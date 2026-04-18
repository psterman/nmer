//go:build windows

package main

import (
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"unicode/utf16"
	"unsafe"
)

const (
	assocFInitDefaultToStar = 0x4
	assocStrFriendlyDocName = 3
	assocStrPerceivedType   = 18
	assocStrCommand         = 1
	assocStrExecutable      = 2
)

func assocQueryString(assocStr uint32, pszAssoc string) string {
	dll := syscall.NewLazyDLL("shlwapi.dll")
	proc := dll.NewProc("AssocQueryStringW")
	psz, err := syscall.UTF16PtrFromString(pszAssoc)
	if err != nil {
		return ""
	}
	var cch uint32
	r, _, _ := proc.Call(uintptr(assocFInitDefaultToStar), uintptr(assocStr), uintptr(unsafe.Pointer(psz)), 0, 0, uintptr(unsafe.Pointer(&cch)))
	if r != 0 && r != uintptr(0x8007007a) {
		return ""
	}
	if cch < 1 {
		return ""
	}
	buf := make([]uint16, cch)
	r2, _, _ := proc.Call(uintptr(assocFInitDefaultToStar), uintptr(assocStr), uintptr(unsafe.Pointer(psz)), 0, uintptr(unsafe.Pointer(&buf[0])), uintptr(unsafe.Pointer(&cch)))
	if r2 != 0 || cch == 0 {
		return ""
	}
	return string(utf16.Decode(buf[:cch-1]))
}

func getAssocBundleForExt(extWithDot string) assocBundle {
	key := strings.ToLower(extWithDot)
	if key == "" {
		key = "."
	}
	if !strings.HasPrefix(key, ".") {
		key = "." + key
	}
	return assocBundle{
		FriendlyDocName: assocQueryString(assocStrFriendlyDocName, key),
		PerceivedType:   strings.ToLower(strings.TrimSpace(assocQueryString(assocStrPerceivedType, key))),
		OpenCommand:     assocQueryString(assocStrCommand, key),
		Executable:      assocQueryString(assocStrExecutable, key),
	}
}

func getFileDescriptionFromPath(filePath string) string {
	if filePath == "" {
		return ""
	}
	if _, err := os.Stat(filePath); err != nil {
		return ""
	}
	return strings.TrimSuffix(filepath.Base(filePath), filepath.Ext(filePath))
}
