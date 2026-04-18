package main

import (
	"fmt"
	"strings"
	"unicode/utf8"
)

// FzyScore 与 CursorHelper.ahk 中 FzyScore 对齐（子序列匹配 + 加权）
func FzyScore(query, target string) float64 {
	if query == "" || target == "" {
		return 0
	}
	qL := strings.ToLower(query)
	tL := strings.ToLower(target)
	lenQ := len(qL)
	lenT := len(tL)
	if lenQ == 0 || lenT == 0 {
		return 0
	}
	pos := make([]int, 0, lenQ)
	start := 0
	for i := 0; i < lenQ; {
		r, w := utf8.DecodeRuneInString(qL[i:])
		if r == utf8.RuneError {
			break
		}
		idx := strings.IndexRune(tL[start:], r)
		if idx < 0 {
			return -100
		}
		found := start + idx
		pos = append(pos, found+1) // 1-based like AHK
		start = found + 1
		i += w
	}
	slashCount := strings.Count(target, "\\")
	score := 0.0
	if strings.Contains(tL, qL) {
		score += 480.0
	}
	if len(qL) <= lenT && strings.HasPrefix(tL, qL) {
		score += 220.0
	}
	fnSeg := target
	for {
		p := strings.LastIndex(fnSeg, "\\")
		if p < 0 {
			break
		}
		fnSeg = fnSeg[p+1:]
	}
	fnL := strings.ToLower(fnSeg)
	if fnL == qL {
		score += 420.0
	} else if len(qL) <= len(fnL) && strings.HasPrefix(fnL, qL) {
		score += 260.0
	} else if strings.Contains(fnL, qL) {
		score += 140.0
	}
	if len(pos) > 0 && pos[0] == 1 {
		score += 100
	}
	for k, p := range pos {
		if p > 1 {
			prevCh, _ := utf8.DecodeLastRuneInString(tL[:p-1])
			curCh, _ := utf8.DecodeRuneInString(tL[p-1:])
			oPrev := uint32(prevCh)
			oCur := uint32(curCh)
			if prevCh == '\\' || prevCh == '/' || prevCh == '_' || prevCh == '-' || prevCh == '.' || prevCh == ' ' {
				score += 80
			}
			if oCur >= 65 && oCur <= 90 && oPrev >= 97 && oPrev <= 122 {
				score += 60
			}
		}
		if k > 0 {
			prevP := pos[k-1]
			gap := p - prevP - 1
			score -= 2 * float64(gap)
			if p == prevP+1 {
				score += 50
			}
		}
	}
	score -= float64(lenT) * 0.02
	score -= float64(slashCount) * 1.0
	return score
}

func computeSearchItemFinalScore(path string, fzyBase float64, pathTrust, bonus, penalty float64) float64 {
	return fzyBase*pathTrust + bonus - penalty
}

// SearchCenterOtherRelevance 非文件条目相关度（简化：无 ShellIcon 友好名）
func SearchCenterOtherRelevance(keyword string, item map[string]any) float64 {
	kw := strings.TrimSpace(keyword)
	if kw == "" {
		return 0
	}
	kwLower := strings.ToLower(kw)
	title := strings.ToLower(strVal(item["Title"]))
	content := strings.ToLower(strVal(item["Content"]))
	sc := 0.0
	if title == kwLower {
		sc += 300.0
	} else if len(kwLower) <= len(title) && strings.HasPrefix(title, kwLower) {
		sc += 180.0
	} else if strings.Contains(title, kwLower) {
		sc += 90.0
	}
	if strings.Contains(content, kwLower) {
		sc += 40.0
	}
	if strVal(item["originalDataType"]) == "clipboard" {
		meta, _ := item["Metadata"].(map[string]any)
		if meta != nil {
			sa := strings.ToLower(strVal(meta["SourceApp"]))
			if sa != "" && (strings.Contains(sa, kwLower)) {
				sc += 95.0
			}
		}
	}
	return sc
}

func strVal(v any) string {
	if v == nil {
		return ""
	}
	switch t := v.(type) {
	case string:
		return t
	default:
		return fmt.Sprint(t)
	}
}

func floatVal(v any) float64 {
	switch t := v.(type) {
	case float64:
		return t
	case float32:
		return float64(t)
	case int:
		return float64(t)
	case int64:
		return float64(t)
	default:
		return 0
	}
}
