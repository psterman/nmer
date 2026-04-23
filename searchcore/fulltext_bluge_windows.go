//go:build windows

package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"hash/crc32"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/blugelabs/bluge"
	blugeindex "github.com/blugelabs/bluge/index"
	blugeSearch "github.com/blugelabs/bluge/search"
	blugeHighlight "github.com/blugelabs/bluge/search/highlight"
	"github.com/fsnotify/fsnotify"
	"golang.org/x/sys/windows"
)

const (
	defaultInitialScanDelay       = 1 * time.Second
	defaultPerFilePause           = 5 * time.Millisecond
	defaultMaxTextFileBytes       = int64(8 * 1024 * 1024)
	defaultHardReadLimit          = int64(32 * 1024 * 1024)
	defaultMinFreeDiskBytes       = int64(500 * 1024 * 1024)
	defaultQueueSize              = 16384
	defaultBatchMaxDocs           = 256
	defaultBatchFlushInterval     = time.Second
	defaultEverythingTimeout      = 8 * time.Second
	supplementalEverythingTimeout = 30 * time.Second
	defaultMFTTimeout             = 10 * time.Second
	defaultRootWalkTimeout        = 10 * time.Minute
	defaultReadDirTimeout         = 5 * time.Second
	recentEnqueueKeep             = 30 * time.Minute
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
	ProgressText       string   `json:"progressText"`
	ProgressDetail     string   `json:"progressDetail"`
	EfficiencyText     string   `json:"efficiencyText"`
	ScanPhase          string   `json:"scanPhase"`
	IndexingFile       string   `json:"indexing_file"`
	IndexedFiles       int64    `json:"indexedFiles"`
	DiscoveredFiles    int64    `json:"discoveredFiles"`
	ProcessedFiles     int64    `json:"processedFiles"`
	PendingTasks       int      `json:"pendingTasks"`
	QueueCapacity      int      `json:"queueCapacity"`
	QueueSaturated     bool     `json:"queueSaturated"`
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
	FilesPerSec        float64  `json:"filesPerSec"`
	ETASeconds         int64    `json:"etaSeconds"`
	LastError          string   `json:"lastError,omitempty"`
	Alerts             []string `json:"alerts,omitempty"`
	LastUpdatedRFC3339 string   `json:"lastUpdated"`
	ScanMode           string   `json:"scan_mode,omitempty"`
	IndexEpoch         uint64   `json:"indexEpoch,omitempty"`
}

type fullTextConfig struct {
	BaseDir             string
	IndexDir            string
	Roots               []string
	FilterConfig        fullTextFilterResolved
	Workers             int
	InitialDelay        time.Duration
	PerFilePause        time.Duration
	ScanSpeed           string
	IncludeLargeText    bool
	MaxFileSizeBytes    int64
	HardReadLimit       int64
	QueueSize           int
	MinFreeDiskBytes    int64
	NeedUserIndexDir    bool
	ExcludeDirs         map[string]struct{}
	IdleIndexAfter      time.Duration
	BatchMaxDocs        int
	BatchFlushInterval  time.Duration
	UseEverything       bool
	UseMFT              bool
	UseUSN              bool
	SkipCommonBinaryExt bool
	IndexMetaOnly       bool
	ForceContentRecheck bool
}

type fileFingerprint struct {
	Size        int64
	ModNano     int64
	ContentHash uint32
}

type indexTask struct {
	Path    string
	Delete  bool
	Initial bool
	Sync    bool
}

type blugeIndexer struct {
	cfg     fullTextConfig
	writer  *bluge.Writer
	watcher *fsnotify.Watcher
	meta    *indexMetaStore

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
	idleWaitNotified bool
	startedAt        time.Time

	cachedReader atomic.Pointer[bluge.Reader]

	batchMu       sync.Mutex
	pendingBatch  *blugeindex.Batch
	batchOpCount  int
	batchFirstAdd time.Time

	indexEpoch atomic.Uint64
	usedMFT    atomic.Bool
	usnRunning atomic.Bool

	frnPathMu sync.RWMutex
	frnToAbs  map[uint64]string
}

type fullTextProgressPayload struct {
	Progress       float64  `json:"progress"`
	ProgressText   string   `json:"progressText"`
	ProgressDetail string   `json:"progressDetail"`
	EfficiencyText string   `json:"efficiencyText"`
	ScanPhase      string   `json:"scanPhase"`
	IndexingFile   string   `json:"indexing_file"`
	Ready          bool     `json:"ready"`
	Running        bool     `json:"running"`
	LowDisk        bool     `json:"lowDisk"`
	FilesPerSec    float64  `json:"filesPerSec"`
	ETASeconds     int64    `json:"etaSeconds"`
	EngineLights   []string `json:"engine_lights"`
	Alerts         []string `json:"alerts,omitempty"`
	ScanMode       string   `json:"scan_mode,omitempty"`
	IndexEpoch     uint64   `json:"indexEpoch,omitempty"`
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
			ProgressText:       "0.0%",
			ProgressDetail:     "not started",
			EfficiencyText:     "0 files/s",
			ScanPhase:          "idle",
			LastUpdatedRFC3339: time.Now().Format(time.RFC3339),
		}
	}
	return idx.GetStatus()
}

func GetProgressPayload() fullTextProgressPayload {
	st := GetStatus()
	return fullTextProgressPayload{
		Progress:       st.Progress,
		ProgressText:   st.ProgressText,
		ProgressDetail: st.ProgressDetail,
		EfficiencyText: st.EfficiencyText,
		ScanPhase:      st.ScanPhase,
		IndexingFile:   st.IndexingFile,
		Ready:          st.Ready,
		Running:        st.Running,
		LowDisk:        st.LowDisk,
		FilesPerSec:    st.FilesPerSec,
		ETASeconds:     st.ETASeconds,
		EngineLights:   buildEngineLights(st),
		Alerts:         st.Alerts,
		ScanMode:       st.ScanMode,
		IndexEpoch:     st.IndexEpoch,
	}
}

func collectRecentUnindexedPaths(window time.Duration, maxCandidates int) []string {
	if window <= 0 || maxCandidates <= 0 {
		return nil
	}
	fullTextGlobalMu.RLock()
	idx := fullTextGlobal
	fullTextGlobalMu.RUnlock()
	if idx == nil {
		return nil
	}
	return idx.collectRecentUnindexedPaths(window, maxCandidates)
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
	return searchFullTextWithBackendContext(context.Background(), baseDir, keyword, maxResults)
}

func searchFullTextWithBackendContext(ctx context.Context, baseDir, keyword string, maxResults int) ([]map[string]any, error) {
	kw := strings.TrimSpace(keyword)
	if kw == "" || maxResults <= 0 {
		return []map[string]any{}, nil
	}
	if ctx == nil {
		ctx = context.Background()
	}
	if maxResults > 400 {
		maxResults = 400
	}
	searchTerms := extractSearchContentTerms(kw)
	hotKeyword := pickPrimarySearchTerm(searchTerms)

	_ = StartIndexer(baseDir)
	coldItems, coldErr := Search(kw, maxResults*2)
	merged := mergeAndRankFullTextItems(kw, maxResults, coldItems)
	hotErr := error(nil)
	if len(merged) < maxResults && hotKeyword != "" && shouldUseHotPathForQuery(baseDir) {
		remain := maxResults - len(merged)
		hotItems, err := searchRecentUnindexedWithRgContext(ctx, baseDir, hotKeyword, remain*2, 10*time.Minute)
		if err != nil {
			hotErr = err
		}
		merged = mergeAndRankFullTextItems(kw, maxResults, merged, hotItems)
	}
	merged = applyStructuredFiltersToItems(merged, kw)
	if len(merged) > 0 {
		return merged, nil
	}
	if ctx.Err() != nil {
		return []map[string]any{}, nil
	}
	if coldErr == nil {
		return []map[string]any{}, nil
	}
	if coldErr != nil {
		if hotErr != nil {
			return nil, fmt.Errorf("hot patch failed: %v; cold search failed: %v", hotErr, coldErr)
		}
		return nil, coldErr
	}
	if hotErr != nil {
		return nil, hotErr
	}
	return []map[string]any{}, nil
}

func shouldUseHotPathForQuery(baseDir string) bool {
	_ = baseDir
	return true
}

func newBlugeIndexer(baseDir string) (*blugeIndexer, error) {
	cfg := loadFullTextConfig(baseDir)
	if err := os.MkdirAll(cfg.IndexDir, 0o755); err != nil {
		return nil, fmt.Errorf("create index dir failed: %w", err)
	}

	writer, err := openBlugeWriterWithRetry(cfg.IndexDir, 6, 180*time.Millisecond)
	if err != nil {
		return nil, fmt.Errorf("open bluge writer failed (%s): %w", cfg.IndexDir, err)
	}

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		_ = writer.Close()
		return nil, fmt.Errorf("create watcher failed: %w", err)
	}
	meta, err := openIndexMetaStore(cfg.IndexDir)
	if err != nil {
		_ = watcher.Close()
		_ = writer.Close()
		return nil, fmt.Errorf("open index meta failed: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	idx := &blugeIndexer{
		cfg:           cfg,
		writer:        writer,
		watcher:       watcher,
		meta:          meta,
		ctx:           ctx,
		cancel:        cancel,
		tasks:         make(chan indexTask, cfg.QueueSize),
		knownFiles:    map[string]fileFingerprint{},
		watchedDirs:   map[string]struct{}{},
		recentEnqueue: map[string]time.Time{},
		frnToAbs:      make(map[uint64]string),
		status: FullTextStatus{
			Engine:             "bluge",
			Running:            false,
			Ready:              false,
			InitialScanDone:    false,
			Progress:           0,
			ProgressText:       "0.0%",
			ProgressDetail:     "waiting to scan",
			EfficiencyText:     "0 files/s",
			ScanPhase:          "startup",
			IndexingFile:       "",
			IndexedFiles:       0,
			DiscoveredFiles:    0,
			ProcessedFiles:     0,
			PendingTasks:       0,
			QueueCapacity:      cfg.QueueSize,
			QueueSaturated:     false,
			WorkerCount:        cfg.Workers,
			ScanSpeed:          cfg.ScanSpeed,
			IncludeLargeText:   cfg.IncludeLargeText,
			MaxFileSizeMB:      cfg.MaxFileSizeBytes / (1024 * 1024),
			IndexDir:           cfg.IndexDir,
			NeedUserIndexDir:   cfg.NeedUserIndexDir,
			Roots:              append([]string{}, cfg.Roots...),
			LastUpdatedRFC3339: time.Now().Format(time.RFC3339),
		},
		startedAt: time.Now(),
	}

	if cfg.NeedUserIndexDir {
		idx.appendAlert("set SEARCHCENTER_FT_INDEX_DIR to a dedicated directory for better stability")
	}
	if cfg.ForceContentRecheck {
		idx.appendAlert("full sync enabled: rechecking file contents against index")
	}

	if known, kerr := idx.meta.LoadAll(); kerr == nil {
		idx.knownFiles = known
	} else {
		idx.recordError(fmt.Errorf("load index meta failed: %w", kerr))
	}
	if pst, ok, perr := idx.meta.LoadIndexState(); perr == nil && ok {
		if pst.IndexedFiles > 0 && idx.status.IndexedFiles < pst.IndexedFiles {
			idx.status.IndexedFiles = pst.IndexedFiles
		}
		if !cfg.ForceContentRecheck && pst.InitialScanDone && len(idx.knownFiles) > 0 {
			idx.status.InitialScanDone = true
			idx.status.Ready = true
			idx.status.Progress = 100
			idx.status.ProgressText = "100.0%"
			idx.status.ScanPhase = "ready"
			if strings.TrimSpace(pst.LastUpdated) != "" {
				idx.status.ProgressDetail = fmt.Sprintf("Loaded previous snapshot (%d files) at %s", int64(len(idx.knownFiles)), pst.LastUpdated)
			} else {
				idx.status.ProgressDetail = fmt.Sprintf("Loaded previous snapshot (%d files)", int64(len(idx.knownFiles)))
			}
		}
	} else if perr != nil {
		idx.recordError(fmt.Errorf("load index state failed: %w", perr))
	}

	if err := idx.refreshIndexedCount(); err != nil {
		idx.recordError(fmt.Errorf("refresh index count: %w", err))
	}
	if !cfg.ForceContentRecheck && len(idx.knownFiles) > 0 && idx.status.IndexedFiles == 0 {
		// Index files were reset but snapshot still indicates incremental mode.
		idx.knownFiles = map[string]fileFingerprint{}
		idx.status.InitialScanDone = false
		idx.status.Ready = false
		idx.status.Progress = 0
		idx.status.ProgressText = "0.0%"
		idx.status.ScanPhase = "walking"
		idx.status.ProgressDetail = "index directory appears rebuilt; switching to full scan"
		idx.appendAlert("index directory rebuilt; forcing full scan")
		_ = idx.meta.SaveIndexState(indexPersistState{
			InitialScanDone: false,
			IndexedFiles:    0,
			ScanPhase:       "walking",
			LastUpdated:     time.Now().Format(time.RFC3339),
		})
	}

	if err := idx.refreshReader(); err != nil {
		idx.recordError(fmt.Errorf("initial bluge reader: %w", err))
	}

	return idx, nil
}

func openBlugeWriterWithRetry(indexDir string, attempts int, baseDelay time.Duration) (*bluge.Writer, error) {
	if attempts < 1 {
		attempts = 1
	}
	if baseDelay <= 0 {
		baseDelay = 150 * time.Millisecond
	}

	var lastErr error
	for i := 0; i < attempts; i++ {
		w, err := bluge.OpenWriter(bluge.DefaultConfig(indexDir))
		if err == nil {
			return w, nil
		}
		lastErr = err
		if !isLikelyIndexLockError(err) || i == attempts-1 {
			break
		}
		time.Sleep(baseDelay * time.Duration(i+1))
	}
	return nil, lastErr
}

func isLikelyIndexLockError(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "exclusive access") ||
		strings.Contains(msg, "unable to obtain exclusive access") ||
		strings.Contains(msg, "has locked a portion of the file") ||
		strings.Contains(msg, "file is being used by another process")
}

func (b *blugeIndexer) refreshReader() error {
	if b.writer == nil {
		return errors.New("no writer")
	}
	nr, err := b.writer.Reader()
	if err != nil {
		return err
	}
	old := b.cachedReader.Swap(nr)
	if old != nil {
		prev := old
		go func() {
			time.Sleep(1500 * time.Millisecond)
			_ = prev.Close()
		}()
	}
	b.indexEpoch.Add(1)
	return nil
}

func (b *blugeIndexer) enqueueBatchUpdate(id string, doc *bluge.Document) error {
	b.batchMu.Lock()
	defer b.batchMu.Unlock()
	if b.pendingBatch == nil {
		b.pendingBatch = bluge.NewBatch()
	}
	if b.batchOpCount == 0 {
		b.batchFirstAdd = time.Now()
	}
	b.pendingBatch.Update(bluge.Identifier(id), doc)
	b.batchOpCount++
	return b.maybeFlushBatchLocked()
}

func (b *blugeIndexer) enqueueBatchDelete(id string) error {
	b.batchMu.Lock()
	defer b.batchMu.Unlock()
	if b.pendingBatch == nil {
		b.pendingBatch = bluge.NewBatch()
	}
	if b.batchOpCount == 0 {
		b.batchFirstAdd = time.Now()
	}
	b.pendingBatch.Delete(bluge.Identifier(id))
	b.batchOpCount++
	return b.maybeFlushBatchLocked()
}

func (b *blugeIndexer) maybeFlushBatchLocked() error {
	if b.batchOpCount == 0 {
		return nil
	}
	overdue := !b.batchFirstAdd.IsZero() && time.Since(b.batchFirstAdd) >= b.cfg.BatchFlushInterval
	if b.batchOpCount < b.cfg.BatchMaxDocs && !overdue {
		return nil
	}
	return b.flushBatchLocked()
}

func (b *blugeIndexer) flushBatchLocked() error {
	if b.pendingBatch == nil || b.batchOpCount == 0 {
		return nil
	}
	err := b.writer.Batch(b.pendingBatch)
	if err != nil {
		return err
	}
	b.pendingBatch.Reset()
	b.batchOpCount = 0
	b.batchFirstAdd = time.Time{}
	if err := b.refreshReader(); err != nil {
		return err
	}
	bumpFullTextQueryCacheEpoch()
	return nil
}

func (b *blugeIndexer) periodicBatchFlushLoop() {
	t := time.NewTicker(500 * time.Millisecond)
	defer t.Stop()
	for {
		select {
		case <-b.ctx.Done():
			return
		case <-t.C:
			b.batchMu.Lock()
			if b.batchOpCount > 0 && !b.batchFirstAdd.IsZero() && time.Since(b.batchFirstAdd) >= b.cfg.BatchFlushInterval {
				_ = b.flushBatchLocked()
			}
			b.batchMu.Unlock()
		}
	}
}

func (b *blugeIndexer) drainPendingBatches() error {
	b.batchMu.Lock()
	defer b.batchMu.Unlock()
	for b.batchOpCount > 0 {
		if err := b.flushBatchLocked(); err != nil {
			return err
		}
	}
	return nil
}

func (b *blugeIndexer) closeCachedReaderOnStop() {
	old := b.cachedReader.Swap(nil)
	if old != nil {
		_ = old.Close()
	}
}

func (b *blugeIndexer) StartIndexer() error {
	var startErr error
	b.startOnce.Do(func() {
		if err := setProcessIdlePriority(); err != nil {
			b.appendAlert("failed to set IDLE_PRIORITY_CLASS; continuing indexing")
		}
		warmIncremental := b.shouldWarmIncrementalSync()

		b.mu.Lock()
		b.status.Running = true
		if warmIncremental {
			b.status.ScanPhase = "incremental_sync"
		} else {
			b.status.ScanPhase = "walking"
		}
		b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
		b.mu.Unlock()

		for i := 0; i < b.cfg.Workers; i++ {
			go b.workerLoop(i + 1)
		}
		go b.periodicBatchFlushLoop()
		go b.statePersistLoop()
		go b.watchLoop()
		go b.initialScanLoop()
		if b.cfg.UseUSN {
			seen := map[byte]struct{}{}
			for _, root := range b.cfg.Roots {
				if !isVolumeRootPath(root) {
					continue
				}
				d, err := driveLetterFromRoot(root)
				if err != nil {
					continue
				}
				if _, ok := seen[d]; ok {
					continue
				}
				seen[d] = struct{}{}
				go b.usnJournalLoop(d)
			}
			if len(seen) > 0 {
				b.usnRunning.Store(true)
			}
		}
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

	reader := b.cachedReader.Load()
	if reader == nil {
		if err := b.refreshReader(); err != nil {
			return nil, err
		}
		reader = b.cachedReader.Load()
	}
	if reader == nil {
		return nil, errors.New("bluge reader unavailable")
	}

	q := lookupFullTextQueryCache(qText, limit, func() bluge.Query {
		return buildBlugeQuery(qText)
	})
	req := bluge.NewTopNSearch(limit, q).WithStandardAggregations().IncludeLocations()
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
		item := b.matchToResultItem(match, qText)
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
	pending := len(b.tasks)
	capacity := cap(b.tasks)
	b.status.PendingTasks = pending
	b.status.QueueCapacity = capacity
	b.status.QueueSaturated = capacity > 0 && pending >= capacity
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	st := cloneFullTextStatus(b.status)
	st.IndexEpoch = b.indexEpoch.Load()
	mode := "walk"
	if b.usedMFT.Load() {
		mode = "mft"
	}
	if b.usnRunning.Load() {
		mode += "+usn"
	}
	st.ScanMode = mode
	return st
}

func cloneFullTextStatus(st FullTextStatus) FullTextStatus {
	cp := st
	cp.Alerts = append([]string{}, st.Alerts...)
	cp.Roots = append([]string{}, st.Roots...)
	return cp
}

func (b *blugeIndexer) refreshIndexedCount() error {
	reader := b.cachedReader.Load()
	if reader == nil {
		if err := b.refreshReader(); err != nil {
			return err
		}
		reader = b.cachedReader.Load()
	}
	if reader == nil {
		return errors.New("reader unavailable for count")
	}

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
	if !b.waitInitialIdleOnce() {
		return
	}
	incrementalMode := b.shouldWarmIncrementalSync()
	if incrementalMode {
		b.mu.Lock()
		b.status.ScanPhase = "incremental_sync"
		b.status.IndexingFile = "Incremental sync"
		b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
		b.mu.Unlock()
	}

	var wg sync.WaitGroup
	for _, root := range b.cfg.Roots {
		root := root
		wg.Add(1)
		go func() {
			defer wg.Done()
			b.scanInitialRoot(root, !incrementalMode)
		}()
	}
	wg.Wait()

	b.mu.Lock()
	if incrementalMode {
		b.status.ScanPhase = "ready"
		b.status.InitialScanDone = true
		b.status.Ready = true
		b.status.IndexingFile = ""
	} else {
		b.initialWalkDone = true
		b.status.ScanPhase = "indexing"
	}
	b.refreshProgressLocked()
	b.mu.Unlock()
}

func (b *blugeIndexer) scanInitialRoot(root string, initial bool) {
	beforeDiscovered := b.snapshotInitialTaskTotal()
	b.mu.Lock()
	if initial {
		b.status.ScanPhase = "walking"
	} else {
		b.status.ScanPhase = "incremental_sync"
	}
	b.status.IndexingFile = "Walking root: " + root
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
	b.walkRoot(root, initial)
	if !initial {
		return
	}
	afterDiscovered := b.snapshotInitialTaskTotal()
	if afterDiscovered == beforeDiscovered {
		b.appendAlert(fmt.Sprintf("root %s produced 0 files in primary scan, running supplemental scan", root))
		b.runSupplementalRootScan(root, true)
		return
	}
	if isNonSystemVolumeRoot(root) {
		b.appendAlert(fmt.Sprintf("running non-system supplemental scan for %s", root))
		b.runSupplementalRootScan(root, true)
	}
}

func (b *blugeIndexer) walkRoot(root string, initial bool) {
	cleanRoot := filepath.Clean(root)
	if st, err := os.Stat(cleanRoot); err != nil || !st.IsDir() {
		return
	}

	if b.cfg.UseMFT && isVolumeRootPath(cleanRoot) {
		b.mu.Lock()
		b.status.ScanPhase = "walking"
		b.status.IndexingFile = "MFT enumerate: " + cleanRoot
		b.mu.Unlock()

		mftCtx, cancelMFT := context.WithTimeout(b.ctx, defaultMFTTimeout)
		emitted, err := walkRootWithMFT(mftCtx, cleanRoot, b.frnToAbs, func(abs string) error {
			select {
			case <-mftCtx.Done():
				return context.Canceled
			default:
			}
			if b.shouldSkipFileByName(abs) {
				return nil
			}
			if initial {
				b.mu.Lock()
				b.initialTaskTotal++
				b.status.DiscoveredFiles = b.initialTaskTotal
				b.refreshProgressLocked()
				b.mu.Unlock()
			}
			b.enqueueTask(indexTask{Path: abs, Initial: initial, Sync: !initial})
			return nil
		})
		cancelMFT()
		if err != nil || emitted == 0 {
			b.recordError(err)
			if err != nil {
				b.appendAlert(fmt.Sprintf("MFT failed, fallback to Everything/WalkDir: %v", err))
			} else {
				b.appendAlert(fmt.Sprintf("MFT returned 0 files, fallback to Everything/WalkDir: %s", cleanRoot))
			}

			if initial {
				b.mu.Lock()
				b.status.ScanPhase = "walking"
				b.status.IndexingFile = "Everything enumerate: " + cleanRoot
				b.mu.Unlock()

				evEmitted, evErr := b.walkRootWithEverythingWithTimeout(cleanRoot, initial, defaultEverythingTimeout)
				if evErr == nil && evEmitted > 0 {
					return
				}
				if evErr != nil {
					b.appendAlert(fmt.Sprintf("Everything failed, fallback to WalkDir: %v", evErr))
				}
			}
			b.walkRootDirConcurrent(cleanRoot, initial)
		} else {
			b.usedMFT.Store(true)
		}
		return
	}

	if initial && b.cfg.UseEverything {
		b.mu.Lock()
		b.status.ScanPhase = "walking"
		b.status.IndexingFile = "Everything enumerate: " + cleanRoot
		b.mu.Unlock()

		emitted, err := b.walkRootWithEverythingWithTimeout(cleanRoot, initial, defaultEverythingTimeout)
		if err == nil && emitted > 0 {
			return
		}
		if err != nil {
			b.appendAlert(fmt.Sprintf("Everything failed, fallback to WalkDir: %v", err))
		}
	}

	b.walkRootDirConcurrent(cleanRoot, initial)
}

func (b *blugeIndexer) snapshotInitialTaskTotal() int64 {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.initialTaskTotal
}

func isNonSystemVolumeRoot(root string) bool {
	clean := strings.ToUpper(filepath.Clean(strings.TrimSpace(root)))
	if !isVolumeRootPath(clean) {
		return false
	}
	sys := strings.ToUpper(filepath.Clean(strings.TrimSpace(os.Getenv("SystemDrive"))))
	if sys == "" {
		sys = "C:\\"
	}
	return !strings.EqualFold(clean, sys)
}

func (b *blugeIndexer) runSupplementalRootScan(root string, initial bool) {
	cleanRoot := filepath.Clean(root)
	if st, err := os.Stat(cleanRoot); err != nil || !st.IsDir() {
		return
	}

	b.mu.Lock()
	b.status.ScanPhase = "walking"
	b.status.IndexingFile = "Supplemental enumerate: " + cleanRoot
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()

	emitted, err := b.walkRootWithEverythingWithTimeout(cleanRoot, initial, supplementalEverythingTimeout)
	if err == nil && emitted > 0 {
		return
	}
	if err != nil {
		b.appendAlert(fmt.Sprintf("Supplemental Everything failed on %s: %v", cleanRoot, err))
	}

	before := b.snapshotInitialTaskTotal()
	b.walkRootDirConcurrent(cleanRoot, initial)
	after := b.snapshotInitialTaskTotal()
	if after > before {
		return
	}

	shellEmitted, shellErr := b.walkRootWithShellFallback(cleanRoot, initial, 20*time.Minute)
	if shellErr != nil {
		b.appendAlert(fmt.Sprintf("Supplemental shell scan failed on %s: %v", cleanRoot, shellErr))
	}
	if shellEmitted <= 0 {
		b.appendAlert(fmt.Sprintf("Supplemental scan still found 0 files on %s", cleanRoot))
	}
}

func (b *blugeIndexer) walkRootWithShellFallback(cleanRoot string, initial bool, timeout time.Duration) (int, error) {
	extWhitelist := b.everythingExtWhitelist()
	if len(extWhitelist) == 0 {
		return 0, nil
	}

	exts := make([]string, 0, len(extWhitelist))
	for ext := range extWhitelist {
		if ext != "" {
			exts = append(exts, strings.ToLower(ext))
		}
	}
	sort.Strings(exts)
	listArg := "'" + strings.Join(exts, "','") + "'"
	rootArg := strings.ReplaceAll(cleanRoot, "'", "''")
	script := fmt.Sprintf(
		"$exts=@(%s); Get-ChildItem -LiteralPath '%s' -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object { $exts -contains $_.Extension.TrimStart('.').ToLowerInvariant() } | ForEach-Object { $_.FullName }",
		listArg,
		rootArg,
	)

	ctx := b.ctx
	cancel := func() {}
	if timeout > 0 {
		var c context.CancelFunc
		ctx, c = context.WithTimeout(b.ctx, timeout)
		cancel = c
	}
	defer cancel()

	cmd := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-Command", script)
	out, err := cmd.Output()
	if ctx.Err() == context.DeadlineExceeded {
		return 0, fmt.Errorf("timeout after %s", timeout)
	}
	if err != nil {
		return 0, err
	}

	emitted := 0
	for _, line := range strings.Split(string(out), "\n") {
		p := filepath.Clean(strings.TrimSpace(strings.TrimRight(line, "\r")))
		if p == "" || b.shouldSkipFileByName(p) {
			continue
		}
		if initial {
			b.mu.Lock()
			b.initialTaskTotal++
			b.status.DiscoveredFiles = b.initialTaskTotal
			b.refreshProgressLocked()
			b.mu.Unlock()
		}
		b.enqueueTask(indexTask{Path: p, Initial: initial, Sync: !initial})
		emitted++
	}
	return emitted, nil
}

func (b *blugeIndexer) walkRootWithEverythingWithTimeout(cleanRoot string, initial bool, timeout time.Duration) (int, error) {
	if timeout <= 0 {
		timeout = defaultEverythingTimeout
	}
	type result struct {
		emitted int
		err     error
	}
	done := make(chan result, 1)
	go func() {
		emitted, err := b.walkRootWithEverything(cleanRoot, initial)
		done <- result{emitted: emitted, err: err}
	}()

	select {
	case <-b.ctx.Done():
		return 0, b.ctx.Err()
	case r := <-done:
		return r.emitted, r.err
	case <-time.After(timeout):
		return 0, fmt.Errorf("everything enumerate timeout after %s", timeout)
	}
}

func (b *blugeIndexer) walkRootWithEverything(cleanRoot string, initial bool) (int, error) {
	extWhitelist := b.everythingExtWhitelist()
	files, err := everythingListFilesForIndex(b.cfg.BaseDir, []string{cleanRoot}, extWhitelist)
	if err != nil {
		return 0, err
	}
	emitted := 0
	for _, f := range files {
		select {
		case <-b.ctx.Done():
			return emitted, context.Canceled
		default:
		}
		if b.shouldSkipFileByName(f.Path) {
			continue
		}
		if initial {
			b.mu.Lock()
			b.initialTaskTotal++
			b.status.DiscoveredFiles = b.initialTaskTotal
			b.refreshProgressLocked()
			b.mu.Unlock()
		}
		b.enqueueTask(indexTask{Path: f.Path, Initial: initial, Sync: !initial})
		emitted++
	}
	return emitted, nil
}

func (b *blugeIndexer) everythingExtWhitelist() map[string]struct{} {
	out := make(map[string]struct{}, len(b.cfg.FilterConfig.ColdExts)+len(b.cfg.FilterConfig.HotExts))
	for ext := range b.cfg.FilterConfig.ColdExts {
		out[normalizeExt(ext)] = struct{}{}
	}
	for ext := range b.cfg.FilterConfig.HotExts {
		out[normalizeExt(ext)] = struct{}{}
	}
	delete(out, "")
	return out
}

func (b *blugeIndexer) walkRootDirConcurrent(cleanRoot string, initial bool) {
	walkCtx := b.ctx
	cancel := func() {}
	if initial {
		var c context.CancelFunc
		walkCtx, c = context.WithTimeout(b.ctx, defaultRootWalkTimeout)
		cancel = c
	}
	defer cancel()

	sem := make(chan struct{}, max(4, runtime.NumCPU()))
	var wg sync.WaitGroup

	var walkDir func(string)
	walkDir = func(dir string) {
		b.addWatch(dir)
		entries, err := readDirWithTimeout(dir, defaultReadDirTimeout)
		if err != nil {
			if errors.Is(err, context.DeadlineExceeded) {
				b.appendAlert(fmt.Sprintf("read dir timeout: %s", dir))
			}
			return
		}
		for _, ent := range entries {
			path := filepath.Join(dir, ent.Name())
			select {
			case <-walkCtx.Done():
				return
			default:
			}
			if ent.IsDir() {
				if b.shouldSkipDir(path, ent.Name()) {
					continue
				}
				if initial && normalizePathKey(path) == normalizePathKey(cleanRoot) {
					b.mu.Lock()
					b.status.ScanPhase = "walking"
					b.status.IndexingFile = "Walking root: " + cleanRoot
					b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
					b.mu.Unlock()
				}
				wg.Add(1)
				go func(p string) {
					defer wg.Done()
					sem <- struct{}{}
					defer func() { <-sem }()
					walkDir(p)
				}(path)
				continue
			}
			if b.shouldSkipFileByName(path) {
				continue
			}
			if initial {
				b.mu.Lock()
				b.initialTaskTotal++
				b.status.DiscoveredFiles = b.initialTaskTotal
				b.refreshProgressLocked()
				b.mu.Unlock()
			}
			b.enqueueTask(indexTask{Path: path, Initial: initial, Sync: !initial})
		}
	}

	b.mu.Lock()
	b.status.ScanPhase = "walking"
	b.status.IndexingFile = "Walking root: " + cleanRoot
	b.mu.Unlock()

	wg.Add(1)
	go func() {
		defer wg.Done()
		sem <- struct{}{}
		defer func() { <-sem }()
		walkDir(cleanRoot)
	}()
	wg.Wait()
	if initial && errors.Is(walkCtx.Err(), context.DeadlineExceeded) {
		b.appendAlert(fmt.Sprintf("walk timeout on %s after %s, continue with partial results", cleanRoot, defaultRootWalkTimeout))
	}
}

func readDirWithTimeout(dir string, timeout time.Duration) ([]os.DirEntry, error) {
	type result struct {
		entries []os.DirEntry
		err     error
	}
	ch := make(chan result, 1)
	go func() {
		entries, err := os.ReadDir(dir)
		ch <- result{entries: entries, err: err}
	}()
	if timeout <= 0 {
		r := <-ch
		return r.entries, r.err
	}
	select {
	case r := <-ch:
		return r.entries, r.err
	case <-time.After(timeout):
		return nil, context.DeadlineExceeded
	}
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
				b.status.ProcessedFiles = b.initialTaskDone
				if b.initialWalkDone && b.initialTaskDone >= b.initialTaskTotal {
					b.status.InitialScanDone = true
					b.status.Ready = true
					b.status.ScanPhase = "ready"
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

func (b *blugeIndexer) waitInitialIdleOnce() bool {
	if b.cfg.IdleIndexAfter <= 0 {
		return true
	}
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		if userIdleForAtLeast(b.cfg.IdleIndexAfter) {
			b.mu.Lock()
			b.idleWaitNotified = false
			b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
			b.mu.Unlock()
			return true
		}
		b.mu.Lock()
		if !b.idleWaitNotified {
			b.appendAlertLocked("initial cold indexing waits for user idle state")
			b.idleWaitNotified = true
		}
		b.status.ScanPhase = "idle_wait"
		b.status.IndexingFile = "waiting for idle state before indexing"
		b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
		b.mu.Unlock()
		select {
		case <-b.ctx.Done():
			return false
		case <-ticker.C:
		}
	}
}

func (b *blugeIndexer) waitForWritableDisk() bool {
	for {
		freeBytes, err := freeDiskBytesAtPath(b.cfg.IndexDir)
		if err != nil {
			b.appendAlert("disk free space check failed; continue indexing")
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
	b.status.LastError = "free disk space below 500MB; indexing writes paused"
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.appendAlertLocked("free disk space below 500MB; paused indexing writes")
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
	task.Path = filepath.Clean(strings.TrimSpace(task.Path))
	if task.Path == "" {
		return
	}
	if !filepath.IsAbs(task.Path) {
		if abs, err := filepath.Abs(task.Path); err == nil && abs != "" {
			task.Path = filepath.Clean(abs)
		}
	}
	if b.isIndexDirPath(task.Path) {
		return
	}

	key := normalizePathKey(task.Path)
	b.mu.Lock()
	if ts, ok := b.recentEnqueue[key]; ok {
		if !task.Initial && time.Since(ts) < 250*time.Millisecond {
			b.mu.Unlock()
			return
		}
	}
	b.recentEnqueue[key] = time.Now()
	for k, ts := range b.recentEnqueue {
		if time.Since(ts) > recentEnqueueKeep {
			delete(b.recentEnqueue, k)
		}
	}
	b.mu.Unlock()

	if task.Initial || task.Sync {
		// Initial-scan tasks cannot be dropped, otherwise total grows while done does not.
		select {
		case b.tasks <- task:
		case <-b.ctx.Done():
			return
		}
	} else {
		select {
		case b.tasks <- task:
		default:
			b.appendAlert("index task queue is full; dropped partial events")
			return
		}
	}
	b.mu.Lock()
	pending := len(b.tasks)
	capacity := cap(b.tasks)
	b.status.PendingTasks = pending
	b.status.QueueCapacity = capacity
	b.status.QueueSaturated = capacity > 0 && pending >= capacity
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
}

type recentPathEntry struct {
	path string
	ts   time.Time
}

func (b *blugeIndexer) collectRecentUnindexedPaths(window time.Duration, maxCandidates int) []string {
	if window <= 0 || maxCandidates <= 0 {
		return nil
	}
	cutoff := time.Now().Add(-window)
	entries := make([]recentPathEntry, 0, 64)

	b.mu.RLock()
	for p, ts := range b.recentEnqueue {
		if ts.Before(cutoff) {
			continue
		}
		entries = append(entries, recentPathEntry{path: p, ts: ts})
	}
	b.mu.RUnlock()
	if len(entries) == 0 {
		return nil
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].ts.After(entries[j].ts)
	})

	out := make([]string, 0, maxCandidates)
	for _, it := range entries {
		if len(out) >= maxCandidates {
			break
		}
		p := filepath.Clean(it.path)
		if p == "" {
			continue
		}
		if b.shouldSkipFileByName(p) || b.isIndexDirPath(p) {
			continue
		}
		st, err := os.Stat(p)
		if err != nil || st.IsDir() {
			continue
		}
		if st.ModTime().Before(cutoff) {
			continue
		}
		if !b.shouldIndexByColdPath(p, st.Size()) {
			continue
		}
		if !b.needsIndexingLocked(p, st) {
			continue
		}
		out = append(out, p)
	}
	return out
}

func (b *blugeIndexer) needsIndexingLocked(path string, st os.FileInfo) bool {
	id := docIDForPath(path)
	modNano := st.ModTime().UnixNano()
	size := st.Size()

	b.mu.RLock()
	if fp, ok := b.knownFiles[id]; ok {
		if fp.Size == size && fp.ModNano == modNano {
			b.mu.RUnlock()
			return false
		}
	}
	b.mu.RUnlock()

	if b.meta != nil {
		if old, ok, err := b.meta.Get(path); err == nil && ok {
			if old.Size == size && old.ModNano == modNano {
				return false
			}
		}
	}
	return true
}

func (b *blugeIndexer) indexFile(path string) error {
	path = filepath.Clean(strings.TrimSpace(path))
	if path == "" {
		return nil
	}
	if !filepath.IsAbs(path) {
		if abs, err := filepath.Abs(path); err == nil && abs != "" {
			path = filepath.Clean(abs)
		}
	}
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
	if !b.shouldIndexByColdPath(path, st.Size()) {
		return b.deleteByPath(path)
	}
	if st.Size() > b.cfg.HardReadLimit && pathExtLower(path) != "pdf" && pathExtLower(path) != "docx" {
		return b.deleteByPath(path)
	}

	id := docIDForPath(path)
	modNano := st.ModTime().UnixNano()
	if !b.cfg.ForceContentRecheck {
		b.mu.RLock()
		if prev, ok := b.knownFiles[id]; ok && prev.Size == st.Size() && prev.ModNano == modNano {
			b.mu.RUnlock()
			return nil
		}
		b.mu.RUnlock()
		if b.meta != nil {
			if old, ok, gerr := b.meta.Get(path); gerr == nil && ok && old.Size == st.Size() && old.ModNano == modNano {
				b.mu.Lock()
				if _, exists := b.knownFiles[id]; !exists {
					b.knownFiles[id] = old
					if b.status.IndexedFiles < int64(len(b.knownFiles)) {
						b.status.IndexedFiles = int64(len(b.knownFiles))
					}
				}
				b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
				b.mu.Unlock()
				return nil
			}
		}
	}
	content, summary, err := b.readFileForIndex(path, st.Size())
	if err != nil {
		if errors.Is(err, errSkipNonText) || errors.Is(err, errSkipTooLarge) {
			if b.cfg.IndexMetaOnly {
				return b.indexFileMetaOnly(path, st, err)
			}
			return b.deleteByPath(path)
		}
		return fmt.Errorf("read index content failed (%s): %w", path, err)
	}

	contentCRC := crc32.ChecksumIEEE([]byte(content))
	fp := fileFingerprint{Size: st.Size(), ModNano: modNano, ContentHash: contentCRC}

	if b.meta != nil {
		if oldFP, ok, gerr := b.meta.Get(path); gerr == nil && ok && oldFP == fp {
			return nil
		}
	}
	b.mu.RLock()
	if prev, ok := b.knownFiles[id]; ok && prev == fp {
		b.mu.RUnlock()
		return nil
	}
	b.mu.RUnlock()

	ext := strings.TrimPrefix(strings.ToLower(filepath.Ext(path)), ".")
	mod := st.ModTime()
	baseName := strings.ToLower(filepath.Base(path))
	headers := buildIndexHeaders(path, content, summary)

	doc := bluge.NewDocument(id).
		AddField(bluge.NewKeywordField("path", path).StoreValue()).
		AddField(bluge.NewKeywordField("path_lower", strings.ToLower(path)).StoreValue()).
		AddField(bluge.NewTextField("title", baseName).WithAnalyzer(fullTextAnalyzer()).SearchTermPositions().StoreValue()).
		AddField(bluge.NewTextField("headers", headers).WithAnalyzer(fullTextAnalyzer()).SearchTermPositions().StoreValue()).
		AddField(bluge.NewTextField("content", content).WithAnalyzer(fullTextAnalyzer()).SearchTermPositions()).
		AddField(bluge.NewKeywordField("ext", ext).StoreValue().Sortable().Aggregatable()).
		AddField(bluge.NewDateTimeField("mtime", mod).StoreValue().Sortable()).
		AddField(bluge.NewNumericField("size", float64(st.Size())).StoreValue().Sortable()).
		AddField(bluge.NewStoredOnlyField("summary", []byte(summary))).
		AddField(bluge.NewTextField("path_text", strings.ToLower(path)).WithAnalyzer(fullTextAnalyzer()))

	if err := b.enqueueBatchUpdate(id, doc); err != nil {
		return fmt.Errorf("bluge update failed (%s): %w", path, err)
	}

	b.mu.Lock()
	b.knownFiles[id] = fp
	if b.status.IndexedFiles < int64(len(b.knownFiles)) {
		b.status.IndexedFiles = int64(len(b.knownFiles))
	}
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
	if b.meta != nil {
		_ = b.meta.Upsert(path, fp)
	}
	return nil
}

func (b *blugeIndexer) indexFileMetaOnly(path string, st os.FileInfo, reason error) error {
	if st == nil || st.IsDir() {
		return nil
	}
	id := docIDForPath(path)
	mod := st.ModTime()
	baseName := strings.ToLower(filepath.Base(path))
	ext := strings.TrimPrefix(strings.ToLower(filepath.Ext(path)), ".")
	metaText := strings.ToLower(path + " " + baseName)
	summary := "meta-only"
	if reason != nil {
		if errors.Is(reason, errSkipTooLarge) {
			summary = "meta-only: too large"
		} else if errors.Is(reason, errSkipNonText) {
			summary = "meta-only: non-text"
		}
	}

	doc := bluge.NewDocument(id).
		AddField(bluge.NewKeywordField("path", path).StoreValue()).
		AddField(bluge.NewKeywordField("path_lower", strings.ToLower(path)).StoreValue()).
		AddField(bluge.NewTextField("title", baseName).WithAnalyzer(fullTextAnalyzer()).SearchTermPositions().StoreValue()).
		AddField(bluge.NewTextField("headers", metaText).WithAnalyzer(fullTextAnalyzer()).SearchTermPositions().StoreValue()).
		AddField(bluge.NewTextField("content", "").WithAnalyzer(fullTextAnalyzer()).SearchTermPositions()).
		AddField(bluge.NewKeywordField("ext", ext).StoreValue().Sortable().Aggregatable()).
		AddField(bluge.NewDateTimeField("mtime", mod).StoreValue().Sortable()).
		AddField(bluge.NewNumericField("size", float64(st.Size())).StoreValue().Sortable()).
		AddField(bluge.NewStoredOnlyField("summary", []byte(summary))).
		AddField(bluge.NewTextField("path_text", strings.ToLower(path)).WithAnalyzer(fullTextAnalyzer()))
	if err := b.enqueueBatchUpdate(id, doc); err != nil {
		return fmt.Errorf("bluge meta-only update failed (%s): %w", path, err)
	}

	fp := fileFingerprint{Size: st.Size(), ModNano: st.ModTime().UnixNano(), ContentHash: 0}
	b.mu.Lock()
	b.knownFiles[id] = fp
	if b.status.IndexedFiles < int64(len(b.knownFiles)) {
		b.status.IndexedFiles = int64(len(b.knownFiles))
	}
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
	if b.meta != nil {
		_ = b.meta.Upsert(path, fp)
	}
	return nil
}

func (b *blugeIndexer) deleteByPath(path string) error {
	path = filepath.Clean(strings.TrimSpace(path))
	if path == "" {
		return nil
	}
	if !filepath.IsAbs(path) {
		if abs, err := filepath.Abs(path); err == nil && abs != "" {
			path = filepath.Clean(abs)
		}
	}
	id := docIDForPath(path)
	if err := b.enqueueBatchDelete(id); err != nil {
		return fmt.Errorf("bluge delete failed (%s): %w", path, err)
	}
	b.mu.Lock()
	delete(b.knownFiles, id)
	if b.status.IndexedFiles > 0 {
		b.status.IndexedFiles--
	}
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
	if b.meta != nil {
		_ = b.meta.Delete(path)
	}
	return nil
}

func buildIndexHeaders(path, content, summary string) string {
	parts := make([]string, 0, 8)
	base := strings.ToLower(filepath.Base(path))
	if base != "" {
		parts = append(parts, base)
	}
	ext := pathExtLower(path)
	if ext != "" {
		parts = append(parts, ext)
	}
	dir := strings.ToLower(filepath.Dir(path))
	if dir != "" && dir != "." {
		parts = append(parts, dir)
	}
	if summary != "" {
		parts = append(parts, summary)
	}
	if content != "" {
		lines := strings.Split(strings.ReplaceAll(content, "\r\n", "\n"), "\n")
		collected := 0
		for _, ln := range lines {
			line := strings.TrimSpace(ln)
			if line == "" {
				continue
			}
			parts = append(parts, line)
			collected++
			if collected >= 2 {
				break
			}
		}
	}
	return strings.Join(parts, "\n")
}

func (b *blugeIndexer) buildBestPreview(match *blugeSearch.DocumentMatch, query, path, title, headers, summary string) string {
	fallback := strings.TrimSpace(summary)
	if fallback == "" {
		fallback = strings.TrimSpace(headers)
	}
	if fallback == "" {
		fallback = title
	}
	if match == nil || len(match.Locations) == 0 {
		return fallback
	}

	highlighter := blugeHighlight.NewHTMLHighlighterTags("<mark>", "</mark>")
	if tlm := match.Locations["headers"]; len(tlm) > 0 && strings.TrimSpace(headers) != "" {
		if frag := strings.TrimSpace(highlighter.BestFragment(tlm, []byte(headers))); frag != "" {
			return frag
		}
	}
	if tlm := match.Locations["title"]; len(tlm) > 0 && strings.TrimSpace(title) != "" {
		if frag := strings.TrimSpace(highlighter.BestFragment(tlm, []byte(title))); frag != "" {
			return frag
		}
	}
	if tlm := match.Locations["content"]; len(tlm) > 0 {
		if text := b.loadPreviewText(path); text != "" {
			if frag := strings.TrimSpace(highlighter.BestFragment(tlm, []byte(text))); frag != "" {
				return frag
			}
		}
	}
	if strings.TrimSpace(fallback) != "" {
		return fallback
	}
	return strings.TrimSpace(query)
}

func (b *blugeIndexer) loadPreviewText(path string) string {
	st, err := os.Stat(path)
	if err != nil || st.IsDir() || st.Size() <= 0 {
		return ""
	}
	if st.Size() > 8*1024*1024 {
		return ""
	}
	text, _, err := b.readFileForIndex(path, st.Size())
	if err != nil {
		return ""
	}
	return text
}

func (b *blugeIndexer) matchToResultItem(match *blugeSearch.DocumentMatch, query string) map[string]any {
	var (
		pathVal    string
		summaryVal string
		headersVal string
		titleVal   string
		extVal     string
		mtimeVal   time.Time
		sizeVal    int64
	)

	_ = match.VisitStoredFields(func(field string, value []byte) bool {
		switch field {
		case "path":
			pathVal = string(value)
		case "summary":
			summaryVal = string(value)
		case "headers":
			headersVal = string(value)
		case "title":
			titleVal = string(value)
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
	if isExcludedByFilter(pathVal, b.cfg.FilterConfig) {
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

	terms := extractSearchContentTerms(query)
	primaryTerm := pickPrimarySearchTerm(terms)
	previewVal := b.buildBestPreview(match, query, pathVal, titleVal, headersVal, summaryVal)
	score := scoreByPathAndContent(pathVal, previewVal, primaryTerm, float64(match.Score))
	hitCtx := buildHitContextForFile(pathVal, primaryTerm, 6)
	hitLines := make([]int, 0, len(hitCtx))
	for _, blk := range hitCtx {
		if ln, ok := blk["line"].(int); ok {
			hitLines = append(hitLines, ln)
		}
	}
	hitCount := len(hitLines)
	if hitCount == 0 {
		hitCount, hitLines = b.computeHitStats(pathVal, primaryTerm)
	}
	qLower := strings.ToLower(strings.TrimSpace(primaryTerm))
	snippetHit := qLower != "" && strings.Contains(strings.ToLower(previewVal), qLower)
	pathHit := qLower != "" && strings.Contains(strings.ToLower(pathVal), qLower)
	// When query has only structured filters (e.g. ext:txt), keep matched docs.
	if len(terms) > 0 && hitCount == 0 && !snippetHit && !pathHit {
		return nil
	}
	if hitCount == 0 && (snippetHit || pathHit) {
		hitCount = 1
	}
	if hitCount > 0 {
		subParts = append(subParts, fmt.Sprintf("hits %d", hitCount))
	}
	meta := map[string]any{
		"FilePath":       pathVal,
		"FileName":       fileName,
		"DirPath":        dirPath,
		"Ext":            extFromPath,
		"IsDirectory":    false,
		"FullTextHit":    true,
		"MatchedLine":    previewVal,
		"DateModified":   ts,
		"IndexedBy":      "bluge",
		"SearchScore":    score,
		"IndexedSize":    sizeVal,
		"IndexedExtName": extVal,
		"HitCount":       hitCount,
		"HitLines":       hitLines,
		"HitContext":     hitCtx,
	}

	return map[string]any{
		"originalDataType": "fulltext",
		"DataType":         "file",
		"DataTypeName":     "FullText",
		"ID":               pathVal,
		"Title":            fileName,
		"SubTitle":         strings.Join(subParts, " | "),
		"Content":          pathVal,
		"Preview":          previewVal,
		"Source":           "File",
		"Metadata":         meta,
		"Action":           "open_file",
		"ActionParams":     map[string]any{"FilePath": pathVal},
	}
}

func (b *blugeIndexer) computeHitStats(path, query string) (int, []int) {
	q := strings.TrimSpace(query)
	if q == "" {
		return 0, nil
	}
	st, err := os.Stat(path)
	if err != nil || st.IsDir() || st.Size() <= 0 {
		return 0, nil
	}
	ext := pathExtLower(path)
	if ext == "pdf" || st.Size() > 8*1024*1024 {
		return 0, nil
	}
	text, _, err := b.readFileForIndex(path, st.Size())
	if err != nil || text == "" {
		return 0, nil
	}
	return countHitsAndLines(text, q, 6)
}

func countHitsAndLines(text, query string, lineLimit int) (int, []int) {
	if text == "" || query == "" {
		return 0, nil
	}
	src := strings.ToLower(text)
	q := strings.ToLower(query)
	count := 0
	for pos := 0; ; {
		i := strings.Index(src[pos:], q)
		if i < 0 {
			break
		}
		count++
		pos += i + len(q)
		if pos >= len(src) {
			break
		}
	}
	lines := make([]int, 0, lineLimit)
	if lineLimit > 0 {
		parts := strings.Split(text, "\n")
		for i, ln := range parts {
			if strings.Contains(strings.ToLower(ln), q) {
				lines = append(lines, i+1)
				if len(lines) >= lineLimit {
					break
				}
			}
		}
	}
	return count, lines
}

func (b *blugeIndexer) shouldSkipDir(path, dirName string) bool {
	if b.isIndexDirPath(path) {
		return true
	}
	if isExcludedByFilter(path, b.cfg.FilterConfig) {
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
	if isExcludedByFilter(path, b.cfg.FilterConfig) {
		return true
	}
	name := strings.ToLower(filepath.Base(path))
	if strings.HasPrefix(name, ".") && name != ".env" {
		return true
	}
	if !b.cfg.SkipCommonBinaryExt {
		return false
	}
	ext := strings.ToLower(filepath.Ext(name))
	switch ext {
	case ".exe", ".dll", ".db", ".wal", ".shm", ".jpg", ".jpeg", ".png", ".gif", ".ico", ".zip", ".7z", ".rar", ".mp4", ".mp3", ".avi", ".mkv":
		return true
	default:
		return false
	}
}

func (b *blugeIndexer) shouldIndexByColdPath(path string, size int64) bool {
	_ = path
	_ = size
	return true
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
	b.status.ScanPhase = "indexing"
	pending := len(b.tasks)
	capacity := cap(b.tasks)
	b.status.PendingTasks = pending
	b.status.QueueCapacity = capacity
	b.status.QueueSaturated = capacity > 0 && pending >= capacity
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
}

func (b *blugeIndexer) clearCurrentFile(path string) {
	b.mu.Lock()
	if b.status.IndexingFile == path {
		b.status.IndexingFile = ""
	}
	pending := len(b.tasks)
	capacity := cap(b.tasks)
	b.status.PendingTasks = pending
	b.status.QueueCapacity = capacity
	b.status.QueueSaturated = capacity > 0 && pending >= capacity
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
	pending := len(b.tasks)
	queueCap := cap(b.tasks)
	b.status.PendingTasks = pending
	b.status.QueueCapacity = queueCap
	b.status.QueueSaturated = queueCap > 0 && pending >= queueCap

	displayTotal := total
	if displayTotal <= 0 {
		// In incremental/warm mode there may be no known total yet; avoid showing 0/0.
		fallbackTotal := done + int64(pending)
		if fallbackTotal > 0 {
			displayTotal = fallbackTotal
		}
	}

	queueDisplay := fmt.Sprintf("%d", pending)
	if queueCap > 0 {
		queueDisplay = fmt.Sprintf("%d/%d", pending, queueCap)
	}

	b.status.DiscoveredFiles = displayTotal
	b.status.ProcessedFiles = done
	if !b.initialWalkDone && total > 0 && done >= total && pending == 0 && b.status.IndexingFile == "" {
		// Failsafe: if all discovered tasks are drained, promote to "walk done" even if a scanner goroutine stalls.
		b.initialWalkDone = true
	}
	if b.status.InitialScanDone {
		b.status.Progress = 100
		b.status.ProgressText = "100.0%"
		b.status.FilesPerSec = b.computeFilesPerSecLocked(done)
		b.status.ETASeconds = 0
		if total > 0 {
			b.status.ProgressDetail = fmt.Sprintf("Processed %d / %d, queue %s, roots %d", done, total, queueDisplay, len(b.cfg.Roots))
		} else {
			b.status.ProgressDetail = fmt.Sprintf("Indexed %d files, queue %s, roots %d", b.status.IndexedFiles, queueDisplay, len(b.cfg.Roots))
		}
		b.status.EfficiencyText = fmt.Sprintf("%.2f files/s", b.status.FilesPerSec)
		return
	}
	if total <= 0 {
		if b.initialWalkDone {
			b.status.Progress = 100
			b.status.InitialScanDone = true
			b.status.Ready = true
			b.status.ScanPhase = "ready"
		} else {
			b.status.Progress = 0
		}
		b.status.ProgressText = fmt.Sprintf("%.1f%%", b.status.Progress)
		b.status.FilesPerSec = b.computeFilesPerSecLocked(done)
		b.status.ETASeconds = 0
		b.status.ProgressDetail = fmt.Sprintf("Discovered %d, queue %s, roots %d", displayTotal, queueDisplay, len(b.cfg.Roots))
		b.status.EfficiencyText = fmt.Sprintf("%.2f files/s", b.status.FilesPerSec)
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
		b.status.ScanPhase = "ready"
	}
	displayProgress := b.status.Progress
	if done > 0 && displayProgress > 0 && displayProgress < 0.1 {
		displayProgress = 0.1
	}
	b.status.ProgressText = fmt.Sprintf("%.1f%%", displayProgress)
	fps := b.computeFilesPerSecLocked(done)
	b.status.FilesPerSec = fps
	if fps > 0 && done < total {
		b.status.ETASeconds = int64(float64(total-done) / fps)
	} else {
		b.status.ETASeconds = 0
	}
	b.status.ProgressDetail = fmt.Sprintf("Processed %d / %d, queue %s, roots %d", done, total, queueDisplay, len(b.cfg.Roots))
	etaText := formatETASeconds(b.status.ETASeconds)
	if etaText != "" {
		b.status.EfficiencyText = fmt.Sprintf("%.2f files/s, eta %s", fps, etaText)
	} else {
		b.status.EfficiencyText = fmt.Sprintf("%.2f files/s", fps)
	}
}

func (b *blugeIndexer) computeFilesPerSecLocked(done int64) float64 {
	if b.startedAt.IsZero() || done <= 0 {
		return 0
	}
	secs := time.Since(b.startedAt).Seconds()
	if secs <= 0 {
		return 0
	}
	return float64(done) / secs
}

func formatETASeconds(sec int64) string {
	if sec <= 0 {
		return ""
	}
	if sec < 60 {
		return fmt.Sprintf("%ds", sec)
	}
	if sec < 3600 {
		return fmt.Sprintf("%dm%ds", sec/60, sec%60)
	}
	return fmt.Sprintf("%dh%dm", sec/3600, (sec%3600)/60)
}

func (b *blugeIndexer) shouldWarmIncrementalSync() bool {
	if b == nil {
		return false
	}
	if b.cfg.ForceContentRecheck {
		return false
	}
	if len(b.knownFiles) == 0 {
		return false
	}
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.status.InitialScanDone
}

func (b *blugeIndexer) statePersistLoop() {
	t := time.NewTicker(3 * time.Second)
	defer t.Stop()
	for {
		select {
		case <-b.ctx.Done():
			b.persistIndexStateSnapshot()
			return
		case <-t.C:
			b.persistIndexStateSnapshot()
		}
	}
}

func (b *blugeIndexer) persistIndexStateSnapshot() {
	if b == nil || b.meta == nil {
		return
	}
	b.mu.RLock()
	snap := indexPersistState{
		InitialScanDone: b.status.InitialScanDone,
		IndexedFiles:    b.status.IndexedFiles,
		ScanPhase:       b.status.ScanPhase,
		LastUpdated:     b.status.LastUpdatedRFC3339,
	}
	b.mu.RUnlock()
	_ = b.meta.SaveIndexState(snap)
}

func loadFullTextConfig(baseDir string) fullTextConfig {
	filterCfg := loadFullTextFilterConfig(baseDir)
	roots := mergeAnyTXTRoots(baseDir, fullTextRoots(baseDir))
	indexDir, needHint := resolveIndexDir(baseDir)
	workers := resolveWorkerCount()
	scanSpeed := resolveScanSpeed()
	perFilePause := resolvePerFilePause(scanSpeed)
	includeLarge := parseBoolEnv("SEARCHCENTER_FT_INCLUDE_LARGE", false)
	maxFileSize := parseInt64Env("SEARCHCENTER_FT_MAX_FILE_MB", 8) * 1024 * 1024
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
	if v := parseInt64Env("SEARCHCENTER_FT_INITIAL_DELAY_SEC", 1); v > 0 {
		initialDelay = time.Duration(v) * time.Second
	}

	minFree := parseInt64Env("SEARCHCENTER_FT_MIN_FREE_MB", 500) * 1024 * 1024
	if minFree <= 0 {
		minFree = defaultMinFreeDiskBytes
	}

	batchMax := int(parseInt64Env("SEARCHCENTER_FT_BATCH_DOCS", defaultBatchMaxDocs))
	if batchMax < 1 {
		batchMax = defaultBatchMaxDocs
	}
	batchMS := parseInt64Env("SEARCHCENTER_FT_BATCH_MS", 1000)
	batchInterval := time.Duration(batchMS) * time.Millisecond
	if batchInterval < 50*time.Millisecond {
		batchInterval = 50 * time.Millisecond
	}

	return fullTextConfig{
		BaseDir:             baseDir,
		IndexDir:            indexDir,
		Roots:               roots,
		FilterConfig:        filterCfg,
		Workers:             workers,
		InitialDelay:        initialDelay,
		PerFilePause:        perFilePause,
		ScanSpeed:           scanSpeed,
		IncludeLargeText:    includeLarge,
		MaxFileSizeBytes:    maxFileSize,
		HardReadLimit:       hardLimit,
		QueueSize:           queueSize,
		MinFreeDiskBytes:    minFree,
		NeedUserIndexDir:    needHint,
		ExcludeDirs:         exclude,
		IdleIndexAfter:      time.Duration(filterCfg.IdleIndexAfter) * time.Second,
		BatchMaxDocs:        batchMax,
		BatchFlushInterval:  batchInterval,
		UseEverything:       parseBoolEnv("SEARCHCENTER_FT_USE_EVERYTHING", false),
		UseMFT:              parseBoolEnv("SEARCHCENTER_FT_USE_MFT", true),
		UseUSN:              parseBoolEnv("SEARCHCENTER_FT_USE_USN", true),
		SkipCommonBinaryExt: parseBoolEnv("SEARCHCENTER_FT_SKIP_COMMON_BINARY_EXT", false),
		IndexMetaOnly:       parseBoolEnv("SEARCHCENTER_FT_INDEX_META_ONLY", true),
		ForceContentRecheck: parseBoolEnv("SEARCHCENTER_FT_FORCE_RECHECK", false),
	}
}

func mergeAnyTXTRoots(baseDir string, preferred []string) []string {
	ntfsRoots := listNTFSDriveRoots()
	if len(ntfsRoots) == 0 {
		return preferred
	}

	out := make([]string, 0, len(ntfsRoots)+len(preferred))
	seen := map[string]struct{}{}
	for _, root := range ntfsRoots {
		clean := filepath.Clean(strings.TrimSpace(root))
		if clean == "" {
			continue
		}
		key := normalizePathKey(clean)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, clean)
	}
	for _, p := range preferred {
		clean := filepath.Clean(strings.TrimSpace(p))
		if clean == "" {
			continue
		}
		covered := false
		for _, root := range ntfsRoots {
			if pathHasRootPrefix(clean, root) {
				covered = true
				break
			}
		}
		if covered {
			continue
		}
		key := normalizePathKey(clean)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, clean)
	}
	return out
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
	// Use per-workspace index directory by default so multiple SearchCenterCore
	// instances do not contend for one shared lock file under LOCALAPPDATA.
	baseKey := strings.ToLower(filepath.Clean(baseDir))
	tag := fmt.Sprintf("%08x", crc32.ChecksumIEEE([]byte(baseKey)))
	return filepath.Join(local, "SearchCenter", "bluge_index_"+tag), true
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

func parseHumanByteSize(s string) (float64, bool) {
	s = strings.TrimSpace(strings.ToLower(s))
	if s == "" {
		return 0, false
	}
	mult := 1.0
	switch {
	case strings.HasSuffix(s, "gb"):
		mult = 1024 * 1024 * 1024
		s = strings.TrimSuffix(s, "gb")
	case strings.HasSuffix(s, "mb"):
		mult = 1024 * 1024
		s = strings.TrimSuffix(s, "mb")
	case strings.HasSuffix(s, "kb"):
		mult = 1024
		s = strings.TrimSuffix(s, "kb")
	case len(s) > 0 && (s[len(s)-1] == 'k' || s[len(s)-1] == 'm' || s[len(s)-1] == 'g'):
		switch s[len(s)-1] {
		case 'g':
			mult = 1024 * 1024 * 1024
		case 'm':
			mult = 1024 * 1024
		case 'k':
			mult = 1024
		}
		s = s[:len(s)-1]
	}
	s = strings.TrimSpace(s)
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0, false
	}
	return v * mult, true
}

func blugeNumericRangeOnSize(spec string) (bluge.Query, bool) {
	spec = strings.TrimSpace(spec)
	if len(spec) < 2 {
		return nil, false
	}
	op := spec[0]
	rest := strings.TrimSpace(spec[1:])
	v, ok := parseHumanByteSize(rest)
	if !ok {
		return nil, false
	}
	switch op {
	case '>':
		return bluge.NewNumericRangeQuery(v, bluge.MaxNumeric).SetField("size"), true
	case '<':
		return bluge.NewNumericRangeQuery(bluge.MinNumeric, v).SetField("size"), true
	case '=':
		return bluge.NewNumericRangeInclusiveQuery(v, v, true, true).SetField("size"), true
	default:
		return nil, false
	}
}

func blugeDateRangeOnMtime(spec string) (bluge.Query, bool) {
	spec = strings.TrimSpace(spec)
	if len(spec) < 2 {
		return nil, false
	}
	op := spec[0]
	rest := strings.TrimSpace(spec[1:])
	var t time.Time
	var err error
	if t, err = time.ParseInLocation("2006-01-02", rest, time.Local); err != nil {
		if t, err = time.ParseInLocation("2006-01-02 15:04", rest, time.Local); err != nil {
			return nil, false
		}
	}
	var start, end time.Time
	switch op {
	case '>':
		start = t
		end = time.Now().Add(365000 * time.Hour)
	case '<':
		start = time.Time{}
		end = t
	default:
		return nil, false
	}
	return bluge.NewDateRangeQuery(start, end).SetField("mtime"), true
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
		pq := bluge.NewBooleanQuery()
		pq.AddShould(bluge.NewMatchPhraseQuery(ph).SetField("content").SetBoost(1))
		pq.AddShould(bluge.NewMatchPhraseQuery(strings.ToLower(ph)).SetField("headers").SetBoost(2.0))
		pq.AddShould(bluge.NewMatchPhraseQuery(strings.ToLower(ph)).SetField("title").SetBoost(10))
		pq.SetMinShould(1)
		root.AddMust(pq)
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
		case strings.HasPrefix(low, "size:"):
			v := strings.TrimPrefix(low, "size:")
			if qn, ok := blugeNumericRangeOnSize(v); ok {
				root.AddMust(qn)
			}
		case strings.HasPrefix(low, "mtime:"):
			v := strings.TrimPrefix(low, "mtime:")
			if qd, ok := blugeDateRangeOnMtime(v); ok {
				root.AddMust(qd)
			}
		case strings.HasPrefix(low, "dir:"):
			v := strings.TrimPrefix(low, "dir:")
			if v != "" {
				pat := "*" + strings.ToLower(v) + "*"
				root.AddMust(bluge.NewWildcardQuery(pat).SetField("path_lower"))
			}
		case strings.HasPrefix(low, "name:"):
			v := strings.TrimPrefix(low, "name:")
			if v != "" {
				lowv := strings.ToLower(v)
				if !strings.ContainsAny(lowv, "*?") {
					lowv = "*" + lowv + "*"
				}
				root.AddMust(bluge.NewWildcardQuery(lowv).SetField("path_lower"))
			}
		case strings.HasSuffix(low, "~") && len(low) > 1:
			root.AddMust(bluge.NewFuzzyQuery(strings.TrimSuffix(low, "~")).SetField("content"))
		case strings.HasSuffix(low, "*") && len(low) > 1:
			root.AddMust(bluge.NewPrefixQuery(strings.TrimSuffix(low, "*")).SetField("content"))
		case strings.ContainsAny(low, "*?"):
			root.AddMust(bluge.NewWildcardQuery(low).SetField("content"))
		default:
			mix := bluge.NewBooleanQuery()
			mix.AddShould(bluge.NewMatchQuery(tk).SetField("content").SetBoost(1))
			mix.AddShould(bluge.NewMatchQuery(strings.ToLower(tk)).SetField("headers").SetBoost(2.0))
			mix.AddShould(bluge.NewMatchQuery(strings.ToLower(tk)).SetField("path_text").SetBoost(3))
			mix.AddShould(bluge.NewMatchQuery(strings.ToLower(tk)).SetField("title").SetBoost(10))
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

func extractSearchContentTerms(raw string) []string {
	phrases, tokens := splitQueryWithPhrases(strings.TrimSpace(raw))
	out := make([]string, 0, len(phrases)+len(tokens))
	seen := map[string]struct{}{}
	for _, ph := range phrases {
		s := strings.TrimSpace(ph)
		if s == "" {
			continue
		}
		key := strings.ToLower(s)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, s)
	}
	for _, tk := range tokens {
		s := strings.TrimSpace(tk)
		if s == "" {
			continue
		}
		low := strings.ToLower(s)
		if strings.HasPrefix(low, "ext:") ||
			strings.HasPrefix(low, "path:") ||
			strings.HasPrefix(low, "size:") ||
			strings.HasPrefix(low, "mtime:") ||
			strings.HasPrefix(low, "dir:") ||
			strings.HasPrefix(low, "name:") {
			continue
		}
		s = strings.Trim(s, "*?")
		s = strings.TrimSuffix(s, "~")
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		key := strings.ToLower(s)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, s)
	}
	return out
}

func pickPrimarySearchTerm(terms []string) string {
	if len(terms) == 0 {
		return ""
	}
	best := terms[0]
	for _, t := range terms[1:] {
		if len([]rune(strings.TrimSpace(t))) > len([]rune(strings.TrimSpace(best))) {
			best = t
		}
	}
	return strings.TrimSpace(best)
}

func extractExtFilters(raw string) map[string]struct{} {
	_, tokens := splitQueryWithPhrases(strings.TrimSpace(raw))
	out := map[string]struct{}{}
	for _, tk := range tokens {
		low := strings.ToLower(strings.TrimSpace(tk))
		if !strings.HasPrefix(low, "ext:") {
			continue
		}
		ext := normalizeExt(strings.TrimPrefix(low, "ext:"))
		if ext != "" {
			out[ext] = struct{}{}
		}
	}
	return out
}

func itemExtLower(it map[string]any) string {
	if it == nil {
		return ""
	}
	if m, ok := it["Metadata"].(map[string]any); ok && m != nil {
		if v, ok := m["IndexedExtName"].(string); ok && strings.TrimSpace(v) != "" {
			return normalizeExt(v)
		}
		if v, ok := m["Ext"].(string); ok && strings.TrimSpace(v) != "" {
			return normalizeExt(v)
		}
	}
	p := itemFilePath(it)
	if p == "" {
		return ""
	}
	return pathExtLower(p)
}

func applyStructuredFiltersToItems(items []map[string]any, rawQuery string) []map[string]any {
	if len(items) == 0 {
		return items
	}
	extFilters := extractExtFilters(rawQuery)
	if len(extFilters) == 0 {
		return items
	}
	out := make([]map[string]any, 0, len(items))
	for _, it := range items {
		ext := itemExtLower(it)
		if _, ok := extFilters[ext]; !ok {
			continue
		}
		out = append(out, it)
	}
	return out
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

	ticker := time.NewTicker(200 * time.Millisecond)
	defer ticker.Stop()

	var lastPayload string
	for {
		payload := GetProgressPayload()
		b, _ := json.Marshal(payload)
		s := string(b)
		if s != lastPayload {
			lastPayload = s
			_, _ = fmt.Fprintf(w, "data: %s\n\n", b)
			flusher.Flush()
		}

		select {
		case <-r.Context().Done():
			return
		case <-ticker.C:
		}
	}
}
