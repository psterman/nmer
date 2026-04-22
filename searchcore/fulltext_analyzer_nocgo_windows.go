//go:build windows && !cgo

package main

import (
	"github.com/blugelabs/bluge/analysis"
	"github.com/blugelabs/bluge/analysis/lang/cjk"
)

func fullTextAnalyzer() *analysis.Analyzer {
	// non-cgo fallback; keeps build green when gojieba is unavailable
	return cjk.Analyzer()
}
