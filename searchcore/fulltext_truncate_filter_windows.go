//go:build windows

package main

import (
	"strings"
	"sync"

	"github.com/blugelabs/bluge/analysis"
)

const defaultContentTermVectorLimit = 10

var (
	fullTextContentAnalyzerOnce sync.Once
	fullTextContentAnalyzerInst *analysis.Analyzer
)

// TruncateFilter limits term-vector bearing token occurrences per document.
// NOTE: Bluge applies location flags at field-level, so true "emit term but
// drop location for overflow token" is emulated by:
// 1) this filter on position-enabled field (drops overflow tokens)
// 2) companion no-position field keeps full token stream for recall.
type TruncateFilter struct {
	maxPositions int
}

func NewTruncateFilter(maxPositions int) *TruncateFilter {
	if maxPositions <= 0 {
		maxPositions = defaultContentTermVectorLimit
	}
	return &TruncateFilter{maxPositions: maxPositions}
}

func (f *TruncateFilter) Filter(input analysis.TokenStream) analysis.TokenStream {
	if len(input) == 0 || f.maxPositions <= 0 {
		return input
	}
	seen := make(map[string]int, len(input))
	out := make(analysis.TokenStream, 0, len(input))
	for _, tk := range input {
		if tk == nil || len(tk.Term) == 0 {
			continue
		}
		term := strings.ToLower(string(tk.Term))
		seen[term]++
		if seen[term] > f.maxPositions {
			continue
		}
		out = append(out, tk)
	}
	return out
}

func fullTextContentAnalyzer() *analysis.Analyzer {
	fullTextContentAnalyzerOnce.Do(func() {
		base := fullTextAnalyzer()
		filters := make([]analysis.TokenFilter, 0, len(base.TokenFilters)+1)
		filters = append(filters, base.TokenFilters...)
		filters = append(filters, NewTruncateFilter(defaultContentTermVectorLimit))
		fullTextContentAnalyzerInst = &analysis.Analyzer{
			CharFilters:  append([]analysis.CharFilter{}, base.CharFilters...),
			Tokenizer:    base.Tokenizer,
			TokenFilters: filters,
		}
	})
	return fullTextContentAnalyzerInst
}

