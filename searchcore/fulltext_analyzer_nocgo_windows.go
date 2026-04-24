//go:build windows && !cgo

package main

import (
	"github.com/blugelabs/bluge/analysis"
	"github.com/blugelabs/bluge/analysis/lang/cjk"
)

// UpdateUserStopwords is a no-op in non-cgo mode.
func UpdateUserStopwords(_ string) {}

func fullTextAnalyzer() *analysis.Analyzer {
	// non-cgo fallback; keeps build green when gojieba is unavailable
	return cjk.Analyzer()
}
