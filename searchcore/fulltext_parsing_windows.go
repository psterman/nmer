//go:build windows

package main

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"fmt"
	"html"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"unicode"
	"unicode/utf16"
	"unicode/utf8"

	"github.com/saintfish/chardet"
	"golang.org/x/text/encoding/htmlindex"
	"golang.org/x/text/encoding/simplifiedchinese"
	"golang.org/x/text/transform"
)

func (b *blugeIndexer) readFileForIndex(path string, fileSize int64) (string, string, error) {
	ext := pathExtLower(path)
	switch ext {
	case "pdf":
		text, err := b.extractPDFText(path)
		if err != nil {
			return "", "", err
		}
		return text, extractSummaryFromText(text, 512), nil
	case "docx":
		text, err := extractDOCXText(path)
		if err != nil {
			return "", "", err
		}
		return text, extractSummaryFromText(text, 512), nil
	case "xlsx":
		text, err := extractXLSXText(path)
		if err != nil {
			return "", "", err
		}
		return text, extractSummaryFromText(text, 512), nil
	default:
		return b.readPlainTextFileForIndex(path, fileSize)
	}
}

func (b *blugeIndexer) readPlainTextFileForIndex(path string, fileSize int64) (string, string, error) {
	maxRead := b.cfg.HardReadLimit
	if maxRead <= 0 {
		maxRead = defaultHardReadLimit
	}
	if fileSize > maxRead {
		return "", "", errSkipTooLarge
	}

	prefix, err := readFilePrefix(path, 512)
	if err != nil {
		return "", "", err
	}
	if sniffBinaryOrNonText(prefix) {
		return "", "", errSkipNonText
	}

	const mmapThreshold int64 = 256 * 1024
	if fileSize > mmapThreshold {
		raw, merr := mmapReadFileUpTo(path, min64(maxRead, fileSize))
		if merr == nil && len(raw) > 0 {
			if int64(len(raw)) > maxRead {
				return "", "", errSkipTooLarge
			}
			text, derr := decodeBestEffortText(raw)
			if derr == nil && strings.TrimSpace(text) != "" {
				return text, extractSummaryFromBytes(raw, 512), nil
			}
		}
	}

	f, err := os.Open(path)
	if err != nil {
		return "", "", err
	}
	defer f.Close()

	buf, err := io.ReadAll(io.LimitReader(f, maxRead+1))
	if err != nil {
		return "", "", err
	}
	if int64(len(buf)) > maxRead {
		return "", "", errSkipTooLarge
	}
	if len(buf) == 0 {
		return "", "", nil
	}
	text, err := decodeBestEffortText(buf)
	if err != nil {
		return "", "", err
	}
	return text, extractSummaryFromBytes(buf, 512), nil
}

func decodeBestEffortText(buf []byte) (string, error) {
	if len(buf) == 0 {
		return "", nil
	}
	if s, ok := decodeUTF16WithBOM(buf); ok {
		if strings.TrimSpace(s) == "" || !looksLikeMeaningfulText(s) {
			return "", errSkipNonText
		}
		return s, nil
	}
	if s, ok := decodeLikelyUTF16NoBOM(buf); ok {
		if strings.TrimSpace(s) == "" || !looksLikeMeaningfulText(s) {
			return "", errSkipNonText
		}
		return s, nil
	}
	if s, ok := decodeByDetectedCharset(buf); ok {
		if strings.TrimSpace(s) == "" || !looksLikeMeaningfulText(s) {
			return "", errSkipNonText
		}
		return s, nil
	}
	if utf8.Valid(buf) {
		s := strings.TrimSpace(string(buf))
		if s == "" || !looksLikeMeaningfulText(s) {
			return "", errSkipNonText
		}
		return s, nil
	}
	if s, _, err := transform.String(simplifiedchinese.GB18030.NewDecoder(), string(buf)); err == nil {
		s = strings.TrimSpace(strings.ReplaceAll(s, "\x00", " "))
		if s != "" && looksLikeMeaningfulText(s) {
			return s, nil
		}
	}
	if bytes.IndexByte(buf, 0) >= 0 {
		return "", errSkipNonText
	}
	s := strings.TrimSpace(string(bytes.ToValidUTF8(buf, []byte(" "))))
	if s == "" || !looksLikeMeaningfulText(s) {
		return "", errSkipNonText
	}
	return s, nil
}

func decodeByDetectedCharset(buf []byte) (string, bool) {
	detector := chardet.NewTextDetector()
	res, err := detector.DetectBest(buf)
	if err != nil || res == nil || strings.TrimSpace(res.Charset) == "" {
		return "", false
	}
	charset := strings.ToLower(strings.TrimSpace(res.Charset))
	switch charset {
	case "utf-16le", "utf16le":
		return decodeUTF16Bytes(buf, true), true
	case "utf-16be", "utf16be":
		return decodeUTF16Bytes(buf, false), true
	case "utf-8", "utf8":
		if utf8.Valid(buf) {
			return strings.TrimSpace(string(buf)), true
		}
	}
	enc, err := htmlindex.Get(charset)
	if err != nil || enc == nil {
		return "", false
	}
	decoded, _, derr := transform.String(enc.NewDecoder(), string(buf))
	if derr != nil {
		return "", false
	}
	return strings.TrimSpace(strings.ReplaceAll(decoded, "\x00", " ")), true
}

func decodeUTF16WithBOM(buf []byte) (string, bool) {
	if len(buf) < 2 {
		return "", false
	}
	if buf[0] == 0xFF && buf[1] == 0xFE {
		return decodeUTF16Bytes(buf[2:], true), true
	}
	if buf[0] == 0xFE && buf[1] == 0xFF {
		return decodeUTF16Bytes(buf[2:], false), true
	}
	return "", false
}

func decodeLikelyUTF16NoBOM(buf []byte) (string, bool) {
	if len(buf) < 4 || len(buf)%2 != 0 {
		return "", false
	}
	var zeroEven, zeroOdd int
	for i := 0; i < len(buf); i += 2 {
		if buf[i] == 0 {
			zeroEven++
		}
		if i+1 < len(buf) && buf[i+1] == 0 {
			zeroOdd++
		}
	}
	total := len(buf) / 2
	if total == 0 {
		return "", false
	}
	leLikely := float64(zeroOdd)/float64(total) > 0.20
	beLikely := float64(zeroEven)/float64(total) > 0.20
	if !leLikely && !beLikely {
		return "", false
	}
	le := decodeUTF16Bytes(buf, true)
	be := decodeUTF16Bytes(buf, false)
	if scoreTextQuality(le) >= scoreTextQuality(be) {
		return le, true
	}
	return be, true
}

func decodeUTF16Bytes(buf []byte, littleEndian bool) string {
	if len(buf) < 2 {
		return ""
	}
	u16 := make([]uint16, 0, len(buf)/2)
	for i := 0; i+1 < len(buf); i += 2 {
		var v uint16
		if littleEndian {
			v = uint16(buf[i]) | uint16(buf[i+1])<<8
		} else {
			v = uint16(buf[i])<<8 | uint16(buf[i+1])
		}
		u16 = append(u16, v)
	}
	runes := utf16.Decode(u16)
	return strings.TrimSpace(string(runes))
}

func scoreTextQuality(s string) int {
	if s == "" {
		return 0
	}
	score := 0
	for _, r := range s {
		switch {
		case unicode.Is(unicode.Han, r):
			score += 4
		case unicode.IsLetter(r), unicode.IsDigit(r):
			score += 2
		case unicode.IsSpace(r):
			score += 1
		case unicode.IsPunct(r):
			score += 1
		}
	}
	return score
}

func looksLikeMeaningfulText(s string) bool {
	if s == "" {
		return false
	}
	var (
		total       int
		printable   int
		controlLike int
		repl        int
	)
	for _, r := range s {
		total++
		switch {
		case r == '\n' || r == '\r' || r == '\t':
			printable++
		case r == utf8.RuneError:
			repl++
		case r < 32:
			controlLike++
		case unicode.IsPrint(r):
			printable++
		default:
			controlLike++
		}
	}
	if total == 0 {
		return false
	}
	printRatio := float64(printable) / float64(total)
	controlRatio := float64(controlLike) / float64(total)
	replRatio := float64(repl) / float64(total)
	if printRatio < 0.70 {
		return false
	}
	if controlRatio > 0.08 {
		return false
	}
	if replRatio > 0.02 {
		return false
	}
	return true
}

func (b *blugeIndexer) extractPDFText(path string) (string, error) {
	out, err := enqueuePDFExtract(b.ctx, b.cfg.BaseDir, b.cfg.FilterConfig, path)
	if err != nil {
		return "", fmt.Errorf("pdftotext failed: %w", err)
	}
	text := strings.TrimSpace(string(bytes.ToValidUTF8([]byte(out), []byte(" "))))
	if text == "" {
		return "", errSkipNonText
	}
	return text, nil
}

func resolvePDFToTextExe(baseDir string, cfg fullTextFilterResolved) string {
	if cfg.PDFToTextPath != "" {
		if st, err := os.Stat(cfg.PDFToTextPath); err == nil && !st.IsDir() {
			return cfg.PDFToTextPath
		}
	}
	candidates := []string{
		filepath.Join(baseDir, "tools", "pdftotext.exe"),
		filepath.Join(baseDir, "lib", "pdftotext.exe"),
	}
	for _, p := range candidates {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	if p, err := exec.LookPath("pdftotext.exe"); err == nil && p != "" {
		return p
	}
	if p, err := exec.LookPath("pdftotext"); err == nil && p != "" {
		return p
	}
	return ""
}

func extractDOCXText(path string) (string, error) {
	zr, err := zip.OpenReader(path)
	if err != nil {
		return "", err
	}
	defer zr.Close()

	parts := make([]string, 0, 4)
	for _, f := range zr.File {
		name := strings.ToLower(strings.ReplaceAll(f.Name, "\\", "/"))
		if name != "word/document.xml" && !strings.HasPrefix(name, "word/header") && !strings.HasPrefix(name, "word/footer") {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			continue
		}
		buf, err := io.ReadAll(rc)
		_ = rc.Close()
		if err != nil || len(buf) == 0 {
			continue
		}
		txt := collectXMLCharData(buf)
		if strings.TrimSpace(txt) != "" {
			parts = append(parts, txt)
		}
	}
	text := strings.TrimSpace(strings.Join(parts, "\n"))
	if text == "" {
		return "", errSkipNonText
	}
	return text, nil
}

func extractXLSXText(path string) (string, error) {
	zr, err := zip.OpenReader(path)
	if err != nil {
		return "", err
	}
	defer zr.Close()

	var parts []string
	for _, f := range zr.File {
		name := strings.ToLower(strings.ReplaceAll(f.Name, "\\", "/"))
		if name != "xl/sharedstrings.xml" && !(strings.HasPrefix(name, "xl/worksheets/sheet") && strings.HasSuffix(name, ".xml")) {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			continue
		}
		buf, err := io.ReadAll(rc)
		_ = rc.Close()
		if err != nil || len(buf) == 0 {
			continue
		}
		text := collectXMLCharData(buf)
		if strings.TrimSpace(text) != "" {
			parts = append(parts, text)
		}
	}
	out := strings.TrimSpace(strings.Join(parts, "\n"))
	if out == "" {
		return "", errSkipNonText
	}
	return out, nil
}

func collectXMLCharData(buf []byte) string {
	dec := xml.NewDecoder(bytes.NewReader(buf))
	var out strings.Builder
	for {
		tok, err := dec.Token()
		if err != nil {
			break
		}
		if c, ok := tok.(xml.CharData); ok {
			s := strings.TrimSpace(string(c))
			if s == "" {
				continue
			}
			if out.Len() > 0 {
				out.WriteByte(' ')
			}
			out.WriteString(html.UnescapeString(s))
		}
	}
	return strings.TrimSpace(out.String())
}

func extractSummaryFromBytes(buf []byte, maxBytes int) string {
	if len(buf) == 0 || maxBytes <= 0 {
		return ""
	}
	if len(buf) > maxBytes {
		buf = buf[:maxBytes]
	}
	if s, err := decodeBestEffortText(buf); err == nil {
		return extractSummaryFromText(s, maxBytes)
	}
	return ""
}

func extractSummaryFromText(text string, maxBytes int) string {
	text = strings.TrimSpace(strings.ReplaceAll(strings.ReplaceAll(text, "\r\n", "\n"), "\r", "\n"))
	if text == "" {
		return ""
	}
	firstBlock := text
	if idx := strings.Index(firstBlock, "\n\n"); idx >= 0 {
		firstBlock = firstBlock[:idx]
	}
	firstBlock = strings.TrimSpace(strings.ReplaceAll(firstBlock, "\n", " "))
	if firstBlock == "" {
		return ""
	}
	out := []byte(firstBlock)
	if len(out) <= maxBytes {
		return firstBlock
	}
	out = out[:maxBytes]
	for len(out) > 0 && !utf8.Valid(out) {
		out = out[:len(out)-1]
	}
	return strings.TrimSpace(string(out))
}
