//go:build windows

package main

import (
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	modKernel32          = windows.NewLazySystemDLL("kernel32.dll")
	modUser32            = windows.NewLazySystemDLL("user32.dll")
	procGetLastInputInfo = modUser32.NewProc("GetLastInputInfo")
	procGetDriveTypeW    = modKernel32.NewProc("GetDriveTypeW")
	procGetTickCount64   = modKernel32.NewProc("GetTickCount64")
)

type lastInputInfo struct {
	CbSize uint32
	DwTime uint32
}

func userIdleForAtLeast(minIdle time.Duration) bool {
	if minIdle <= 0 {
		return true
	}
	info := lastInputInfo{CbSize: uint32(unsafe.Sizeof(lastInputInfo{}))}
	r1, _, _ := procGetLastInputInfo.Call(uintptr(unsafe.Pointer(&info)))
	if r1 == 0 {
		return true
	}
	now, _, _ := procGetTickCount64.Call()
	now64 := uint64(now)
	var elapsed uint64
	if uint64(info.DwTime) <= now64 {
		elapsed = now64 - uint64(info.DwTime)
	}
	return time.Duration(elapsed)*time.Millisecond >= minIdle
}
