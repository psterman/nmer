//go:build windows && cgo

package main

import (
	"regexp"
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
		position = appendToken(dst, word, start, end, position, analysis.Ideographic)
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
		position = appendToken(dst, part, start, end, position, analysis.AlphaNumeric)
		subParts := splitCodeIdentifier(part)
		for _, sub := range subParts {
			if sub == part {
				continue
			}
			position = appendToken(dst, sub, start, end, position, analysis.AlphaNumeric)
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

func appendToken(dst *analysis.TokenStream, term string, start, end int, position int, tokenType analysis.TokenType) int {
	term = strings.TrimSpace(term)
	if !shouldKeepToken(term) {
		return position
	}
	*dst = append(*dst, &analysis.Token{
		Start:        start,
		End:          end,
		Term:         []byte(term),
		PositionIncr: 1,
		Type:         tokenType,
	})
	return position + 1
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
	return utf8.RuneCountInString(term) >= 2
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

func isHanRune(r rune) bool {
	return unicode.Is(unicode.Han, r)
}

func isCodeRune(r rune) bool {
	return r == '_' || unicode.IsLetter(r) || unicode.IsDigit(r)
}
