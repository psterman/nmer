//go:build windows

package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode/utf16"
	"unicode/utf8"
	"unsafe"
)

const (
	evReqPathFileName = 0x00000004
	evReqSize         = 0x00000020
	evReqDateModified = 0x00000080
	evReqAttributes   = 0x00000200
	fileAttrDirectory = 0x10
)

func everythingDLLPath(baseDir string) string {
	return filepath.Join(baseDir, "lib", "everything64.dll")
}

func resolveEverythingExe(baseDir string) string {
	candidates := []string{
		filepath.Join(baseDir, "Everything64.exe"),
		filepath.Join(baseDir, "Everything.exe"),
		filepath.Join(os.Getenv("ProgramFiles"), "Everything", "Everything64.exe"),
		filepath.Join(os.Getenv("ProgramFiles"), "Everything", "Everything.exe"),
		filepath.Join(os.Getenv("ProgramFiles"), "voidtools", "Everything", "Everything64.exe"),
		filepath.Join(os.Getenv("ProgramFiles"), "voidtools", "Everything", "Everything.exe"),
	}
	if pf86 := os.Getenv("ProgramFiles(x86)"); pf86 != "" {
		candidates = append(candidates,
			filepath.Join(pf86, "Everything", "Everything64.exe"),
			filepath.Join(pf86, "Everything", "Everything.exe"),
			filepath.Join(pf86, "voidtools", "Everything", "Everything64.exe"),
			filepath.Join(pf86, "voidtools", "Everything", "Everything.exe"),
		)
	}
	for _, p := range candidates {
		if p == "" {
			continue
		}
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	return ""
}

func tryStartEverything(baseDir string) bool {
	if findEverythingPID() != 0 {
		return true
	}
	exe := resolveEverythingExe(baseDir)
	if exe == "" {
		return false
	}
	c := exec.Command(exe, "-startup")
	c.Dir = filepath.Dir(exe)
	c.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	_ = c.Start()
	time.Sleep(1800 * time.Millisecond)
	return findEverythingPID() != 0
}

func findEverythingPID() uint32 {
	// 使用 tasklist 简化检测（避免依赖额外 syscall 结构体版本差异）
	out, err := exec.Command("cmd", "/c", "tasklist", "/FI", "IMAGENAME eq Everything64.exe", "/FO", "CSV", "/NH").Output()
	if err == nil && strings.Contains(strings.ToLower(string(out)), "everything64.exe") {
		return 1
	}
	out2, err2 := exec.Command("cmd", "/c", "tasklist", "/FI", "IMAGENAME eq Everything.exe", "/FO", "CSV", "/NH").Output()
	if err2 == nil && strings.Contains(strings.ToLower(string(out2)), "everything.exe") {
		return 1
	}
	return 0
}

// everythingKeywordVariants 极短关键词（1～2 个字符的字母/数字等）在 Everything 中常被当成无效表达式、宏或最小长度未满足而 0 结果；
// 依次尝试通配子串、引号字面量、仅文件名(fn:)、原始串。更长关键词保持原样。
func everythingKeywordVariants(keyword string) []string {
	s := strings.TrimSpace(keyword)
	if s == "" {
		return nil
	}
	if utf8.RuneCountInString(s) > 2 {
		return []string{s}
	}
	seen := map[string]struct{}{}
	var out []string
	add := func(x string) {
		if x == "" {
			return
		}
		if _, ok := seen[x]; ok {
			return
		}
		seen[x] = struct{}{}
		out = append(out, x)
	}
	add("*" + s + "*")
	add(`"` + s + `"`)
	// voidtools：nopath: 仅匹配文件名（不含路径），短词在「全路径匹配」下易被稀释为 0
	add("nopath:*" + s + "*")
	add(s)
	return out
}

func everythingQuery(baseDir, keyword string, maxResults int, includeFolders bool) ([]map[string]any, error) {
	dllPath := everythingDLLPath(baseDir)
	if _, err := os.Stat(dllPath); err != nil {
		return nil, fmt.Errorf("未找到 lib\\everything64.dll: %w", err)
	}
	dll, err := syscall.LoadDLL(dllPath)
	if err != nil {
		return nil, fmt.Errorf("加载 everything64.dll: %w", err)
	}
	defer dll.Release()

	getMajor := dll.MustFindProc("Everything_GetMajorVersion")
	maj, _, _ := getMajor.Call()
	if maj == 0 {
		tryStartEverything(baseDir)
		time.Sleep(400 * time.Millisecond)
		maj, _, _ = getMajor.Call()
		if maj == 0 {
			return nil, fmt.Errorf("Everything IPC 不可用（未运行或权限不一致）")
		}
	}

	cleanup := dll.MustFindProc("Everything_CleanUp")
	setSearch := dll.MustFindProc("Everything_SetSearchW")
	setMax := dll.MustFindProc("Everything_SetMax")
	setReq := dll.MustFindProc("Everything_SetRequestFlags")
	query := dll.MustFindProc("Everything_QueryW")
	getNum := dll.MustFindProc("Everything_GetNumResults")
	getAttr := dll.MustFindProc("Everything_GetResultAttributes")
	getPath := dll.MustFindProc("Everything_GetResultFullPathNameW")
	getSize := dll.MustFindProc("Everything_GetResultSize")
	getDate := dll.MustFindProc("Everything_GetResultDateModified")
	getLastErr := dll.MustFindProc("Everything_GetLastError")

	variants := everythingKeywordVariants(keyword)
	if len(variants) == 0 {
		return nil, fmt.Errorf("搜索词为空")
	}

	req := evReqPathFileName | evReqSize | evReqDateModified | evReqAttributes
	var lastQueryErr error

	for vi, kw := range variants {
		_, _, _ = cleanup.Call()
		kwUTF16, err := syscall.UTF16PtrFromString(kw)
		if err != nil {
			lastQueryErr = err
			continue
		}
		_, _, _ = setSearch.Call(uintptr(unsafe.Pointer(kwUTF16)))
		_, _, _ = setMax.Call(uintptr(maxResults))
		_, _, _ = setReq.Call(uintptr(req))

		ok, _, _ := query.Call(uintptr(1))
		if ok == 0 {
			code, _, _ := getLastErr.Call()
			lastQueryErr = fmt.Errorf("Everything_QueryW 失败 lastError=%d", code)
			continue
		}

		n, _, _ := getNum.Call()
		count := int(n)
		if count == 0 {
			continue
		}
		if vi > 0 {
			log.Printf("[search] Everything 短关键词已用备用表达式命中: %q", kw)
		}
		if count > maxResults {
			count = maxResults
		}

		out := make([]map[string]any, 0, count)
		buf := make([]uint16, 4096)
		for i := 0; i < count; i++ {
			attr, _, _ := getAttr.Call(uintptr(i))
			isDir := (attr & fileAttrDirectory) != 0
			if !includeFolders && isDir {
				continue
			}
			r1, _, _ := getPath.Call(uintptr(i), uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)))
			if r1 == 0 {
				continue
			}
			nChars := int(r1)
			if nChars > len(buf) {
				nChars = len(buf)
			}
			fullPath := string(utf16.Decode(buf[:nChars]))
			if fullPath == "" {
				continue
			}
			var size int64
			sz, _, _ := getSize.Call(uintptr(i))
			size = int64(sz)
			ft, _, _ := getDate.Call(uintptr(i))
			item := buildEverythingFileItem(fullPath, isDir, size, int64(ft))
			out = append(out, item)
		}
		return out, nil
	}

	if lastQueryErr != nil {
		return nil, lastQueryErr
	}
	return []map[string]any{}, nil
}

func buildEverythingFileItem(fullPath string, isDir bool, fileSize int64, fileTime int64) map[string]any {
	dirPath, fileName, ext := splitPathParts(fullPath)
	sizeStr := formatSize(fileSize, isDir)
	dateStr := fileTimeToStr(fileTime)
	subTitleParts := []string{}
	if dirPath != "" {
		subTitleParts = append(subTitleParts, dirPath)
	}
	if isDir {
		subTitleParts = append(subTitleParts, "文件夹")
	} else {
		if ext != "" {
			subTitleParts = append(subTitleParts, ext)
		} else {
			subTitleParts = append(subTitleParts, "文件")
		}
	}
	if sizeStr != "" {
		subTitleParts = append(subTitleParts, sizeStr)
	}
	if dateStr != "" {
		subTitleParts = append(subTitleParts, dateStr)
	}
	subTitle := strings.Join(subTitleParts, " · ")

	dt := "file"
	dtn := "文件"
	if isDir {
		dt = "folder"
		dtn = "文件夹"
	}
	src := "文件"
	if isDir {
		src = "文件夹"
	}
	meta := map[string]any{
		"FilePath":     fullPath,
		"FileName":     fileName,
		"DirPath":      dirPath,
		"Ext":          ext,
		"IsDirectory":  isDir,
		"Size":         fileSize,
		"DateModified": fileTime,
		"Timestamp":    dateStr,
	}
	action := "open_file"
	if isDir {
		action = "open_folder"
	}
	return map[string]any{
		"originalDataType": "file",
		"DataType":         dt,
		"DataTypeName":     dtn,
		"ID":               fullPath,
		"Title":            fileName,
		"SubTitle":         subTitle,
		"Content":          fullPath,
		"Preview":          fullPath,
		"Source":           src,
		"Metadata":         meta,
		"Action":           action,
		"ActionParams":     map[string]any{"FilePath": fullPath},
	}
}

func splitPathParts(p string) (dir, base, ext string) {
	p = filepath.Clean(p)
	base = filepath.Base(p)
	dir = filepath.Dir(p)
	ext = filepath.Ext(base)
	return
}

func formatSize(sz int64, isDir bool) string {
	if isDir || sz <= 0 {
		return ""
	}
	const kb = 1024
	const mb = 1024 * kb
	const gb = 1024 * mb
	switch {
	case sz < kb:
		return strconv.FormatInt(sz, 10) + " B"
	case sz < mb:
		return trimFloat(float64(sz)/float64(kb)) + " KB"
	case sz < gb:
		return trimFloat(float64(sz)/float64(mb)) + " MB"
	default:
		return trimFloat(float64(sz)/float64(gb)) + " GB"
	}
}

func trimFloat(f float64) string {
	s := strconv.FormatFloat(f, 'f', 2, 64)
	s = strings.TrimRight(strings.TrimRight(s, "0"), ".")
	return s
}

func fileTimeToStr(ft int64) string {
	if ft == 0 {
		return ""
	}
	const epochDiff = 116444736000000000
	if ft < epochDiff {
		return ""
	}
	t := (ft - epochDiff) / 10000000
	tm := time.Unix(t, 0).Local()
	return tm.Format("2006-01-02 15:04")
}
