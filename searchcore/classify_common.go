package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

const (
	bonusApp           = 100.0
	bonusProject       = 30.0
	bonusConfig        = 15.0
	penaltyArchive     = 5.0
	penaltySystemTemp  = 50.0
	penaltyFolder      = 60.0
	penaltyFolderShallow = 10.0
	penaltyJunkLegacy  = 100.0
	penaltySubUserDev  = 20.0
	penaltyParentOverflow = 100.0
	penaltyNoiseZone   = 150.0
	penaltyInstallerJunk = 80.0
	penaltyDepthPerLevel = 8.0
)

var scriptExts = map[string]bool{
	".ahk": true, ".ps1": true, ".psm1": true, ".bat": true, ".cmd": true,
	".vbs": true, ".wsf": true, ".js": true, ".jse": true, ".py": true, ".rb": true,
}
var configExts = map[string]bool{
	".json": true, ".ini": true, ".yaml": true, ".yml": true, ".toml": true,
}
var archiveExts = map[string]bool{
	".zip": true, ".rar": true, ".7z": true, ".tar": true, ".gz": true, ".tgz": true,
	".bz2": true, ".xz": true, ".cab": true, ".iso": true,
}
var mediaExt = map[string]bool{
	".mp4": true, ".mkv": true, ".png": true, ".jpg": true, ".jpeg": true, ".gif": true,
	".mp3": true, ".wav": true, ".webp": true,
}

type assocBundle struct {
	FriendlyDocName string
	PerceivedType   string
	OpenCommand     string
	Executable      string
}

func normalizePath(p string) string {
	if p == "" {
		return ""
	}
	s := strings.ReplaceAll(p, "/", "\\")
	for strings.Contains(s, `\\`) {
		s = strings.ReplaceAll(s, `\\`, `\`)
	}
	return s
}

func lastPathSegment(path string) string {
	seg := path
	for {
		p := strings.Index(seg, "\\")
		if p < 0 {
			break
		}
		seg = seg[p+1:]
	}
	return seg
}

func parentFolderName(path string) string {
	path = strings.TrimRight(normalizePath(path), "\\")
	p := strings.LastIndex(path, "\\")
	if p < 0 {
		return ""
	}
	return path[:p]
}

func secondParentFolderName(path string) string {
	p := parentFolderName(path)
	if p == "" {
		return ""
	}
	return parentFolderName(p)
}

func countBackslashes(path string) int {
	return strings.Count(path, "\\")
}

func inferSubCategory(path string) string {
	pl := strings.ToLower(normalizePath(path))
	if pl == "" {
		return ""
	}
	patterns := []string{`\node_modules\`, `\vendor\`, `\.git\`, `\packages\`, `\venv\`, `\.venv\`,
		`\dist\`, `\build\`, `\.cargo\`, `\go\pkg\`, `\.gradle\`, `\.m2\`}
	for _, m := range patterns {
		if strings.Contains(pl, m) {
			return "DevResource"
		}
	}
	if strings.Contains(pl, `\appdata\`) || strings.Contains(pl, `\application data\`) ||
		regexp.MustCompile(`(?i)\\users\\[^\\]+\\appdata\\`).MatchString(pl) {
		return "User Data"
	}
	if strings.Contains(pl, `\windows\`) || strings.Contains(pl, `\program files\windows\`) {
		return "System"
	}
	return ""
}

func isJunkPath(path string) bool {
	pl := strings.ToLower(normalizePath(path))
	if pl == "" {
		return false
	}
	junk := []string{
		`\appdata\`, `\application data\`, `\cache\`, `\caches\`, `\temp\`, `\tmp\`,
		`\node_modules\`, `\.git\objects\`, `\winsxs\`, `\inetcache\`, `\cookies\`,
		`\crashpad\`, `\indexeddb\`, `\leveldb\`, `\gpu_cache\`, `\code cache\`,
		`\service worker\`, `\system32\`, `\library\`,
	}
	for _, m := range junk {
		if strings.Contains(pl, m) {
			return true
		}
	}
	return regexp.MustCompile(`(?i)appcrash[_\\]`).MatchString(pl)
}

func isNoiseZonePath(path string) bool {
	pl := strings.ToLower(normalizePath(path))
	noise := []string{`\appdata\`, `\application data\`, `\local\`, `\temp\`, `\tmp\`,
		`\node_modules\`, `\system32\`, `\syswow64\`, `\library\`, `\cache\`, `\caches\`}
	for _, m := range noise {
		if strings.Contains(pl, m) {
			return true
		}
	}
	return false
}

func isJunkPathKeyword(kw string) bool {
	kw = strings.ToLower(strings.TrimSpace(kw))
	if kw == "" {
		return false
	}
	for _, w := range []string{"appdata", "local", "temp", "tmp", "node_modules", "system32", "library", "cache", "winsxs"} {
		if kw == w {
			return true
		}
	}
	return false
}

func fullWordMatchLastSegment(path, keyword string) bool {
	if keyword == "" {
		return false
	}
	return strings.EqualFold(lastPathSegment(path), keyword)
}

func isVeryShallowPath(path string) bool {
	return countBackslashes(path) <= 2
}

func noiseZonePenaltyApplies(path, keyword string) bool {
	if isJunkPathKeyword(keyword) {
		return false
	}
	if !isNoiseZonePath(path) {
		return false
	}
	if fullWordMatchLastSegment(path, keyword) && isVeryShallowPath(path) {
		return false
	}
	return true
}

func isSubCategoryExemptKeyword(keyword string) bool {
	if isJunkPathKeyword(keyword) {
		return true
	}
	k := strings.ToLower(strings.TrimSpace(keyword))
	if k == "" {
		return false
	}
	long := []string{"node_modules", "vendor", "appdata", "gradle", "cargo", "packages", "venv", "system32", "winsxs"}
	for _, w := range long {
		if len(w) >= 5 && strings.Contains(k, w) {
			return true
		}
	}
	for _, w := range []string{"git", "pkg", "m2"} {
		if k == w {
			return true
		}
	}
	return false
}

func getPathTrustMultiplier(path string) float64 {
	pl := strings.ToLower(normalizePath(path))
	if pl == "" {
		return 1.0
	}
	if strings.Contains(pl, `\desktop\`) || strings.Contains(pl, `\documents\`) || strings.Contains(pl, `\我的文档`) {
		return 1.5
	}
	if strings.Contains(pl, `\start menu\`) || strings.Contains(pl, `\开始菜单`) || strings.Contains(pl, "program files") {
		return 1.5
	}
	return 1.0
}

func isSystemOrTempPath(path string) bool {
	pl := strings.ToLower(normalizePath(path))
	if pl == "" {
		return false
	}
	prefixes := []string{
		`\appdata\local\temp\`, `\windows\temp\`, `\$recycle.bin\`, `\windows\winsxs\`,
		`\windows\system32\`, `\windows\syswow64\`, `\windows\installer\`, `\windows\prefetch\`,
	}
	for _, p := range prefixes {
		if strings.Contains(pl, p) {
			return true
		}
	}
	return false
}

func isAppInstallerJunkName(fileName string) bool {
	if fileName == "" {
		return false
	}
	n := strings.ToLower(fileName)
	if i := strings.LastIndex(n, "."); i > 0 {
		n = n[:i]
	}
	for _, w := range []string{"uninst", "setup", "helper", "crash", "installer", "patch"} {
		if strings.Contains(n, w) {
			return true
		}
	}
	return false
}

func hasPackageJSON(dirPath string) bool {
	if dirPath == "" {
		return false
	}
	p := filepath.Join(dirPath, "package.json")
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}

func isProjectFolder(path, lastSegLower string) bool {
	if lastSegLower == ".git" {
		return true
	}
	if st, err := os.Stat(filepath.Join(path, ".git")); err == nil && st.IsDir() {
		return true
	}
	if hasPackageJSON(path) {
		return true
	}
	return false
}

func isFileInProjectDirectory(filePath string) bool {
	par := parentFolderName(filePath)
	if par == "" {
		return false
	}
	last := strings.ToLower(lastPathSegment(par))
	return isProjectFolder(par, last)
}

func computeIdentityAndPathAdjustments(category, path, keyword, subCategory, fileName string, isAppJunk, inProjectTree bool) (bonus, penalty float64) {
	fullMatch := fullWordMatchLastSegment(path, keyword)
	if isAppJunk && (category == "App" || category == "Document") {
		penalty += penaltyInstallerJunk
		return
	}
	switch category {
	case "App":
		if !isAppJunk {
			bonus += bonusApp
		}
	case "Project":
		bonus += bonusProject
	case "Config":
		bonus += bonusConfig
	case "Archive":
		penalty += penaltyArchive
	case "SystemTemp":
		if !fullMatch {
			penalty += penaltySystemTemp
		}
	case "Folder":
		if fullMatch && isVeryShallowPath(path) {
			penalty += penaltyFolderShallow
		} else {
			penalty += penaltyFolder
		}
	}
	if inProjectTree && category != "Project" {
		bonus += bonusProject
	}
	penalty += float64(countBackslashes(path)) * penaltyDepthPerLevel
	if noiseZonePenaltyApplies(path, keyword) {
		penalty += penaltyNoiseZone
	}
	noiseApplied := noiseZonePenaltyApplies(path, keyword)
	junkOn := isJunkPath(path) && !isJunkPathKeyword(keyword) && !noiseApplied
	if junkOn {
		penalty += penaltyJunkLegacy
	}
	if junkOn && (subCategory == "User Data" || subCategory == "DevResource") && !isSubCategoryExemptKeyword(keyword) {
		penalty += penaltySubUserDev
	}
	return
}

func getQuotaCategory(category string, isDir, inProjectTree bool) string {
	switch category {
	case "App":
		return "App"
	case "Project":
		return "Project"
	default:
		if inProjectTree && !isDir {
			return "Project"
		}
	}
	return "Other"
}

func categoryEmoji(category, subCat string, isDir bool) string {
	switch category {
	case "App":
		return "🚀"
	case "Project":
		return "📂"
	case "Folder":
		return "📁"
	case "SystemTemp":
		return "⚙️"
	case "Script":
		return "📜"
	default:
		if !isDir && subCat == "DevResource" {
			return "📦"
		}
	}
	return "📄"
}

func buildDisplaySubtitle(path string) string {
	p1 := parentFolderName(path)
	p2 := secondParentFolderName(path)
	if p1 != "" && p2 != "" {
		return lastPathSegment(p2) + " › " + lastPathSegment(p1) + " ›"
	}
	if p1 != "" {
		return lastPathSegment(p1) + " ›"
	}
	return ""
}

func buildDisplayPath(parentName, fileName string) string {
	if parentName != "" {
		return parentName + " › " + fileName
	}
	return fileName
}

func isScriptLike(extLower string, bundle assocBundle, friendlyLower string) bool {
	if scriptExts[extLower] {
		return true
	}
	if strings.Contains(friendlyLower, "script") || strings.Contains(friendlyLower, "脚本") {
		return true
	}
	oc := strings.ToLower(bundle.OpenCommand)
	ex := strings.ToLower(bundle.Executable)
	if strings.Contains(ex, "autohotkey") || strings.Contains(oc, "powershell") {
		return true
	}
	return false
}

func isMediaExt(extLower, perc string) bool {
	if mediaExt[extLower] {
		return true
	}
	return perc == "video" || perc == "audio" || perc == "image"
}

func getCategoryColor(category string) string {
	m := map[string]string{
		"App": "2ECC71", "Project": "9B59B6", "Config": "F39C12", "Archive": "95A5A6",
		"SystemTemp": "7F8C8D", "Script": "1ABC9C", "Media": "3498DB", "Document": "BDC3C7",
		"Folder": "E67E22", "Hidden": "34495E",
	}
	if c, ok := m[category]; ok {
		return c
	}
	return "BDC3C7"
}
