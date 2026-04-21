//go:build windows

package main

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/xml"
	"fmt"
	"html"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"
)

func (b *blugeIndexer) readFileForIndex(path string, fileSize int64) (string, string, error) {
	ext := pathExtLower(path)
	switch ext {
	case "pdf":
		text, err := b.extractPDFText(path)
		if err != nil {
			return "", "", err
		}
		return text, trimPreview(text, 180), nil
	case "docx":
		text, err := extractDOCXText(path)
		if err != nil {
			return "", "", err
		}
		return text, trimPreview(text, 180), nil
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
	if bytes.IndexByte(buf, 0) >= 0 {
		return "", "", errSkipNonText
	}
	if !utf8.Valid(buf) {
		buf = bytes.ToValidUTF8(buf, []byte(" "))
	}
	text := string(buf)
	return text, trimPreview(text, 180), nil
}

func (b *blugeIndexer) extractPDFText(path string) (string, error) {
	tool := resolvePDFToTextExe(b.cfg.BaseDir, b.cfg.FilterConfig)
	if tool == "" {
		return "", fmt.Errorf("pdftotext not found")
	}

	ctx, cancel := context.WithTimeout(b.ctx, 25*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, tool, "-enc", "UTF-8", "-q", "-nopgbrk", path, "-")
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("pdftotext failed: %w", err)
	}
	text := strings.TrimSpace(string(bytes.ToValidUTF8(out, []byte(" "))))
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
