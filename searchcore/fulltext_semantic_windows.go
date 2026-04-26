//go:build windows

package main

import (
	"regexp"
	"sort"
	"strings"
	"unicode/utf8"
)

const (
	privacyModeStrict   = "strict"
	privacyModeBalanced = "balanced"
	privacyModeOff      = "off"
)

var (
	semIPRe     = regexp.MustCompile(`\b(?:(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\b`)
	semCIDRRe   = regexp.MustCompile(`\b(?:(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)/(?:[0-9]|[12]\d|3[0-2])\b`)
	semDomainRe = regexp.MustCompile(`\b(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\b`)
	semAmountRe = regexp.MustCompile(`(?i)(?:¥|\$|usd|cny|rmb)\s?\d[\d,]*(?:\.\d{1,2})?`)
	semJWTRe    = regexp.MustCompile(`\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b`)
	semTokenRe  = regexp.MustCompile(`(?i)\b(?:api[_-]?key|access[_-]?token|refresh[_-]?token|secret|private[_-]?key|bearer)\b`)
	semEmailRe  = regexp.MustCompile(`\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b`)
	semPhoneRe  = regexp.MustCompile(`(?:\+?86[-\s]?)?(?:1[3-9]\d{9}|0\d{2,3}[-\s]?\d{7,8})`)
	semKeyValRe = regexp.MustCompile(`(?i)\b(?:token|secret|apikey|api_key|password|passwd|pwd)\s*[:=]\s*\S+`)
)

func normalizePrivacyMode(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case privacyModeOff:
		return privacyModeOff
	case privacyModeBalanced:
		return privacyModeBalanced
	default:
		return privacyModeStrict
	}
}

func semanticTagsForAlias(token string) ([]string, bool) {
	switch strings.ToLower(strings.TrimSpace(token)) {
	case "@net":
		return []string{"net_ip", "net_cidr", "net_domain"}, true
	case "@fin":
		return []string{"fin_amount"}, true
	case "@auth":
		return []string{"auth_token", "auth_jwt", "auth_keyvalue"}, true
	case "@logic":
		return []string{"logic_func", "logic_type"}, true
	default:
		return nil, false
	}
}

func semanticExtractTags(path, content, summary string, maxScanBytes int) []string {
	tags := map[string]struct{}{}
	add := func(tag string) {
		tag = strings.TrimSpace(tag)
		if tag == "" {
			return
		}
		tags[tag] = struct{}{}
	}

	ext := pathExtLower(path)
	switch ext {
	case "go", "py", "ahk", "js", "ts", "tsx", "jsx", "java", "c", "cpp", "h", "hpp", "cs", "rs":
		add("logic_code")
	case "yaml", "yml", "json", "toml", "ini", "xml", "conf", "cfg":
		add("logic_config")
	}

	blob := semanticSampleText(content, summary, maxScanBytes)
	if blob == "" {
		return sortedSemanticTags(tags)
	}
	low := strings.ToLower(blob)

	// L1 cheap checks first.
	if strings.Contains(low, "func ") || strings.Contains(low, "def ") || strings.Contains(low, "class ") || strings.Contains(low, "interface ") {
		add("logic_func")
		add("logic_type")
	}
	if strings.Contains(low, "http://") || strings.Contains(low, "https://") {
		add("net_url")
	}

	// L2/L3 regex checks (precompiled).
	if semIPRe.MatchString(blob) {
		add("net_ip")
	}
	if semCIDRRe.MatchString(blob) {
		add("net_cidr")
	}
	if semDomainRe.MatchString(blob) {
		add("net_domain")
	}
	if semAmountRe.MatchString(blob) {
		add("fin_amount")
	}
	if semJWTRe.MatchString(blob) {
		add("auth_jwt")
		add("auth_token")
	}
	if semTokenRe.MatchString(blob) {
		add("auth_token")
	}
	if semKeyValRe.MatchString(blob) {
		add("auth_keyvalue")
		add("auth_token")
	}
	if semEmailRe.MatchString(blob) {
		add("contact_email")
	}
	if semPhoneRe.MatchString(blob) {
		add("contact_phone")
	}

	return sortedSemanticTags(tags)
}

func semanticSampleText(content, summary string, maxBytes int) string {
	if maxBytes <= 0 {
		maxBytes = 128 * 1024
	}
	text := strings.TrimSpace(content)
	if text == "" {
		text = strings.TrimSpace(summary)
	}
	if text == "" {
		return ""
	}
	if len(text) <= maxBytes {
		return text
	}
	runes := []rune(text)
	if len(runes) == 0 {
		return ""
	}
	maxRunes := maxBytes / 2
	if maxRunes < 1 {
		maxRunes = 1
	}
	if len(runes) <= maxRunes {
		return text
	}
	return string(runes[:maxRunes])
}

func semanticHasSensitiveTags(tags []string) bool {
	for _, t := range tags {
		switch t {
		case "auth_token", "auth_jwt", "auth_keyvalue", "contact_email", "contact_phone", "fin_amount":
			return true
		}
	}
	return false
}

func semanticRedactPreview(text string, privacyMode string, tags []string) string {
	mode := normalizePrivacyMode(privacyMode)
	if mode == privacyModeOff {
		return text
	}
	if !semanticHasSensitiveTags(tags) {
		return text
	}
	out := text
	out = semJWTRe.ReplaceAllString(out, "[redacted-jwt]")
	out = semEmailRe.ReplaceAllString(out, "[redacted-email]")
	out = semPhoneRe.ReplaceAllString(out, "[redacted-phone]")
	out = semAmountRe.ReplaceAllString(out, "[redacted-amount]")
	if mode == privacyModeStrict {
		out = semKeyValRe.ReplaceAllString(out, "[redacted-keyvalue]")
	}
	if utf8.RuneCountInString(strings.TrimSpace(out)) == 0 {
		return "[redacted-sensitive]"
	}
	return out
}

func sortedSemanticTags(src map[string]struct{}) []string {
	if len(src) == 0 {
		return nil
	}
	out := make([]string, 0, len(src))
	for k := range src {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
