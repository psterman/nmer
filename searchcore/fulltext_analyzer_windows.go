//go:build windows && cgo

package main

import (
	"regexp"
	"sort"
	"strings"
	"sync"
	"unicode"
	"unicode/utf8"

	"github.com/blugelabs/bluge/analysis"
	bltoken "github.com/blugelabs/bluge/analysis/token"
	"github.com/yanyiwu/gojieba"
)

var (
	fullTextAnalyzerOnce sync.Once
	fullTextAnalyzerInst *analysis.Analyzer
)

func fullTextAnalyzer() *analysis.Analyzer {
	fullTextAnalyzerOnce.Do(func() {
		fullTextAnalyzerInst = &analysis.Analyzer{
			Tokenizer: &jiebaCodeTokenizer{
				jieba: getJiebaTokenizer(),
			},
			TokenFilters: []analysis.TokenFilter{
				bltoken.NewLowerCaseFilter(),
			},
		}
	})
	return fullTextAnalyzerInst
}

var (
	jiebaInit sync.Once
	jiebaInst *gojieba.Jieba
)

func getJiebaTokenizer() *gojieba.Jieba {
	jiebaInit.Do(func() {
		jiebaInst = gojieba.NewJieba()
	})
	return jiebaInst
}

type jiebaCodeTokenizer struct {
	jieba *gojieba.Jieba
}

type singleRuneStopwordManager struct {
	mu        sync.RWMutex
	stopwords map[rune]struct{}
}

type textSpan struct {
	text  string
	start int
	end   int
	kind  spanKind
}

type spanKind int

const (
	spanCode spanKind = iota
	spanHan
)

var codePartRegexp = regexp.MustCompile(`[A-Za-z0-9_]+`)

var defaultSingleRuneStopwords = []rune{
	'的', '了', '在', '是', '和', '与', '及', '并', '且', '或', '而', '就', '都', '也', '很',
	'把', '被', '将', '于', '之', '其', '这', '那', '你', '我', '他', '她', '它', '们',
	'啊', '呀', '吗', '吧', '呢', '么', '着', '过', '到', '去', '来', '上', '下', '里',
	'中', '可', '并', '还', '又', '已', '让', '给', '对', '从', '向',
	'a', 'b', 'c', 'd', 'e', 'f', 'g',
	'h', 'i', 'j', 'k', 'l', 'm', 'n',
	'o', 'p', 'q', 'r', 's', 't', 'u',
	'v', 'w', 'x', 'y', 'z',
}

var singleRuneStopwords = newSingleRuneStopwordManager(defaultSingleRuneStopwords)

func newSingleRuneStopwordManager(defaults []rune) *singleRuneStopwordManager {
	m := &singleRuneStopwordManager{
		stopwords: map[rune]struct{}{},
	}
	m.reset(defaults)
	return m
}

func (m *singleRuneStopwordManager) reset(words []rune) {
	m.mu.Lock()
	defer m.mu.Unlock()
	next := make(map[rune]struct{}, len(words))
	for _, r := range words {
		if r == utf8.RuneError {
			continue
		}
		next[unicode.ToLower(r)] = struct{}{}
	}
	m.stopwords = next
}

func (m *singleRuneStopwordManager) isStopword(r rune) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	_, ok := m.stopwords[unicode.ToLower(r)]
	return ok
}

func (m *singleRuneStopwordManager) list() []string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]string, 0, len(m.stopwords))
	for r := range m.stopwords {
		out = append(out, string(r))
	}
	sort.Strings(out)
	return out
}

// UpdateUserStopwords accepts a comma/space/newline separated list and replaces
// the single-rune stopword blacklist used by N-Gram single-rune emission.
func UpdateUserStopwords(raw string) {
	parsed := parseSingleRuneStopwords(raw)
	if len(parsed) == 0 {
		singleRuneStopwords.reset(defaultSingleRuneStopwords)
		return
	}
	singleRuneStopwords.reset(parsed)
}

func parseSingleRuneStopwords(raw string) []rune {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	parts := strings.FieldsFunc(raw, func(r rune) bool {
		return r == ',' || r == '，' || r == ';' || r == '；' || unicode.IsSpace(r)
	})
	if len(parts) == 0 {
		return nil
	}
	out := make([]rune, 0, len(parts))
	seen := make(map[rune]struct{}, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		for _, r := range p {
			r = unicode.ToLower(r)
			if _, ok := seen[r]; ok {
				continue
			}
			seen[r] = struct{}{}
			out = append(out, r)
		}
	}
	return out
}

var codeKeywordTokens = map[string]struct{}{
	"api": {}, "argv": {}, "auth": {}, "await": {}, "bool": {}, "class": {}, "const": {}, "ctx": {}, "db": {}, "enum": {}, "err": {}, "func": {}, "http": {}, "https": {}, "id": {}, "if": {}, "impl": {}, "int": {}, "io": {}, "ip": {}, "json": {}, "jwt": {}, "lang": {}, "map": {}, "nil": {}, "null": {}, "oauth": {}, "orm": {}, "proto": {}, "ptr": {}, "repo": {}, "req": {}, "resp": {}, "rpc": {}, "sdk": {}, "sha1": {}, "sha256": {}, "sql": {}, "ssh": {}, "ssl": {}, "str": {}, "svc": {}, "tcp": {}, "tls": {}, "token": {}, "ts": {}, "type": {}, "udp": {}, "uid": {}, "uri": {}, "url": {}, "user": {}, "utf8": {}, "uuid": {}, "var": {}, "xml": {}, "yaml": {},
}

func (t *jiebaCodeTokenizer) Tokenize(input []byte) analysis.TokenStream {
	text := string(input)
	spans := splitTokenizerSpans(text)
	if len(spans) == 0 {
		return nil
	}

	tokens := make(analysis.TokenStream, 0, len(spans)*3)
	position := 0
	for _, sp := range spans {
		switch sp.kind {
		case spanHan:
			position = t.emitHanTokens(&tokens, sp, position)
		case spanCode:
			position = emitCodeTokens(&tokens, sp, position)
		}
	}
	return tokens
}

func splitTokenizerSpans(s string) []textSpan {
	var spans []textSpan
	if s == "" {
		return spans
	}
	inSpan := false
	start := 0
	currentKind := spanCode
	for i, r := range s {
		var kind spanKind
		switch {
		case isHanRune(r):
			kind = spanHan
		case isCodeRune(r):
			kind = spanCode
		default:
			if inSpan {
				spans = append(spans, textSpan{text: s[start:i], start: start, end: i, kind: currentKind})
				inSpan = false
			}
			continue
		}
		if !inSpan {
			inSpan = true
			start = i
			currentKind = kind
			continue
		}
		if currentKind != kind {
			spans = append(spans, textSpan{text: s[start:i], start: start, end: i, kind: currentKind})
			start = i
			currentKind = kind
		}
	}
	if inSpan {
		spans = append(spans, textSpan{text: s[start:], start: start, end: len(s), kind: currentKind})
	}
	return spans
}

func (t *jiebaCodeTokenizer) emitHanTokens(dst *analysis.TokenStream, sp textSpan, position int) int {
	if t.jieba == nil || strings.TrimSpace(sp.text) == "" {
		return position
	}
	terms := t.jieba.CutForSearch(sp.text, true)
	cursor := 0
	for _, term := range terms {
		word := strings.TrimSpace(term)
		if word == "" {
			continue
		}
		rel := strings.Index(sp.text[cursor:], word)
		if rel < 0 {
			rel = strings.Index(sp.text, word)
			if rel < 0 {
				continue
			}
		} else {
			rel += cursor
		}
		start := sp.start + rel
		end := start + len(word)
		cursor = rel + len(word)
		position = appendToken(dst, word, start, end, position, 1, analysis.Ideographic, false)

		// N-Gram hybrid: emit one-rune overlap tokens with PositionIncr=0
		if utf8.RuneCountInString(word) <= 1 {
			continue
		}
		wordOffset := start
		for _, rr := range word {
			rLen := utf8.RuneLen(rr)
			if rLen <= 0 {
				continue
			}
			if shouldKeepSingleRuneToken(rr) {
				_ = appendToken(dst, string(rr), wordOffset, wordOffset+rLen, position, 0, analysis.Ideographic, true)
			}
			wordOffset += rLen
		}
	}
	return position
}

func emitCodeTokens(dst *analysis.TokenStream, sp textSpan, position int) int {
	if sp.text == "" {
		return position
	}
	matches := codePartRegexp.FindAllStringIndex(sp.text, -1)
	for _, m := range matches {
		part := sp.text[m[0]:m[1]]
		if part == "" {
			continue
		}
		start := sp.start + m[0]
		end := sp.start + m[1]
		position = appendToken(dst, part, start, end, position, 1, analysis.AlphaNumeric, false)
		subParts := splitCodeIdentifier(part)
		for _, sub := range subParts {
			if sub == part {
				continue
			}
			position = appendToken(dst, sub, start, end, position, 1, analysis.AlphaNumeric, false)
		}
	}
	return position
}

func splitCodeIdentifier(s string) []string {
	if s == "" {
		return nil
	}
	var out []string
	seen := map[string]struct{}{}
	add := func(v string) {
		v = strings.TrimSpace(v)
		if v == "" {
			return
		}
		if _, ok := seen[v]; ok {
			return
		}
		seen[v] = struct{}{}
		out = append(out, v)
	}

	add(s)
	for _, part := range splitIdentifierCore(s) {
		add(part)
	}
	lower := strings.ToLower(s)
	for kw := range codeKeywordTokens {
		if strings.Contains(lower, kw) {
			add(kw)
		}
	}
	return out
}

func appendToken(dst *analysis.TokenStream, term string, start, end int, position int, positionIncr int, tokenType analysis.TokenType, forceKeep bool) int {
	term = strings.TrimSpace(term)
	if !forceKeep && !shouldKeepToken(term) {
		return position
	}
	*dst = append(*dst, &analysis.Token{
		Start:        start,
		End:          end,
		Term:         []byte(term),
		PositionIncr: positionIncr,
		Type:         tokenType,
	})
	if positionIncr > 0 {
		return position + positionIncr
	}
	return position
}

func splitIdentifierCore(s string) []string {
	if s == "" {
		return nil
	}
	var out []string
	for _, chunk := range strings.Split(s, "_") {
		chunk = strings.TrimSpace(chunk)
		if chunk == "" {
			continue
		}
		out = append(out, splitCamelAndDigit(chunk)...)
	}
	return out
}

func splitCamelAndDigit(s string) []string {
	if s == "" {
		return nil
	}
	runes := []rune(s)
	if len(runes) <= 1 {
		return []string{s}
	}
	parts := make([]string, 0, 4)
	start := 0
	for i := 1; i < len(runes); i++ {
		prev := runes[i-1]
		cur := runes[i]
		next := rune(0)
		if i+1 < len(runes) {
			next = runes[i+1]
		}

		boundary := false
		switch {
		case unicode.IsDigit(prev) != unicode.IsDigit(cur):
			boundary = true
		case unicode.IsLower(prev) && unicode.IsUpper(cur):
			boundary = true
		case unicode.IsUpper(prev) && unicode.IsUpper(cur) && next != 0 && unicode.IsLower(next):
			boundary = true
		}
		if boundary {
			parts = append(parts, string(runes[start:i]))
			start = i
		}
	}
	parts = append(parts, string(runes[start:]))
	return parts
}

func shouldKeepToken(term string) bool {
	term = strings.TrimSpace(term)
	if term == "" {
		return false
	}
	if isNumericToken(term) {
		return true
	}
	if utf8.RuneCountInString(term) >= 2 {
		return true
	}
	// Keep legal non-stopword single rune tokens so one-char queries like "勇"
	// can hit semantic tokens emitted by jieba.
	r, _ := utf8.DecodeRuneInString(term)
	return shouldKeepSingleRuneToken(r)
}

func isNumericToken(term string) bool {
	if term == "" {
		return false
	}
	for _, r := range term {
		if !unicode.IsDigit(r) {
			return false
		}
	}
	return true
}

func shouldKeepSingleRuneToken(r rune) bool {
	switch {
	case unicode.Is(unicode.Han, r):
		// keep
	case unicode.IsLetter(r), unicode.IsDigit(r):
		// keep alphanumeric rune
	default:
		return false
	}
	if singleRuneStopwords.isStopword(r) {
		return false
	}
	return true
}

func isHanRune(r rune) bool {
	return unicode.Is(unicode.Han, r)
}

func isCodeRune(r rune) bool {
	return r == '_' || unicode.IsLetter(r) || unicode.IsDigit(r)
}
