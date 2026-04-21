//go:build windows

package main

import (
	"context"
	"errors"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

const defaultPDFWorkerN = 3

type pdfExtractJob struct {
	ctx  context.Context
	tool string
	path string
	out  chan pdfExtractResult
}

type pdfExtractResult struct {
	text string
	err  error
}

var (
	pdfWorkerOnce sync.Once
	pdfJobCh      chan pdfExtractJob
)

func initPDFPool(n int) {
	if n < 1 {
		n = 1
	}
	if n > 8 {
		n = 8
	}
	pdfJobCh = make(chan pdfExtractJob, n*4)
	for i := 0; i < n; i++ {
		go pdfWorkerLoop()
	}
}

func pdfWorkerLoop() {
	for job := range pdfJobCh {
		text, err := runPdftotextOnce(job.ctx, job.tool, job.path)
		job.out <- pdfExtractResult{text: text, err: err}
	}
}

func runPdftotextOnce(ctx context.Context, tool, path string) (string, error) {
	if tool == "" {
		return "", exec.ErrNotFound
	}
	cctx, cancel := context.WithTimeout(ctx, 25*time.Second)
	defer cancel()
	cmd := exec.CommandContext(cctx, tool, "-enc", "UTF-8", "-q", "-nopgbrk", path, "-")
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func enqueuePDFExtract(ctx context.Context, baseDir string, filter fullTextFilterResolved, path string) (string, error) {
	pdfWorkerOnce.Do(func() { initPDFPool(defaultPDFWorkerN) })
	tool := resolvePDFToTextExe(baseDir, filter)
	if tool == "" {
		return "", errors.New("pdftotext not found")
	}
	tool, _ = filepath.Abs(tool)
	resCh := make(chan pdfExtractResult, 1)
	job := pdfExtractJob{ctx: ctx, tool: tool, path: path, out: resCh}
	select {
	case pdfJobCh <- job:
	case <-ctx.Done():
		return "", ctx.Err()
	}
	select {
	case r := <-resCh:
		return r.text, r.err
	case <-ctx.Done():
		return "", ctx.Err()
	}
}
