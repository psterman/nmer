//go:build windows

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/blugelabs/bluge"
	"github.com/blugelabs/bluge/analysis/lang/cjk"
	blugeSearch "github.com/blugelabs/bluge/search"
	"github.com/fsnotify/fsnotify"
	"golang.org/x/sys/windows"
)

const (
	defaultInitialScanDelay = 15 * time.Second
	defaultPerFilePause     = 5 * time.Millisecond
	defaultMaxTextFileBytes = int64(2 * 1024 * 1024)
	defaultHardReadLimit    = int64(32 * 1024 * 1024)
	defaultMinFreeDiskBytes = int64(500 * 1024 * 1024)
	defaultQueueSize        = 4096
)

var (
	errSkipNonText  = errors.New("skip non-text file")
	errSkipTooLarge = errors.New("skip too large file")

	fullTextGlobalMu sync.RWMutex
	fullTextGlobal   *blugeIndexer
)

type FullTextStatus struct {
	Engine             string   `json:"engine"`
	Running            bool     `json:"running"`
	Ready              bool     `json:"ready"`
	InitialScanDone    bool     `json:"initialScanDone"`
	Progress           float64  `json:"progress"`
	IndexingFile       string   `json:"indexing_file"`
	IndexedFiles       int64    `json:"indexedFiles"`
	PendingTasks       int      `json:"pendingTasks"`
	WorkerCount        int      `json:"workerCount"`
	ScanSpeed          string   `json:"scanSpeed"`
	IncludeLargeText   bool     `json:"includeLargeText"`
	MaxFileSizeMB      int64    `json:"maxFileSizeMB"`
	IndexDir           string   `json:"indexDir"`
	NeedUserIndexDir   bool     `json:"needUserIndexDir"`
	Roots              []string `json:"roots"`
	LowDisk            bool     `json:"lowDisk"`
	FreeDiskMB         int64    `json:"freeDiskMB"`
	WritesPaused       bool     `json:"writesPaused"`
	LastError          string   `json:"lastError,omitempty"`
	Alerts             []string `json:"alerts,omitempty"`
	LastUpdatedRFC3339 string   `json:"lastUpdated"`
}

type fullTextConfig struct {
	BaseDir          string
	IndexDir         string
	Roots            []string
	Workers          int
	InitialDelay     time.Duration
	PerFilePause     time.Duration
	ScanSpeed        string
	IncludeLargeText bool
	MaxFileSizeBytes int64
	HardReadLimit    int64
	QueueSize        int
	MinFreeDiskBytes int64
	NeedUserIndexDir bool
	ExcludeDirs      map[string]struct{}
}

type fileFingerprint struct {
	Size    int64
	ModNano int64
}

type indexTask struct {
	Path    string
	Delete  bool
	Initial bool
}

type blugeIndexer struct {
	cfg     fullTextConfig
	writer  *bluge.Writer
	watcher *fsnotify.Watcher

	ctx    context.Context
	cancel context.CancelFunc

	tasks chan indexTask

	startOnce sync.Once

	mu sync.RWMutex

	status FullTextStatus

	knownFiles    map[string]fileFingerprint
	watchedDirs   map[string]struct{}
	recentEnqueue map[string]time.Time

	initialWalkDone  bool
	initialTaskTotal int64
	initialTaskDone  int64
}

type fullTextProgressPayload struct {
	Progress     float64  `json:"progress"`
	ProgressText string   `json:"progressText"`
	IndexingFile string   `json:"indexing_file"`
	Ready        bool     `json:"ready"`
	Running      bool     `json:"running"`
	LowDisk      bool     `json:"lowDisk"`
	EngineLights []string `json:"engine_lights"`
	Alerts       []string `json:"alerts,omitempty"`
}

func StartIndexer(baseDir string) error {
	ensureFullTextRuntime(baseDir)
	if isFullTextStartSuppressed() {
		return errors.New("fulltext indexer is paused")
	}

	fullTextGlobalMu.Lock()
	defer fullTextGlobalMu.Unlock()

	if fullTextGlobal != nil {
		return fullTextGlobal.StartIndexer()
	}

	idx, err := newBlugeIndexer(baseDir)
	if err != nil {
		return err
	}
	fullTextGlobal = idx
	return fullTextGlobal.StartIndexer()
}

func Search(query string, limit int) ([]map[string]any, error) {
	fullTextGlobalMu.RLock()
	idx := fullTextGlobal
	fullTextGlobalMu.RUnlock()
	if idx == nil {
		return nil, errors.New("fulltext indexer not initialized")
	}
	return idx.Search(query, limit)
}

func GetStatus() FullTextStatus {
	fullTextGlobalMu.RLock()
	idx := fullTextGlobal
	fullTextGlobalMu.RUnlock()
	if idx == nil {
		return FullTextStatus{
			Engine:             "bluge",
			Running:            false,
			Ready:              false,
			InitialScanDone:    false,
			Progress:           0,
			LastUpdatedRFC3339: time.Now().Format(time.RFC3339),
		}
	}
	return idx.GetStatus()
}

func GetProgressPayload() fullTextProgressPayload {
	st := GetStatus()
	return fullTextProgressPayload{
		Progress:     st.Progress,
		ProgressText: fmt.Sprintf("%.1f%%", st.Progress),
		IndexingFile: st.IndexingFile,
		Ready:        st.Ready,
		Running:      st.Running,
		LowDisk:      st.LowDisk,
		EngineLights: buildEngineLights(st),
		Alerts:       st.Alerts,
	}
}

func buildEngineLights(st FullTextStatus) []string {
	lights := []string{"off", "off", "off", "off"}
	if st.Running {
		lights[0] = "active"
	}
	if st.PendingTasks > 0 || st.IndexingFile != "" {
		lights[1] = "active"
	}
	if st.Progress > 0 {
		lights[2] = "active"
	}
	if st.LowDisk || st.WritesPaused || st.LastError != "" {
		lights[3] = "warn"
	} else if st.Running {
		lights[3] = "active"
	}
	if st.Ready {
		lights = []string{"ready", "ready", "ready", "ready"}
	}
	return lights
}

func searchFullTextWithBackend(baseDir, keyword string, maxResults int) ([]map[string]any, error) {
	kw := strings.TrimSpace(keyword)
	if kw == "" || maxResults <= 0 {
		return []map[string]any{}, nil
	}

	if err := StartIndexer(baseDir); err != nil {
		return searchFullTextWithRg(baseDir, kw, maxResults)
	}

	items, err := Search(kw, maxResults)
	if err == nil {
		st := GetStatus()
		if len(items) > 0 || st.Ready {
			return items, nil
		}
	}

	rgItems, rgErr := searchFullTextWithRg(baseDir, kw, maxResults)
	if rgErr != nil {
		if err != nil {
			return nil, fmt.Errorf("bluge=%v; rg=%v", err, rgErr)
		}
		return items, nil
	}
	return rgItems, nil
}

func newBlugeIndexer(baseDir string) (*blugeIndexer, error) {
	cfg := loadFullTextConfig(baseDir)
	if err := os.MkdirAll(cfg.IndexDir, 0o755); err != nil {
		return nil, fmt.Errorf("create index dir failed: %w", err)
	}

	writer, err := bluge.OpenWriter(bluge.DefaultConfig(cfg.IndexDir))
	if err != nil {
		return nil, fmt.Errorf("open bluge writer failed: %w", err)
	}

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		_ = writer.Close()
		return nil, fmt.Errorf("create watcher failed: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	idx := &blugeIndexer{
		cfg:           cfg,
		writer:        writer,
		watcher:       watcher,
		ctx:           ctx,
		cancel:        cancel,
		tasks:         make(chan indexTask, cfg.QueueSize),
		knownFiles:    map[string]fileFingerprint{},
		watchedDirs:   map[string]struct{}{},
		recentEnqueue: map[string]time.Time{},
		status: FullTextStatus{
			Engine:             "bluge",
			Running:            false,
			Ready:              false,
			InitialScanDone:    false,
			Progress:           0,
			IndexingFile:       "",
			IndexedFiles:       0,
			PendingTasks:       0,
			WorkerCount:        cfg.Workers,
			ScanSpeed:          cfg.ScanSpeed,
			IncludeLargeText:   cfg.IncludeLargeText,
			MaxFileSizeMB:      cfg.MaxFileSizeBytes / (1024 * 1024),
			IndexDir:           cfg.IndexDir,
			NeedUserIndexDir:   cfg.NeedUserIndexDir,
			Roots:              append([]string{}, cfg.Roots...),
			LastUpdatedRFC3339: time.Now().Format(time.RFC3339),
		},
	}

	if cfg.NeedUserIndexDir {
		idx.appendAlert("建议设置 SEARCHCENTER_FT_INDEX_DIR 到独立目录，避免默认路径占用系统盘")
	}

	if err := idx.refreshIndexedCount(); err != nil {
		idx.recordError(fmt.Errorf("refresh index count: %w", err))
	}

	return idx, nil
}

func (b *blugeIndexer) StartIndexer() error {
	var startErr error
	b.startOnce.Do(func() {
		if err := setProcessIdlePriority(); err != nil {
			b.appendAlert("无法设置 IDLE_PRIORITY_CLASS，索引仍会继续")
		}

		b.mu.Lock()
		b.status.Running = true
		b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
		b.mu.Unlock()

		for i := 0; i < b.cfg.Workers; i++ {
			go b.workerLoop(i + 1)
		}
		go b.watchLoop()
		go b.initialScanLoop()
	})
	return startErr
}

func (b *blugeIndexer) Search(query string, limit int) ([]map[string]any, error) {
	qText := strings.TrimSpace(query)
	if qText == "" {
		return []map[string]any{}, nil
	}
	if limit <= 0 {
		limit = 30
	}

	reader, err := b.writer.Reader()
	if err != nil {
		return nil, err
	}
	defer reader.Close()

	q := buildBlugeQuery(qText)
	req := bluge.NewTopNSearch(limit, q).WithStandardAggregations()
	it, err := reader.Search(context.Background(), req)
	if err != nil {
		return nil, err
	}

	out := make([]map[string]any, 0, limit)
	for {
		match, nerr := it.Next()
		if nerr != nil {
			return out, nerr
		}
		if match == nil {
			break
		}
		item := b.matchToResultItem(match)
		if item != nil {
			out = append(out, item)
		}
	}
	return out, nil
}

func (b *blugeIndexer) GetStatus() FullTextStatus {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.refreshProgressLocked()
	b.status.PendingTasks = len(b.tasks)
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	return cloneFullTextStatus(b.status)
}

func cloneFullTextStatus(st FullTextStatus) FullTextStatus {
	cp := st
	cp.Alerts = append([]string{}, st.Alerts...)
	cp.Roots = append([]string{}, st.Roots...)
	return cp
}

func (b *blugeIndexer) refreshIndexedCount() error {
	reader, err := b.writer.Reader()
	if err != nil {
		return err
	}
	defer reader.Close()

	req := bluge.NewTopNSearch(1, bluge.NewMatchAllQuery()).WithStandardAggregations()
	it, err := reader.Search(context.Background(), req)
	if err != nil {
		return err
	}
	count := int64(it.Aggregations().Count())
	b.mu.Lock()
	if count > 0 {
		b.status.IndexedFiles = count
	}
	b.mu.Unlock()
	return nil
}

func (b *blugeIndexer) initialScanLoop() {
	select {
	case <-b.ctx.Done():
		return
	case <-time.After(b.cfg.InitialDelay):
	}

	for _, root := range b.cfg.Roots {
		b.walkRoot(root, true)
	}

	b.mu.Lock()
	b.initialWalkDone = true
	b.refreshProgressLocked()
	b.mu.Unlock()
}

func (b *blugeIndexer) walkRoot(root string, initial bool) {
	cleanRoot := filepath.Clean(root)
	if st, err := os.Stat(cleanRoot); err != nil || !st.IsDir() {
		return
	}

	_ = filepath.WalkDir(cleanRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		select {
		case <-b.ctx.Done():
			return context.Canceled
		default:
		}

		if d.IsDir() {
			if b.shouldSkipDir(path, d.Name()) {
				return filepath.SkipDir
			}
			b.addWatch(path)
			return nil
		}

		if b.shouldSkipFileByName(path) {
			return nil
		}

		if initial {
			b.mu.Lock()
			b.initialTaskTotal++
			b.refreshProgressLocked()
			b.mu.Unlock()
		}

		b.enqueueTask(indexTask{Path: path, Initial: initial})
		return nil
	})
}

func (b *blugeIndexer) workerLoop(workerID int) {
	for {
		select {
		case <-b.ctx.Done():
			return
		case task := <-b.tasks:
			b.markCurrentFile(task.Path)
			if ok := b.waitForWritableDisk(); !ok {
				return
			}

			var err error
			if task.Delete {
				err = b.deleteByPath(task.Path)
			} else {
				err = b.indexFile(task.Path)
			}
			if err != nil {
				b.recordError(err)
			}

			if task.Initial {
				b.mu.Lock()
				b.initialTaskDone++
				if b.initialWalkDone && b.initialTaskDone >= b.initialTaskTotal {
					b.status.InitialScanDone = true
					b.status.Ready = true
				}
				b.refreshProgressLocked()
				b.mu.Unlock()
			}

			if b.cfg.PerFilePause > 0 {
				time.Sleep(b.cfg.PerFilePause)
			}
			b.clearCurrentFile(task.Path)
		}
	}
}

func (b *blugeIndexer) waitForWritableDisk() bool {
	for {
		freeBytes, err := freeDiskBytesAtPath(b.cfg.IndexDir)
		if err != nil {
			b.appendAlert("磁盘可用空间检测失败，继续执行索引")
			return true
		}
		if int64(freeBytes) >= b.cfg.MinFreeDiskBytes {
			b.setDiskHealthy(freeBytes)
			return true
		}
		b.setLowDisk(freeBytes)
		select {
		case <-b.ctx.Done():
			return false
		case <-time.After(2 * time.Second):
		}
	}
}

func (b *blugeIndexer) setDiskHealthy(freeBytes uint64) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.status.LowDisk = false
	b.status.WritesPaused = false
	b.status.FreeDiskMB = int64(freeBytes / (1024 * 1024))
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
}

func (b *blugeIndexer) setLowDisk(freeBytes uint64) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.status.LowDisk = true
	b.status.WritesPaused = true
	b.status.FreeDiskMB = int64(freeBytes / (1024 * 1024))
	b.status.LastError = "磁盘可用空间不足 500MB，已暂停索引写入"
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.appendAlertLocked("磁盘可用空间不足 500MB，索引写入已自动暂停")
}

func (b *blugeIndexer) watchLoop() {
	for _, root := range b.cfg.Roots {
		b.addWatchRecursive(root)
	}

	for {
		select {
		case <-b.ctx.Done():
			return
		case ev, ok := <-b.watcher.Events:
			if !ok {
				return
			}
			b.handleWatchEvent(ev)
		case err, ok := <-b.watcher.Errors:
			if !ok {
				return
			}
			b.recordError(fmt.Errorf("fsnotify error: %w", err))
		}
	}
}

func (b *blugeIndexer) handleWatchEvent(ev fsnotify.Event) {
	path := filepath.Clean(ev.Name)
	if path == "" {
		return
	}
	if b.shouldSkipFileByName(path) {
		return
	}

	if ev.Op&(fsnotify.Remove|fsnotify.Rename) != 0 {
		b.enqueueTask(indexTask{Path: path, Delete: true})
		return
	}

	st, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			b.enqueueTask(indexTask{Path: path, Delete: true})
		}
		return
	}

	if st.IsDir() {
		if b.shouldSkipDir(path, filepath.Base(path)) {
			return
		}
		b.addWatch(path)
		go b.walkRoot(path, false)
		return
	}

	if ev.Op&(fsnotify.Create|fsnotify.Write|fsnotify.Chmod) != 0 {
		b.enqueueTask(indexTask{Path: path})
	}
}

func (b *blugeIndexer) addWatch(dir string) {
	clean := filepath.Clean(dir)
	if clean == "" {
		return
	}
	if b.shouldSkipDir(clean, filepath.Base(clean)) {
		return
	}
	if b.isIndexDirPath(clean) {
		return
	}

	key := normalizePathKey(clean)
	b.mu.RLock()
	_, exists := b.watchedDirs[key]
	b.mu.RUnlock()
	if exists {
		return
	}

	if err := b.watcher.Add(clean); err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			b.recordError(fmt.Errorf("watch add failed for %s: %w", clean, err))
		}
		return
	}

	b.mu.Lock()
	b.watchedDirs[key] = struct{}{}
	b.mu.Unlock()
}

func (b *blugeIndexer) addWatchRecursive(root string) {
	cleanRoot := filepath.Clean(root)
	if st, err := os.Stat(cleanRoot); err != nil || !st.IsDir() {
		return
	}
	_ = filepath.WalkDir(cleanRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if !d.IsDir() {
			return nil
		}
		if b.shouldSkipDir(path, d.Name()) {
			return filepath.SkipDir
		}
		b.addWatch(path)
		return nil
	})
}

func (b *blugeIndexer) enqueueTask(task indexTask) {
	if task.Path == "" {
		return
	}
	if b.isIndexDirPath(task.Path) {
		return
	}

	key := normalizePathKey(task.Path)
	b.mu.Lock()
	if ts, ok := b.recentEnqueue[key]; ok {
		if time.Since(ts) < 250*time.Millisecond {
			b.mu.Unlock()
			return
		}
	}
	b.recentEnqueue[key] = time.Now()
	for k, ts := range b.recentEnqueue {
		if time.Since(ts) > 30*time.Second {
			delete(b.recentEnqueue, k)
		}
	}
	b.mu.Unlock()

	select {
	case b.tasks <- task:
		b.mu.Lock()
		b.status.PendingTasks = len(b.tasks)
		b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
		b.mu.Unlock()
	default:
		b.appendAlert("索引任务队列已满，已丢弃部分事件")
	}
}

func (b *blugeIndexer) indexFile(path string) error {
	st, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return b.deleteByPath(path)
		}
		return err
	}
	if st.IsDir() {
		return nil
	}
	if b.shouldSkipFileByName(path) {
		return b.deleteByPath(path)
	}
	if !b.cfg.IncludeLargeText && st.Size() > b.cfg.MaxFileSizeBytes {
		return b.deleteByPath(path)
	}
	if st.Size() > b.cfg.HardReadLimit {
		return b.deleteByPath(path)
	}

	id := docIDForPath(path)
	fp := fileFingerprint{Size: st.Size(), ModNano: st.ModTime().UnixNano()}

	b.mu.RLock()
	prev, ok := b.knownFiles[id]
	b.mu.RUnlock()
	if ok && prev == fp {
		return nil
	}

	content, snippet, err := b.readFileForIndex(path, st.Size())
	if err != nil {
		if errors.Is(err, errSkipNonText) || errors.Is(err, errSkipTooLarge) {
			return b.deleteByPath(path)
		}
		return fmt.Errorf("read index content failed (%s): %w", path, err)
	}

	ext := strings.TrimPrefix(strings.ToLower(filepath.Ext(path)), ".")
	mod := st.ModTime()

	doc := bluge.NewDocument(id).
		AddField(bluge.NewKeywordField("path", path).StoreValue()).
		AddField(bluge.NewKeywordField("path_lower", strings.ToLower(path)).StoreValue()).
		AddField(bluge.NewTextField("content", content).WithAnalyzer(cjk.Analyzer()).SearchTermPositions()).
		AddField(bluge.NewKeywordField("ext", ext).StoreValue().Sortable().Aggregatable()).
		AddField(bluge.NewDateTimeField("mtime", mod).StoreValue().Sortable()).
		AddField(bluge.NewNumericField("size", float64(st.Size())).StoreValue().Sortable()).
		AddField(bluge.NewStoredOnlyField("snippet", []byte(snippet))).
		AddField(bluge.NewTextField("path_text", strings.ToLower(path)).WithAnalyzer(cjk.Analyzer()))

	if err := b.writer.Update(doc.ID(), doc); err != nil {
		return fmt.Errorf("bluge update failed (%s): %w", path, err)
	}

	b.mu.Lock()
	b.knownFiles[id] = fp
	if b.status.IndexedFiles < int64(len(b.knownFiles)) {
		b.status.IndexedFiles = int64(len(b.knownFiles))
	}
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
	return nil
}

func (b *blugeIndexer) deleteByPath(path string) error {
	id := docIDForPath(path)
	if err := b.writer.Delete(bluge.Identifier(id)); err != nil {
		return fmt.Errorf("bluge delete failed (%s): %w", path, err)
	}
	b.mu.Lock()
	delete(b.knownFiles, id)
	if b.status.IndexedFiles > 0 {
		b.status.IndexedFiles--
	}
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
	return nil
}

func (b *blugeIndexer) readFileForIndex(path string, fileSize int64) (string, string, error) {
	if !b.cfg.IncludeLargeText && fileSize > b.cfg.MaxFileSizeBytes {
		return "", "", errSkipTooLarge
	}

	maxRead := b.cfg.HardReadLimit
	if maxRead <= 0 {
		maxRead = defaultHardReadLimit
	}

	f, err := os.Open(path)
	if err != nil {
		return "", "", err
	}
	defer f.Close()

	buf, err := io.ReadAll(io.LimitReader(f, maxRead+1))
	if err != nil {
		return "", "", err
	}
	if int64(len(buf)) > maxRead {
		return "", "", errSkipTooLarge
	}
	if len(buf) == 0 {
		return "", "", nil
	}
	if bytes.IndexByte(buf, 0) >= 0 {
		return "", "", errSkipNonText
	}
	if !utf8.Valid(buf) {
		buf = bytes.ToValidUTF8(buf, []byte(" "))
	}

	text := string(buf)
	snippet := trimPreview(text, 180)
	return text, snippet, nil
}

func (b *blugeIndexer) matchToResultItem(match *blugeSearch.DocumentMatch) map[string]any {
	var (
		pathVal    string
		snippetVal string
		extVal     string
		mtimeVal   time.Time
		sizeVal    int64
	)

	_ = match.VisitStoredFields(func(field string, value []byte) bool {
		switch field {
		case "path":
			pathVal = string(value)
		case "snippet":
			snippetVal = string(value)
		case "ext":
			extVal = string(value)
		case "mtime":
			if t, err := bluge.DecodeDateTime(value); err == nil {
				mtimeVal = t
			}
		case "size":
			if f, err := bluge.DecodeNumericFloat64(value); err == nil {
				sizeVal = int64(f)
			}
		}
		return true
	})

	if pathVal == "" {
		return nil
	}

	dirPath, fileName, extFromPath := splitPathParts(pathVal)
	if extVal == "" {
		extVal = strings.TrimPrefix(strings.ToLower(extFromPath), ".")
	}
	ts := ""
	if !mtimeVal.IsZero() {
		ts = mtimeVal.Format("2006-01-02 15:04")
	}
	subParts := make([]string, 0, 4)
	if dirPath != "" {
		subParts = append(subParts, dirPath)
	}
	if extVal != "" {
		subParts = append(subParts, "."+extVal)
	}
	if ts != "" {
		subParts = append(subParts, ts)
	}
	if sizeVal > 0 {
		subParts = append(subParts, fmt.Sprintf("%d KB", sizeVal/1024))
	}

	meta := map[string]any{
		"FilePath":       pathVal,
		"FileName":       fileName,
		"DirPath":        dirPath,
		"Ext":            extFromPath,
		"IsDirectory":    false,
		"FullTextHit":    true,
		"MatchedLine":    snippetVal,
		"DateModified":   ts,
		"IndexedBy":      "bluge",
		"SearchScore":    match.Score,
		"IndexedSize":    sizeVal,
		"IndexedExtName": extVal,
	}

	return map[string]any{
		"originalDataType": "fulltext",
		"DataType":         "file",
		"DataTypeName":     "全文搜索",
		"ID":               pathVal,
		"Title":            fileName,
		"SubTitle":         strings.Join(subParts, " · "),
		"Content":          pathVal,
		"Preview":          snippetVal,
		"Source":           "文件",
		"Metadata":         meta,
		"Action":           "open_file",
		"ActionParams":     map[string]any{"FilePath": pathVal},
	}
}

func (b *blugeIndexer) shouldSkipDir(path, dirName string) bool {
	if b.isIndexDirPath(path) {
		return true
	}
	name := strings.ToLower(strings.TrimSpace(dirName))
	_, skip := b.cfg.ExcludeDirs[name]
	return skip
}

func (b *blugeIndexer) shouldSkipFileByName(path string) bool {
	if b.isIndexDirPath(path) {
		return true
	}
	name := strings.ToLower(filepath.Base(path))
	if strings.HasPrefix(name, ".") && name != ".env" {
		return true
	}
	ext := strings.ToLower(filepath.Ext(name))
	switch ext {
	case ".exe", ".dll", ".db", ".wal", ".shm", ".jpg", ".jpeg", ".png", ".gif", ".ico", ".zip", ".7z", ".rar", ".mp4", ".mp3", ".avi", ".mkv", ".pdf":
		return true
	default:
		return false
	}
}

func (b *blugeIndexer) isIndexDirPath(path string) bool {
	p := normalizePathKey(path)
	idx := normalizePathKey(b.cfg.IndexDir)
	if p == idx {
		return true
	}
	return strings.HasPrefix(p+"\\", idx+"\\")
}

func (b *blugeIndexer) markCurrentFile(path string) {
	b.mu.Lock()
	b.status.IndexingFile = path
	b.status.PendingTasks = len(b.tasks)
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
}

func (b *blugeIndexer) clearCurrentFile(path string) {
	b.mu.Lock()
	if b.status.IndexingFile == path {
		b.status.IndexingFile = ""
	}
	b.status.PendingTasks = len(b.tasks)
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
}

func (b *blugeIndexer) recordError(err error) {
	if err == nil {
		return
	}
	b.mu.Lock()
	b.status.LastError = err.Error()
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.appendAlertLocked(err.Error())
	b.mu.Unlock()
}

func (b *blugeIndexer) appendAlert(msg string) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.appendAlertLocked(msg)
}

func (b *blugeIndexer) appendAlertLocked(msg string) {
	if msg == "" {
		return
	}
	for _, it := range b.status.Alerts {
		if it == msg {
			return
		}
	}
	b.status.Alerts = append([]string{msg}, b.status.Alerts...)
	if len(b.status.Alerts) > 8 {
		b.status.Alerts = b.status.Alerts[:8]
	}
}

func (b *blugeIndexer) refreshProgressLocked() {
	total := b.initialTaskTotal
	done := b.initialTaskDone
	if b.status.InitialScanDone {
		b.status.Progress = 100
		return
	}
	if total <= 0 {
		if b.initialWalkDone {
			b.status.Progress = 100
			b.status.InitialScanDone = true
			b.status.Ready = true
		} else {
			b.status.Progress = 0
		}
		return
	}
	p := (float64(done) * 100.0) / float64(total)
	if p < 0 {
		p = 0
	}
	if p > 99.5 && !b.initialWalkDone {
		p = 99.5
	}
	if p > 100 {
		p = 100
	}
	b.status.Progress = p
	if b.initialWalkDone && done >= total {
		b.status.InitialScanDone = true
		b.status.Ready = true
		b.status.Progress = 100
	}
}

func loadFullTextConfig(baseDir string) fullTextConfig {
	roots := fullTextRoots(baseDir)
	indexDir, needHint := resolveIndexDir(baseDir)
	workers := resolveWorkerCount()
	scanSpeed := resolveScanSpeed()
	perFilePause := resolvePerFilePause(scanSpeed)
	includeLarge := parseBoolEnv("SEARCHCENTER_FT_INCLUDE_LARGE", false)
	maxFileSize := parseInt64Env("SEARCHCENTER_FT_MAX_FILE_MB", 2) * 1024 * 1024
	if maxFileSize <= 0 {
		maxFileSize = defaultMaxTextFileBytes
	}
	hardLimit := parseInt64Env("SEARCHCENTER_FT_HARD_LIMIT_MB", 32) * 1024 * 1024
	if hardLimit < maxFileSize {
		hardLimit = maxFileSize
	}

	queueSize := int(parseInt64Env("SEARCHCENTER_FT_QUEUE", defaultQueueSize))
	if queueSize <= 0 {
		queueSize = defaultQueueSize
	}

	exclude := map[string]struct{}{}
	for _, d := range []string{"node_modules", ".git", ".venv", "dist", "bin", "temp"} {
		exclude[strings.ToLower(d)] = struct{}{}
	}
	if extra := strings.TrimSpace(os.Getenv("SEARCHCENTER_FT_EXCLUDE_DIRS")); extra != "" {
		for _, it := range strings.Split(extra, ";") {
			x := strings.ToLower(strings.TrimSpace(it))
			if x != "" {
				exclude[x] = struct{}{}
			}
		}
	}

	initialDelay := defaultInitialScanDelay
	if v := parseInt64Env("SEARCHCENTER_FT_INITIAL_DELAY_SEC", 15); v > 0 {
		initialDelay = time.Duration(v) * time.Second
	}

	minFree := parseInt64Env("SEARCHCENTER_FT_MIN_FREE_MB", 500) * 1024 * 1024
	if minFree <= 0 {
		minFree = defaultMinFreeDiskBytes
	}

	return fullTextConfig{
		BaseDir:          baseDir,
		IndexDir:         indexDir,
		Roots:            roots,
		Workers:          workers,
		InitialDelay:     initialDelay,
		PerFilePause:     perFilePause,
		ScanSpeed:        scanSpeed,
		IncludeLargeText: includeLarge,
		MaxFileSizeBytes: maxFileSize,
		HardReadLimit:    hardLimit,
		QueueSize:        queueSize,
		MinFreeDiskBytes: minFree,
		NeedUserIndexDir: needHint,
		ExcludeDirs:      exclude,
	}
}

func resolveIndexDir(baseDir string) (string, bool) {
	raw := strings.TrimSpace(os.Getenv("SEARCHCENTER_FT_INDEX_DIR"))
	if raw != "" {
		if !filepath.IsAbs(raw) {
			raw = filepath.Join(baseDir, raw)
		}
		abs := filepath.Clean(raw)
		return abs, false
	}

	local := strings.TrimSpace(os.Getenv("LOCALAPPDATA"))
	if local == "" {
		local = strings.TrimSpace(os.Getenv("APPDATA"))
	}
	if local == "" {
		local = os.TempDir()
	}
	return filepath.Join(local, "SearchCenter", "bluge_index"), true
}

func isUnderBase(path, base string) bool {
	p := normalizePathKey(path)
	b := normalizePathKey(base)
	if p == b {
		return true
	}
	return strings.HasPrefix(p+"\\", b+"\\")
}

func resolveWorkerCount() int {
	if v := strings.TrimSpace(os.Getenv("SEARCHCENTER_FT_WORKERS")); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	n := runtime.NumCPU() / 2
	if n < 1 {
		n = 1
	}
	if n > 2 {
		n = 2
	}
	return n
}

func resolveScanSpeed() string {
	s := strings.ToLower(strings.TrimSpace(os.Getenv("SEARCHCENTER_FT_SCAN_SPEED")))
	switch s {
	case "slow", "normal", "fast":
		return s
	default:
		return "normal"
	}
}

func resolvePerFilePause(speed string) time.Duration {
	if ms := parseInt64Env("SEARCHCENTER_FT_PAUSE_MS", -1); ms >= 0 {
		return time.Duration(ms) * time.Millisecond
	}
	switch speed {
	case "slow":
		return 12 * time.Millisecond
	case "fast":
		return 1 * time.Millisecond
	default:
		return defaultPerFilePause
	}
}

func parseBoolEnv(key string, def bool) bool {
	raw := strings.ToLower(strings.TrimSpace(os.Getenv(key)))
	switch raw {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return def
	}
}

func parseInt64Env(key string, def int64) int64 {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return def
	}
	v, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return def
	}
	return v
}

func normalizePathKey(path string) string {
	p := filepath.Clean(path)
	p = strings.ReplaceAll(p, "/", "\\")
	return strings.ToLower(p)
}

func docIDForPath(path string) string {
	return normalizePathKey(path)
}

func setProcessIdlePriority() error {
	if err := windows.SetPriorityClass(windows.CurrentProcess(), windows.IDLE_PRIORITY_CLASS); err != nil {
		return err
	}
	log.Printf("[fulltext] process priority set to IDLE_PRIORITY_CLASS")
	return nil
}

func freeDiskBytesAtPath(path string) (uint64, error) {
	ptr, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return 0, err
	}
	var freeBytesAvailable uint64
	var totalBytes uint64
	var totalFreeBytes uint64
	if err := windows.GetDiskFreeSpaceEx(ptr, &freeBytesAvailable, &totalBytes, &totalFreeBytes); err != nil {
		return 0, err
	}
	return freeBytesAvailable, nil
}

func buildBlugeQuery(raw string) bluge.Query {
	query := strings.TrimSpace(raw)
	if query == "" {
		return bluge.NewMatchAllQuery()
	}

	phrases, tokens := splitQueryWithPhrases(query)
	root := bluge.NewBooleanQuery()

	for _, ph := range phrases {
		if ph == "" {
			continue
		}
		root.AddMust(bluge.NewMatchPhraseQuery(ph).SetField("content"))
	}

	for _, tk := range tokens {
		if tk == "" {
			continue
		}
		low := strings.ToLower(tk)
		switch {
		case strings.HasPrefix(low, "ext:"):
			v := strings.TrimPrefix(low, "ext:")
			if v != "" {
				root.AddMust(bluge.NewTermQuery(v).SetField("ext"))
			}
		case strings.HasPrefix(low, "path:"):
			v := strings.TrimPrefix(low, "path:")
			if v != "" {
				if strings.ContainsAny(v, "*?") {
					root.AddMust(bluge.NewWildcardQuery(v).SetField("path_lower"))
				} else {
					root.AddMust(bluge.NewWildcardQuery("*" + strings.ToLower(v) + "*").SetField("path_lower"))
				}
			}
		case strings.HasSuffix(low, "~") && len(low) > 1:
			root.AddMust(bluge.NewFuzzyQuery(strings.TrimSuffix(low, "~")).SetField("content"))
		case strings.HasSuffix(low, "*") && len(low) > 1:
			root.AddMust(bluge.NewPrefixQuery(strings.TrimSuffix(low, "*")).SetField("content"))
		case strings.ContainsAny(low, "*?"):
			root.AddMust(bluge.NewWildcardQuery(low).SetField("content"))
		default:
			mix := bluge.NewBooleanQuery()
			mix.AddShould(
				bluge.NewMatchQuery(tk).SetField("content"),
				bluge.NewMatchQuery(strings.ToLower(tk)).SetField("path_text"),
			)
			mix.SetMinShould(1)
			root.AddMust(mix)
		}
	}

	if len(root.Musts()) == 0 && len(root.Shoulds()) == 0 {
		return bluge.NewMatchAllQuery()
	}
	return root
}

func splitQueryWithPhrases(raw string) (phrases, tokens []string) {
	var (
		buf     strings.Builder
		inQuote bool
	)
	for _, r := range raw {
		switch r {
		case '"':
			if inQuote {
				phrases = append(phrases, strings.TrimSpace(buf.String()))
				buf.Reset()
				inQuote = false
			} else {
				if strings.TrimSpace(buf.String()) != "" {
					tokens = append(tokens, strings.Fields(buf.String())...)
				}
				buf.Reset()
				inQuote = true
			}
		default:
			buf.WriteRune(r)
		}
	}
	if strings.TrimSpace(buf.String()) != "" {
		if inQuote {
			phrases = append(phrases, strings.TrimSpace(buf.String()))
		} else {
			tokens = append(tokens, strings.Fields(buf.String())...)
		}
	}
	return phrases, tokens
}

func handleFullTextStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(GetStatus())
}

func handleFullTextProgress(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(GetProgressPayload())
}

func handleFullTextProgressStream(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "stream unsupported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		payload := GetProgressPayload()
		b, _ := json.Marshal(payload)
		_, _ = fmt.Fprintf(w, "data: %s\n\n", b)
		flusher.Flush()

		select {
		case <-r.Context().Done():
			return
		case <-ticker.C:
		}
	}
}
