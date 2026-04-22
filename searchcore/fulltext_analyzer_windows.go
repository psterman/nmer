//go:build windows && cgo

package main

import (
	"regexp"
	"strings"
	"sync"
	"unicode"

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
		*dst = append(*dst, &analysis.Token{
			Start:        start,
			End:          end,
			Term:         []byte(word),
			PositionIncr: 1,
			Type:         analysis.Ideographic,
		})
		position++
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
	for _, it := range strings.Split(s, "_") {
		add(it)
	}

	var b strings.Builder
	prevLower := false
	for _, r := range s {
		if r == '_' {
			add(b.String())
			b.Reset()
			prevLower = false
			continue
		}
		if b.Len() > 0 && unicode.IsUpper(r) && prevLower {
			add(b.String())
			b.Reset()
		}
		b.WriteRune(r)
		prevLower = unicode.IsLower(r)
	}
	add(b.String())
	return out
}

func appendToken(dst *analysis.TokenStream, term string, start, end int, position int, tokenType analysis.TokenType) int {
	term = strings.TrimSpace(term)
	if term == "" {
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

func isHanRune(r rune) bool {
	return unicode.Is(unicode.Han, r)
}

func isCodeRune(r rune) bool {
	return r == '_' || unicode.IsLetter(r) || unicode.IsDigit(r)
}
