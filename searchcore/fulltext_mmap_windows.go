//go:build windows

package main

import (
	"io"
	"os"
	"unsafe"

	"golang.org/x/sys/windows"
)

func mmapReadFileUpTo(path string, limit int64) ([]byte, error) {
	if limit <= 0 {
		return nil, nil
	}
	st, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	sz := st.Size()
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}
	h, err := windows.CreateFile(p,
		windows.GENERIC_READ,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE,
		nil,
		windows.OPEN_EXISTING,
		windows.FILE_ATTRIBUTE_NORMAL,
		0,
	)
	if err != nil {
		return nil, err
	}
	defer windows.CloseHandle(h)

	readN := sz
	if readN > limit {
		readN = limit
	}
	if readN <= 0 {
		return nil, nil
	}

	maxSz := uint32(readN)
	fm, err := windows.CreateFileMapping(h, nil, windows.PAGE_READONLY, 0, maxSz, nil)
	if err != nil {
		return nil, err
	}
	defer windows.CloseHandle(fm)

	addr, err := windows.MapViewOfFile(fm, windows.FILE_MAP_READ, 0, 0, uintptr(maxSz))
	if err != nil {
		return nil, err
	}
	defer windows.UnmapViewOfFile(addr)

	slice := unsafe.Slice((*byte)(unsafe.Pointer(addr)), int(readN))
	out := make([]byte, int(readN))
	copy(out, slice)
	return out, nil
}

func readFilePrefix(path string, n int) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	buf := make([]byte, n)
	m, err := io.ReadFull(f, buf)
	if err == io.ErrUnexpectedEOF || err == io.EOF {
		return buf[:m], nil
	}
	if err != nil {
		return nil, err
	}
	return buf, nil
}

func sniffBinaryOrNonText(prefix []byte) bool {
	if len(prefix) == 0 {
		return true
	}
	nul := 0
	for _, c := range prefix {
		if c == 0 {
			nul++
		}
	}
	if float64(nul)/float64(len(prefix)) > 0.10 {
		return true
	}
	// 常见二进制头
	if len(prefix) >= 4 {
		switch {
		case prefix[0] == 0x4d && prefix[1] == 0x5a: // MZ
			return true
		case prefix[0] == 0x7f && prefix[1] == 'E' && prefix[2] == 'L' && prefix[3] == 'F':
			return true
		case prefix[0] == 0x50 && prefix[1] == 0x4b && (prefix[2] == 3 || prefix[2] == 5 || prefix[2] == 7): // PK zip family
			// docx/xlsx 为 zip，由专用解析处理；此处仅对非解析扩展判定
			return false
		}
	}
	return false
}

func min64(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}
