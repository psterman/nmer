package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type classifyTag struct {
	Category        string
	SubCategory     string
	DisplayTitle    string
	DisplaySubtitle string
	DisplayPath     string
	TypeHint        string
	TitleMarker     string
	PathTrust       float64
	BonusTotal      float64
	PenaltyTotal    float64
	FzyCategoryBonus float64
	QuotaCategory   string
	CategoryColor   string
}

func resolveItemPath(item map[string]any) string {
	if p := strVal(item["Preview"]); p != "" {
		return normalizePath(p)
	}
	if c := strVal(item["Content"]); c != "" {
		return normalizePath(c)
	}
	if meta, ok := item["Metadata"].(map[string]any); ok {
		if fp := strVal(meta["FilePath"]); fp != "" {
			return normalizePath(fp)
		}
	}
	return ""
}

func classifyOne(path string, bundle assocBundle, extLower, fileName, nameNoExt string, isDir bool, keyword string) classifyTag {
	subCat := inferSubCategory(path)
	friendly := bundle.FriendlyDocName
	friendlyL := strings.ToLower(friendly)
	perc := bundle.PerceivedType

	category := "Document"
	displayTitle := ""
	typeHint := ""
	displayPath := ""
	titleMarker := ""
	isAppJunk := isAppInstallerJunkName(fileName)
	inProjectTree := false

	baseName := fileName
	if baseName == "" && nameNoExt != "" {
		baseName = nameNoExt
	}
	if baseName == "" {
		baseName = lastPathSegment(path)
	}
	displaySubtitle := buildDisplaySubtitle(path)
	lastSeg := strings.ToLower(lastPathSegment(path))

	if isSystemOrTempPath(path) {
		category = "SystemTemp"
		typeHint = "系统或临时路径"
		displayPath = buildDisplayPath(parentFolderName(path), baseName)
		em := categoryEmoji("SystemTemp", subCat, isDir)
		displayTitle = em + baseName
	} else if isDir {
		if isProjectFolder(path, lastSeg) {
			category = "Project"
			typeHint = "项目/仓库"
			em := categoryEmoji("Project", subCat, true)
			displayTitle = em + baseName
			displayPath = displayTitle
		} else {
			category = "Folder"
			typeHint = "文件夹"
			em := categoryEmoji("Folder", subCat, true)
			displayTitle = em + baseName
			displayPath = displayTitle
		}
	} else if configExts[extLower] {
		category = "Config"
		if friendly != "" {
			typeHint = friendly
		} else {
			typeHint = "配置"
		}
		displayPath = buildDisplayPath(parentFolderName(path), baseName)
		displayTitle = categoryEmoji("Config", subCat, false) + baseName
		inProjectTree = isFileInProjectDirectory(path)
	} else if archiveExts[extLower] {
		category = "Archive"
		if friendly != "" {
			typeHint = friendly
		} else {
			typeHint = "压缩包"
		}
		displayPath = buildDisplayPath(parentFolderName(path), baseName)
		displayTitle = categoryEmoji("Document", subCat, false) + baseName
	} else if extLower == ".exe" || extLower == ".msi" || extLower == ".com" || extLower == ".scr" {
		category = "App"
		displayTitle = getFileDescriptionFromPath(path)
		if displayTitle == "" {
			if nameNoExt != "" {
				displayTitle = nameNoExt
			} else {
				displayTitle = baseName
			}
		}
		displayTitle = categoryEmoji("App", subCat, false) + displayTitle
		if friendly != "" {
			typeHint = friendly
		} else {
			typeHint = "应用程序"
		}
		displayPath = ""
	} else if extLower == ".lnk" {
		displayTitle = categoryEmoji("Document", subCat, false)
		if nameNoExt != "" {
			displayTitle += nameNoExt
		} else {
			displayTitle += baseName
		}
		category = "Document"
		typeHint = "快捷方式"
		displayPath = ""
	} else if isScriptLike(extLower, bundle, friendlyL) {
		category = "Script"
		if friendly != "" {
			typeHint = friendly
		} else {
			typeHint = "脚本"
		}
		displayPath = buildDisplayPath(parentFolderName(path), baseName)
		displayTitle = categoryEmoji("Script", subCat, false) + baseName
		inProjectTree = isFileInProjectDirectory(path)
	} else if isMediaExt(extLower, perc) {
		category = "Media"
		if friendly != "" {
			typeHint = friendly + " (" + perc + ")"
		} else if perc != "" {
			typeHint = perc
		}
		displayPath = buildDisplayPath(parentFolderName(path), baseName)
		displayTitle = categoryEmoji("Document", subCat, false) + baseName
	} else if perc == "application" && (extLower == ".dll" || extLower == ".cpl") {
		category = "App"
		dt := friendly
		if dt == "" {
			if nameNoExt != "" {
				dt = nameNoExt
			} else {
				dt = baseName
			}
		}
		displayTitle = categoryEmoji("App", subCat, false) + dt
		typeHint = friendly
		displayPath = ""
	} else {
		displayTitle = categoryEmoji("Document", subCat, false) + baseName
		if friendly != "" {
			typeHint = friendly
			if perc != "" {
				typeHint += " (" + perc + ")"
			}
		} else {
			typeHint = perc
		}
		displayPath = buildDisplayPath(parentFolderName(path), baseName)
		inProjectTree = isFileInProjectDirectory(path)
	}

	if typeHint == "" && friendly != "" {
		typeHint = friendly
	}
	if typeHint == "" && perc != "" {
		typeHint = perc
	}
	displayTitle = titleMarker + displayTitle

	pathTrust := getPathTrustMultiplier(path)
	bonus, penalty := computeIdentityAndPathAdjustments(category, path, keyword, subCat, fileName, isAppJunk, inProjectTree)
	qc := getQuotaCategory(category, isDir, inProjectTree)

	return classifyTag{
		Category:         category,
		SubCategory:      subCat,
		DisplayTitle:     displayTitle,
		DisplaySubtitle:  displaySubtitle,
		DisplayPath:      displayPath,
		TypeHint:         typeHint,
		TitleMarker:      titleMarker,
		PathTrust:        pathTrust,
		BonusTotal:       bonus,
		PenaltyTotal:     penalty,
		FzyCategoryBonus: bonus - penalty,
		QuotaCategory:    qc,
		CategoryColor:    getCategoryColor(category),
	}
}

func processFileItems(items []map[string]any, keyword string) {
	for _, item := range items {
		path := resolveItemPath(item)
		if path == "" {
			continue
		}
		isDir := false
		if meta, ok := item["Metadata"].(map[string]any); ok {
			if id, ok := meta["IsDirectory"].(bool); ok {
				isDir = id
			}
		}
		if !isDir {
			if st, err := os.Stat(path); err == nil && st.IsDir() {
				isDir = true
			}
		}
		ext := ""
		if meta, ok := item["Metadata"].(map[string]any); ok {
			ext = strVal(meta["Ext"])
		}
		fileName := filepath.Base(path)
		extFromPath := filepath.Ext(fileName)
		if ext == "" {
			ext = extFromPath
		}
		extLower := strings.ToLower(ext)
		if !strings.HasPrefix(extLower, ".") && extLower != "" {
			extLower = "." + extLower
		}
		nameNoExt := strings.TrimSuffix(fileName, extFromPath)

		bundle := getAssocBundleForExt(extLower)
		if extLower == "" || extLower == "." {
			bundle = getAssocBundleForExt(".")
		}
		tag := classifyOne(path, bundle, extLower, fileName, nameNoExt, isDir, keyword)

		item["DisplayTitle"] = tag.DisplayTitle
		item["DisplaySubtitle"] = tag.DisplaySubtitle
		item["DisplayPath"] = tag.DisplayPath
		item["Category"] = tag.Category
		item["SubCategory"] = tag.SubCategory
		item["TypeHint"] = tag.TypeHint
		item["TitleMarker"] = tag.TitleMarker
		item["PathTrust"] = tag.PathTrust
		item["BonusTotal"] = tag.BonusTotal
		item["PenaltyTotal"] = tag.PenaltyTotal
		item["FzyCategoryBonus"] = tag.FzyCategoryBonus
		item["QuotaCategory"] = tag.QuotaCategory
		item["CategoryColor"] = tag.CategoryColor

		if meta, ok := item["Metadata"].(map[string]any); ok {
			meta["Category"] = tag.Category
			meta["SubCategory"] = tag.SubCategory
			meta["TypeHint"] = tag.TypeHint
			meta["DisplayPath"] = tag.DisplayPath
			meta["DisplaySubtitle"] = tag.DisplaySubtitle
			meta["CategoryColor"] = tag.CategoryColor
			meta["QuotaCategory"] = tag.QuotaCategory
		}
	}
}

func sortFilesByFzy(items []map[string]any, keyword string) {
	kw := strings.TrimSpace(keyword)
	for i, item := range items {
		path := resolveItemPath(item)
		fzy := FzyScore(kw, path)
		tr := floatVal(item["PathTrust"])
		if tr == 0 {
			tr = 1.0
		}
		b := floatVal(item["BonusTotal"])
		p := floatVal(item["PenaltyTotal"])
		final := computeSearchItemFinalScore(path, fzy, tr, b, p)
		item["FzyBase"] = fzy
		item["FinalScore"] = final
		item["FzyScore"] = final
		item["_FzyStableIdx"] = i
		if meta, ok := item["Metadata"].(map[string]any); ok {
			meta["FzyScore"] = final
			meta["FzyBase"] = fzy
		}
	}
}

func applyExeNameBonus(items []map[string]any, keyword string) {
	kwLower := strings.ToLower(strings.TrimSpace(keyword))
	for _, item := range items {
		path := resolveItemPath(item)
		if path == "" {
			continue
		}
		if st, err := os.Stat(path); err != nil || st.IsDir() {
			continue
		}
		fn := filepath.Base(path)
		fnl := strings.ToLower(fn)
		stem := strings.TrimSuffix(fnl, ".exe")
		fs := floatVal(item["FinalScore"])
		if fnl == kwLower || fnl == kwLower+".exe" || stem == kwLower {
			fs += 45.0
			item["FinalScore"] = fs
			item["FzyScore"] = fs
		}
	}
}

func finalScoreCompare(a, b map[string]any) bool {
	sa := floatVal(a["FinalScore"])
	sb := floatVal(b["FinalScore"])
	if sa != sb {
		return sa > sb
	}
	ia := int(floatVal(a["_FzyStableIdx"]))
	ib := int(floatVal(b["_FzyStableIdx"]))
	return ia < ib
}

func applyParentDirectoryCollapse(items []map[string]any) {
	if len(items) == 0 {
		return
	}
	parentCount := map[string]int{}
	for _, item := range items {
		path := resolveItemPath(item)
		pk := strings.ToLower(parentFolderName(path))
		if pk == "" {
			continue
		}
		parentCount[pk]++
		if parentCount[pk] <= 5 {
			continue
		}
		item["Category"] = "Hidden"
		item["QuotaCategory"] = "Other"
		pen := floatVal(item["PenaltyTotal"])
		item["PenaltyTotal"] = pen + penaltyParentOverflow
		b := floatVal(item["BonusTotal"])
		item["FzyCategoryBonus"] = b - floatVal(item["PenaltyTotal"])
		item["CategoryColor"] = getCategoryColor("Hidden")
		if meta, ok := item["Metadata"].(map[string]any); ok {
			meta["Category"] = "Hidden"
		}
		fzy := floatVal(item["FzyBase"])
		tr := floatVal(item["PathTrust"])
		if tr == 0 {
			tr = 1.0
		}
		item["FinalScore"] = computeSearchItemFinalScore(path, fzy, tr, floatVal(item["BonusTotal"]), floatVal(item["PenaltyTotal"]))
		item["FzyScore"] = item["FinalScore"]
	}
}

func applyTop9CategoryQuota(items []map[string]any) {
	if len(items) <= 9 {
		return
	}
	out := []map[string]any{}
	nApp, nProj := 0, 0
	for _, item := range items {
		if len(out) >= 9 {
			break
		}
		qc := strVal(item["QuotaCategory"])
		if qc == "App" && nApp >= 4 {
			continue
		}
		if qc == "Project" && nProj >= 2 {
			continue
		}
		out = append(out, item)
		if qc == "App" {
			nApp++
		} else if qc == "Project" {
			nProj++
		}
	}
	if len(out) < 9 {
		for _, item := range items {
			if len(out) >= 9 {
				break
			}
			if containsRef(out, item) {
				continue
			}
			qc := strVal(item["QuotaCategory"])
			if qc != "App" && qc != "Project" {
				out = append(out, item)
			}
		}
	}
	if len(out) < 9 {
		for _, item := range items {
			if len(out) >= 9 {
				break
			}
			if containsRef(out, item) {
				continue
			}
			out = append(out, item)
		}
	}
	rest := []map[string]any{}
	for _, item := range items {
		if !containsRef(out, item) {
			rest = append(rest, item)
		}
	}
	copy(items[:len(out)], out)
	copy(items[len(out):], rest)
}

func containsRef(arr []map[string]any, obj map[string]any) bool {
	id := fmt.Sprint(obj["ID"]) + "|" + strVal(obj["originalDataType"])
	for _, it := range arr {
		if fmt.Sprint(it["ID"])+"|"+strVal(it["originalDataType"]) == id {
			return true
		}
	}
	return false
}

func sortSearchCenterMerged(fileItems, otherItems []map[string]any, keyword string) []map[string]any {
	if len(fileItems) > 0 && strings.TrimSpace(keyword) != "" {
		finalizeFilePathsResults(fileItems, keyword)
		applyExeNameBonus(fileItems, keyword)
		sortFileMaps(fileItems, keyword)
	}
	applyParentDirectoryCollapse(fileItems)
	applyTop9CategoryQuota(fileItems)
	for i, o := range otherItems {
		o["SearchCenterScore"] = SearchCenterOtherRelevance(keyword, o)
		o["_scIdx"] = i
	}
	sortOtherMaps(otherItems)
	out := make([]map[string]any, 0, len(fileItems)+len(otherItems))
	out = append(out, fileItems...)
	out = append(out, otherItems...)
	return out
}

func sortFileMaps(items []map[string]any, keyword string) {
	// slice stable sort by FinalScore
	for i := 0; i < len(items); i++ {
		for j := i + 1; j < len(items); j++ {
			if !finalScoreCompare(items[i], items[j]) {
				items[i], items[j] = items[j], items[i]
			}
		}
	}
}

func sortOtherMaps(items []map[string]any) {
	for i := 0; i < len(items); i++ {
		for j := i + 1; j < len(items); j++ {
			si := floatVal(items[i]["SearchCenterScore"])
			sj := floatVal(items[j]["SearchCenterScore"])
			if sj > si || (sj == si && floatVal(items[i]["_scIdx"]) > floatVal(items[j]["_scIdx"])) {
				items[i], items[j] = items[j], items[i]
			}
		}
	}
}

func finalizeFilePathsResults(items []map[string]any, keyword string) {
	if len(items) == 0 || strings.TrimSpace(keyword) == "" {
		return
	}
	processFileItems(items, keyword)
	sortFilesByFzy(items, keyword)
}

func splitFileAndOther(all []map[string]any) (files, others []map[string]any) {
	for _, it := range all {
		od := strVal(it["originalDataType"])
		dt := strVal(it["DataType"])
		isFile := od == "file" || dt == "file" || dt == "folder" || strVal(it["Source"]) == "文件" || strVal(it["Source"]) == "文件夹" || strVal(it["Source"]) == "文件路径"
		if isFile {
			files = append(files, it)
		} else {
			others = append(others, it)
		}
	}
	return
}
