package main

import (
	"bufio"
	"database/sql"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type templateEntry struct {
	ID, Title, Content, Icon, Category, FunctionCategory, Series string
}

func defaultPromptTemplatesZH() []templateEntry {
	return []templateEntry{
		{ID: "explain_basic", Title: "代码解释", Content: "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点", Category: "基础", FunctionCategory: "Explain", Series: "Basic"},
		{ID: "refactor_basic", Title: "代码重构", Content: "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变", Category: "基础", FunctionCategory: "Refactor", Series: "Basic"},
		{ID: "optimize_basic", Title: "性能优化", Content: "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性", Category: "基础", FunctionCategory: "Optimize", Series: "Basic"},
		{ID: "debug_basic", Title: "调试代码", Content: "请帮我调试这段代码，找出可能的bug和错误，并提供修复建议", Category: "基础"},
		{ID: "test_basic", Title: "编写测试", Content: "为这段代码编写单元测试，覆盖主要功能和边界情况", Category: "基础"},
		{ID: "document_basic", Title: "添加文档", Content: "为这段代码添加详细的文档注释，包括函数说明、参数说明、返回值说明和使用示例", Category: "基础"},
		{ID: "code_review", Title: "代码审查", Content: "请对这段代码进行全面审查，指出潜在问题、bug、安全隐患和改进建议", Category: "专业"},
		{ID: "architecture_analysis", Title: "架构分析", Content: "请从专业的角度分析这段代码，包括架构设计、设计模式、技术选型等方面的考量", Category: "专业"},
		{ID: "security_audit", Title: "安全审计", Content: "请对这段代码进行安全审计，检查是否存在SQL注入、XSS、CSRF等安全漏洞，并提供安全加固建议", Category: "专业"},
		{ID: "bugfix_human", Title: "请说人话", Content: "请提供一份双语对照表。左边是代码行，右边是对应的'人类意图'。通过对比，帮我定位哪一行有错误。请粘贴错误代码或者截图", Category: "改错"},
	}
}

func loadMergedTemplates(baseDir string) []templateEntry {
	out := defaultPromptTemplatesZH()
	iniPath := filepath.Join(baseDir, "PromptTemplates.ini")
	data, err := os.ReadFile(iniPath)
	if err != nil {
		return out
	}
	sections := parseIniSections(string(data))
	byID := map[string]int{}
	for i := range out {
		byID[out[i].ID] = i
	}
	tplCount := 0
	if sec := sections[strings.ToLower("Templates")]; sec != nil {
		if v, ok := sec["count"]; ok {
			tplCount, _ = strconv.Atoi(v)
		}
	}
	re := regexp.MustCompile(`(?i)^template(\d+)$`)
	for name, sec := range sections {
		m := re.FindStringSubmatch(name)
		if len(m) != 2 {
			continue
		}
		idx, _ := strconv.Atoi(m[1])
		if tplCount > 0 && idx > tplCount {
			continue
		}
		id := strings.TrimSpace(lookupKey(sec, "ID", "id"))
		if id == "" {
			continue
		}
		t := templateEntry{
			ID:               id,
			Title:            lookupKey(sec, "Title", "title"),
			Content:          lookupKey(sec, "Content", "content"),
			Icon:             lookupKey(sec, "Icon", "icon"),
			Category:         lookupKey(sec, "Category", "category"),
			FunctionCategory: lookupKey(sec, "FunctionCategory", "functioncategory"),
			Series:           lookupKey(sec, "Series", "series"),
		}
		if i, ok := byID[id]; ok {
			out[i] = t
		} else {
			out = append(out, t)
			byID[id] = len(out) - 1
		}
	}
	_ = tplCount
	return out
}

func lookupKey(sec map[string]string, keys ...string) string {
	for _, k := range keys {
		for kk, v := range sec {
			if strings.EqualFold(kk, k) {
				return v
			}
		}
	}
	return ""
}

func parseIniSections(s string) map[string]map[string]string {
	out := map[string]map[string]string{}
	sec := ""
	sc := bufio.NewScanner(strings.NewReader(s))
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, ";") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			sec = strings.Trim(line, "[]")
			if out[strings.ToLower(sec)] == nil {
				out[strings.ToLower(sec)] = map[string]string{}
			}
			continue
		}
		p := strings.IndexByte(line, '=')
		if p <= 0 || sec == "" {
			continue
		}
		k := strings.TrimSpace(line[:p])
		v := strings.TrimSpace(line[p+1:])
		out[strings.ToLower(sec)][strings.ToLower(k)] = v
	}
	return out
}

func searchTemplates(baseDir, keyword string, maxResults, offset int) []map[string]any {
	kw := strings.ToLower(strings.TrimSpace(keyword))
	if kw == "" {
		return nil
	}
	templates := loadMergedTemplates(baseDir)
	var out []map[string]any
	skipped := 0
	now := time.Now().Format("2006-01-02 15:04:05")
	for _, t := range templates {
		if strings.Contains(strings.ToLower(t.Title), kw) ||
			strings.Contains(strings.ToLower(t.Content), kw) ||
			strings.Contains(strings.ToLower(t.Category), kw) {
			if skipped < offset {
				skipped++
				continue
			}
			if len(out) >= maxResults {
				break
			}
			prev := t.Content
			if len([]rune(prev)) > 80 {
				prev = string([]rune(prev)[:80]) + "..."
			}
			ts := now
			out = append(out, map[string]any{
				"originalDataType": "template",
				"DataType":         "template",
				"DataTypeName":     "提示词模板",
				"ID":               t.ID,
				"Title":            t.Title,
				"SubTitle":         t.Category + " · " + prev,
				"Content":          t.Content,
				"Preview":          prev,
				"Timestamp":        ts,
				"Metadata": map[string]any{
					"Category":         t.Category,
					"Icon":             t.Icon,
					"FunctionCategory": t.FunctionCategory,
					"Series":           t.Series,
				},
				"Action":       "send_to_cursor",
				"ActionParams": map[string]any{"TemplateID": t.ID},
			})
		}
	}
	return out
}

func readCursorShortcutIni(baseDir string) map[string]map[string]string {
	path := filepath.Join(baseDir, "CursorShortcut.ini")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	return parseIniSections(string(data))
}

func searchConfigItems(baseDir, keyword string, maxResults, offset int) []map[string]any {
	kw := strings.ToLower(strings.TrimSpace(keyword))
	if kw == "" {
		return nil
	}
	ini := readCursorShortcutIni(baseDir)
	if ini == nil {
		return nil
	}
	tabNameMap := map[string]string{
		"通用": "general", "General": "general",
		"外观": "appearance", "Appearance": "appearance",
		"提示词": "prompts", "Prompts": "prompts",
		"快捷键": "hotkeys", "Hotkeys": "hotkeys",
		"高级": "advanced", "Advanced": "advanced",
	}
	configSections := map[string]string{
		"General": "general", "Settings": "general", "Prompts": "prompts",
		"Hotkeys": "hotkeys", "Appearance": "appearance", "Advanced": "advanced",
	}
	var out []map[string]any
	skipped := 0
	count := 0
	for tabName, tabKey := range tabNameMap {
		if count >= maxResults {
			break
		}
		if strings.Contains(strings.ToLower(tabName), kw) {
			if skipped < offset {
				skipped++
				continue
			}
			out = append(out, map[string]any{
				"originalDataType": "config",
				"DataType":         "config",
				"DataTypeName":     "配置项",
				"ID":               "config_tab_" + tabKey,
				"Title":            tabName + "标签页",
				"SubTitle":         "标签页 · 配置面板",
				"Content":          "跳转到" + tabName + "标签页",
				"Preview":          "点击跳转到" + tabName + "标签页",
				"Metadata": map[string]any{
					"Section": "", "Key": "", "TabName": tabKey,
				},
				"Action":       "jump_to_config",
				"ActionParams": map[string]any{"TabName": tabKey, "Section": "", "Key": ""},
			})
			count++
		}
	}
	for secName, tabName := range configSections {
		if count >= maxResults {
			break
		}
		section := ini[strings.ToLower(secName)]
		if section == nil {
			continue
		}
		for key, value := range section {
			if count >= maxResults {
				break
			}
			if !strings.Contains(strings.ToLower(key), kw) && !strings.Contains(strings.ToLower(value), kw) {
				continue
			}
			if skipped < offset {
				skipped++
				continue
			}
			vp := value
			if len([]rune(vp)) > 60 {
				vp = string([]rune(vp)[:60]) + "..."
			}
			out = append(out, map[string]any{
				"originalDataType": "config",
				"DataType":         "config",
				"DataTypeName":     "配置项",
				"ID":               secName + "." + key,
				"Title":            key,
				"SubTitle":         secName + " · " + vp,
				"Content":          value,
				"Preview":          vp,
				"Metadata": map[string]any{
					"Section": secName, "Key": key, "TabName": tabName,
				},
				"Action":       "jump_to_config",
				"ActionParams": map[string]any{"TabName": tabName, "Section": secName, "Key": key},
			})
			count++
		}
	}
	return out
}

func hotkeyDefaultsFromIni(baseDir string) map[string]string {
	ini := readCursorShortcutIni(baseDir)
	def := map[string]string{
		"关闭面板": "Esc", "连续复制": "c", "合并粘贴": "v", "剪贴板管理": "x",
		"解释": "e", "重构": "r", "优化": "o", "配置": "q", "语音输入": "z",
		"区域截图": "t", "分割代码": "s", "批量操作": "b",
	}
	if ini == nil {
		return def
	}
	hk := ini["hotkeys"]
	if hk == nil {
		return def
	}
	merge := func(key, friendly string) {
		for kk, v := range hk {
			if strings.EqualFold(kk, key) && v != "" {
				def[friendly] = v
			}
		}
	}
	merge("HotkeyESC", "关闭面板")
	merge("HotkeyC", "连续复制")
	merge("HotkeyV", "合并粘贴")
	merge("HotkeyX", "剪贴板管理")
	merge("HotkeyE", "解释")
	merge("HotkeyR", "重构")
	merge("HotkeyO", "优化")
	merge("HotkeyQ", "配置")
	merge("HotkeyZ", "语音输入")
	merge("HotkeyT", "区域截图")
	merge("SplitHotkey", "分割代码")
	merge("BatchHotkey", "批量操作")
	return def
}

func searchHotkeys(baseDir, keyword string, maxResults, offset int) []map[string]any {
	kw := strings.ToLower(strings.TrimSpace(keyword))
	if kw == "" {
		return nil
	}
	hmap := map[string]map[string]string{
		"关闭面板":   {"Hotkey": "", "Function": "关闭面板", "Description": "关闭快捷操作面板"},
		"连续复制":   {"Hotkey": "", "Function": "连续复制", "Description": "CapsLock+C 连续复制内容"},
		"合并粘贴":   {"Hotkey": "", "Function": "合并粘贴", "Description": "CapsLock+V 合并粘贴所有复制的内容"},
		"剪贴板管理": {"Hotkey": "", "Function": "剪贴板管理", "Description": "CapsLock+X 打开剪贴板管理面板"},
		"解释":     {"Hotkey": "", "Function": "解释", "Description": "CapsLock+E 解释代码"},
		"重构":     {"Hotkey": "", "Function": "重构", "Description": "CapsLock+R 重构代码"},
		"优化":     {"Hotkey": "", "Function": "优化", "Description": "CapsLock+O 优化代码"},
		"配置":     {"Hotkey": "", "Function": "配置", "Description": "CapsLock+Q 打开配置面板"},
		"语音输入":   {"Hotkey": "", "Function": "语音输入", "Description": "CapsLock+Z 语音输入"},
		"区域截图":   {"Hotkey": "", "Function": "区域截图", "Description": "CapsLock+T 区域截图"},
		"分割代码":   {"Hotkey": "", "Function": "分割代码", "Description": "CapsLock+分割键 分割代码"},
		"批量操作":   {"Hotkey": "", "Function": "批量操作", "Description": "CapsLock+批量键 批量操作"},
		"快捷操作":   {"Hotkey": "", "Function": "快捷操作", "Description": "快捷操作按钮面板"},
		"快捷操作按钮": {"Hotkey": "", "Function": "快捷操作按钮", "Description": "快捷操作按钮面板"},
	}
	df := hotkeyDefaultsFromIni(baseDir)
	for k := range hmap {
		if v, ok := df[k]; ok {
			hmap[k]["Hotkey"] = v
		}
	}
	if sp, ok := df["分割代码"]; ok {
		hmap["分割代码"]["Description"] = "CapsLock+" + sp + " 分割代码"
	}
	if bp, ok := df["批量操作"]; ok {
		hmap["批量操作"]["Description"] = "CapsLock+" + bp + " 批量操作"
	}
	var out []map[string]any
	skipped := 0
	count := 0
	if strings.Contains(kw, "快捷") {
		if skipped >= offset {
			out = append(out, map[string]any{
				"originalDataType": "hotkey",
				"DataType":         "hotkey",
				"DataTypeName":     "快捷键",
				"ID":               "hotkeys_tab",
				"Title":            "快捷键标签页",
				"SubTitle":         "标签页 · 配置面板中的快捷键设置",
				"Content":          "跳转到快捷键标签页",
				"Preview":          "点击跳转到快捷键标签页",
				"Metadata":         map[string]any{"TabKey": "hotkeys", "Type": "标签页"},
				"Action":           "jump_to_config",
				"ActionParams":     map[string]any{"TabName": "hotkeys", "Section": "", "Key": ""},
			})
			count++
		} else {
			skipped++
		}
	}
	for fn, info := range hmap {
		if count >= maxResults {
			break
		}
		fnL := strings.ToLower(fn)
		hkL := strings.ToLower(info["Hotkey"])
		descL := strings.ToLower(info["Description"])
		quick := strings.Contains(kw, "快捷") && (strings.Contains(fnL, "快捷") || strings.Contains(descL, "快捷"))
		if strings.Contains(fnL, kw) || strings.Contains(hkL, kw) || strings.Contains(descL, kw) || quick {
			if skipped < offset {
				skipped++
				continue
			}
			out = append(out, map[string]any{
				"originalDataType": "hotkey",
				"DataType":         "hotkey",
				"DataTypeName":     "快捷键",
				"ID":               "hotkey_" + fn,
				"Title":            info["Function"] + " (" + info["Hotkey"] + ")",
				"SubTitle":         info["Description"],
				"Content":          info["Description"],
				"Preview":          info["Description"],
				"Metadata": map[string]any{
					"Hotkey": info["Hotkey"], "Function": info["Function"], "Description": info["Description"],
				},
				"Action":       "jump_to_hotkey",
				"ActionParams": map[string]any{"FunctionName": info["Function"]},
			})
			count++
		}
	}
	return out
}

func searchFunctions(keyword string, maxResults, offset int) []map[string]any {
	kw := strings.ToLower(strings.TrimSpace(keyword))
	if kw == "" {
		return nil
	}
	funList := []map[string]string{
		{"Name": "解释代码", "Description": "使用AI解释代码逻辑", "Category": "AI功能"},
		{"Name": "重构代码", "Description": "使用AI重构代码", "Category": "AI功能"},
		{"Name": "优化代码", "Description": "使用AI优化代码性能", "Category": "AI功能"},
		{"Name": "剪贴板管理", "Description": "管理剪贴板历史记录", "Category": "工具功能"},
		{"Name": "语音输入", "Description": "使用语音输入文本", "Category": "工具功能"},
		{"Name": "语音搜索", "Description": "使用语音搜索", "Category": "工具功能"},
		{"Name": "区域截图", "Description": "截取屏幕区域", "Category": "工具功能"},
		{"Name": "模板管理", "Description": "管理提示词模板", "Category": "配置功能"},
	}
	var out []map[string]any
	skipped := 0
	for _, fn := range funList {
		if len(out) >= maxResults {
			break
		}
		nm := strings.ToLower(fn["Name"])
		ds := strings.ToLower(fn["Description"])
		cat := strings.ToLower(fn["Category"])
		if strings.Contains(nm, kw) || strings.Contains(ds, kw) || strings.Contains(cat, kw) {
			if skipped < offset {
				skipped++
				continue
			}
			out = append(out, map[string]any{
				"originalDataType": "function",
				"DataType":         "function",
				"DataTypeName":     "功能",
				"ID":               fn["Name"],
				"Title":            fn["Name"],
				"SubTitle":         fn["Category"] + " · " + fn["Description"],
				"Content":          fn["Description"],
				"Preview":          fn["Description"],
				"Metadata": map[string]any{
					"Category": fn["Category"], "Description": fn["Description"],
				},
				"Action":       "execute_function",
				"ActionParams": map[string]any{"FunctionName": fn["Name"]},
			})
		}
	}
	return out
}

func searchUI(keyword string, maxResults, offset int) []map[string]any {
	kw := strings.ToLower(strings.TrimSpace(keyword))
	if kw == "" {
		return nil
	}
	tabMap := map[string]string{
		"通用": "general", "General": "general",
		"外观": "appearance", "Appearance": "appearance",
		"提示词": "prompts", "Prompts": "prompts",
		"快捷键": "hotkeys", "Hotkeys": "hotkeys",
		"高级": "advanced", "Advanced": "advanced",
		"搜索": "search",
	}
	uiElements := []map[string]string{
		{"Name": "快捷操作", "Tab": "hotkeys", "Description": "快捷操作按钮面板", "Type": "按钮"},
		{"Name": "快捷操作按钮", "Tab": "hotkeys", "Description": "快捷操作按钮面板", "Type": "按钮"},
		{"Name": "快捷键设置", "Tab": "hotkeys", "Description": "快捷键配置页面", "Type": "标签页"},
		{"Name": "快捷键配置", "Tab": "hotkeys", "Description": "快捷键配置页面", "Type": "标签页"},
		{"Name": "模板管理", "Tab": "prompts", "Description": "提示词模板管理", "Type": "标签页"},
		{"Name": "剪贴板管理", "Tab": "general", "Description": "剪贴板历史管理", "Type": "功能"},
		{"Name": "配置面板", "Tab": "general", "Description": "打开配置面板", "Type": "功能"},
	}
	var out []map[string]any
	skipped := 0
	for tabName, tabKey := range tabMap {
		if len(out) >= maxResults {
			break
		}
		if strings.Contains(strings.ToLower(tabName), kw) {
			if skipped < offset {
				skipped++
				continue
			}
			out = append(out, map[string]any{
				"originalDataType": "ui",
				"DataType":         "ui",
				"DataTypeName":     "界面",
				"ID":               "ui_tab_" + tabKey,
				"Title":            tabName + "标签页",
				"SubTitle":         "配置面板 · " + tabName,
				"Content":          "跳转到" + tabName + "标签页",
				"Preview":          "点击跳转到" + tabName + "标签页",
				"Metadata":         map[string]any{"TabKey": tabKey, "Type": "标签页"},
				"Action":           "jump_to_config",
				"ActionParams":     map[string]any{"TabName": tabKey},
			})
		}
	}
	for _, el := range uiElements {
		if len(out) >= maxResults {
			break
		}
		nm := strings.ToLower(el["Name"])
		ds := strings.ToLower(el["Description"])
		if strings.Contains(nm, kw) || strings.Contains(ds, kw) {
			if skipped < offset {
				skipped++
				continue
			}
			out = append(out, map[string]any{
				"originalDataType": "ui",
				"DataType":         "ui",
				"DataTypeName":     "界面",
				"ID":               "ui_el_" + el["Name"],
				"Title":            el["Name"],
				"SubTitle":         el["Type"] + " · " + el["Description"],
				"Content":          el["Description"],
				"Preview":          el["Description"],
				"Metadata": map[string]any{
					"TabKey": el["Tab"], "ElementType": el["Type"], "Description": el["Description"],
				},
				"Action":       "jump_to_config",
				"ActionParams": map[string]any{"TabName": el["Tab"]},
			})
		}
	}
	return out
}

func searchFilePathsSupplementDB(db *sql.DB, keyword string, maxResults int) []map[string]any {
	kw := strings.ToLower(strings.TrimSpace(keyword))
	if kw == "" || db == nil {
		return nil
	}
	q := `SELECT DISTINCT Content, Timestamp FROM ClipboardHistory WHERE (LOWER(Content) LIKE ? OR LOWER(Content) LIKE ?) ORDER BY Timestamp DESC LIMIT ?`
	pat := "%" + kw + "%"
	rows, err := db.Query(q, pat, "file://%"+kw+"%", maxResults*2)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []map[string]any
	for rows.Next() {
		var content, ts sql.NullString
		if err := rows.Scan(&content, &ts); err != nil {
			continue
		}
		c := nv(content)
		if !isFilePathLike(c) {
			continue
		}
		if !strings.Contains(strings.ToLower(filepath.Base(c)), kw) && !strings.Contains(strings.ToLower(c), kw) {
			continue
		}
		fn := filepath.Base(c)
		dir := filepath.Dir(c)
		ext := filepath.Ext(fn)
		out = append(out, map[string]any{
			"originalDataType": "file",
			"DataType":         "file",
			"DataTypeName":     "文件路径",
			"ID":               c,
			"Title":            fn,
			"SubTitle":         dir + " · " + ext,
			"Content":          c,
			"Preview":          c,
			"Source":           "文件路径",
			"Metadata": map[string]any{
				"FilePath": c, "FileName": fn, "DirPath": dir, "Ext": ext,
				"Timestamp": nv(ts),
			},
			"Action":       "open_file",
			"ActionParams": map[string]any{"FilePath": c},
		})
		if len(out) >= maxResults {
			break
		}
	}
	return out
}

func isFilePathLike(s string) bool {
	if len(s) < 3 {
		return false
	}
	return strings.Contains(s, ":\\") || strings.HasPrefix(s, `\\`)
}
