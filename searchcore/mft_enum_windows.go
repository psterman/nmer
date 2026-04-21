//go:build windows

package main

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"path/filepath"
	"strings"
	"unicode/utf16"

	"golang.org/x/sys/windows"
)

// FSCTL_ENUM_USN_DATA — 通过 NTFS MFT 枚举卷上的文件元数据（需管理员或备份权限）。
const fsctlEnumUsnData = uint32(0x000900b3)

type mftEnumData struct {
	StartFileReferenceNumber uint64
	LowUsn                   uint64
	HighUsn                  uint64
}

type mftNode struct {
	parent uint64
	name   string
	attrs  uint32
}

func driveLetterFromRoot(root string) (byte, error) {
	clean := filepath.Clean(root)
	if len(clean) < 2 {
		return 0, errors.New("invalid root")
	}
	if clean[1] != ':' {
		return 0, errors.New("not a drive root")
	}
	ch := clean[0]
	if ch >= 'a' && ch <= 'z' {
		ch = ch - 'a' + 'A'
	}
	if ch < 'A' || ch > 'Z' {
		return 0, errors.New("invalid drive letter")
	}
	return ch, nil
}

func openNTFSVolumeHandle(drive byte) (windows.Handle, error) {
	vol := fmt.Sprintf(`\\.\%c:`, drive)
	u, err := windows.UTF16PtrFromString(vol)
	if err != nil {
		return 0, err
	}
	h, err := windows.CreateFile(u,
		windows.GENERIC_READ,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE,
		nil,
		windows.OPEN_EXISTING,
		windows.FILE_FLAG_BACKUP_SEMANTICS,
		0,
	)
	if err != nil {
		return 0, err
	}
	return h, nil
}

func decodeUTF16LE(b []byte) (string, error) {
	if len(b)%2 != 0 {
		return "", errors.New("odd utf16 length")
	}
	u := make([]uint16, len(b)/2)
	for i := 0; i < len(u); i++ {
		u[i] = binary.LittleEndian.Uint16(b[i*2:])
	}
	return string(utf16.Decode(u)), nil
}

func enumerateMFTVolume(ctx context.Context, drive byte, nodes map[uint64]mftNode) error {
	if nodes == nil {
		return errors.New("nodes map required")
	}
	h, err := openNTFSVolumeHandle(drive)
	if err != nil {
		return fmt.Errorf("open volume %c: %w", drive, err)
	}
	defer windows.CloseHandle(h)

	inBuf := make([]byte, 24)
	outBuf := make([]byte, 1024*1024)
	var startFRN uint64

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		med := mftEnumData{
			StartFileReferenceNumber: startFRN,
			LowUsn:                   0,
			HighUsn:                  ^uint64(0),
		}
		binary.LittleEndian.PutUint64(inBuf[0:8], med.StartFileReferenceNumber)
		binary.LittleEndian.PutUint64(inBuf[8:16], med.LowUsn)
		binary.LittleEndian.PutUint64(inBuf[16:24], med.HighUsn)

		var br uint32
		err := windows.DeviceIoControl(h, fsctlEnumUsnData, &inBuf[0], uint32(len(inBuf)), &outBuf[0], uint32(len(outBuf)), &br, nil)
		if err != nil {
			if err == windows.ERROR_HANDLE_EOF || err == windows.ERROR_NO_MORE_FILES {
				break
			}
			return fmt.Errorf("FSCTL_ENUM_USN_DATA: %w", err)
		}
		if br <= 8 {
			break
		}

		nextStart := binary.LittleEndian.Uint64(outBuf[0:8])
		off := 8
		parsed := 0
		for off+60 <= int(br) {
			rec := outBuf[off:]
			reclen := binary.LittleEndian.Uint32(rec[0:4])
			if reclen < 60 || off+int(reclen) > int(br) {
				break
			}
			major := binary.LittleEndian.Uint16(rec[4:6])
			if major < 2 || major > 4 {
				off += int(reclen)
				continue
			}
			frn := binary.LittleEndian.Uint64(rec[8:16])
			parent := binary.LittleEndian.Uint64(rec[16:24])
			attrs := binary.LittleEndian.Uint32(rec[52:56])
			nameLen := int(binary.LittleEndian.Uint16(rec[56:58]))
			nameOff := int(binary.LittleEndian.Uint16(rec[58:60]))
			if nameOff < 0 || nameOff+nameLen > int(reclen) {
				off += int(reclen)
				continue
			}
			nameBytes := rec[nameOff : nameOff+nameLen]
			name, nerr := decodeUTF16LE(nameBytes)
			if nerr != nil || name == "" {
				off += int(reclen)
				continue
			}
			nodes[frn] = mftNode{parent: parent, name: name, attrs: attrs}
			parsed++
			off += int(reclen)
		}

		if nextStart == startFRN && parsed == 0 {
			break
		}
		startFRN = nextStart
		if parsed == 0 && nextStart == 0 {
			break
		}
	}
	return nil
}

// resolveMFTPath 由 FRN 反查相对路径（不含盘符），失败返回空。
func resolveMFTPath(frn uint64, nodes map[uint64]mftNode, maxDepth int) string {
	if frn == 0 || nodes == nil {
		return ""
	}
	var parts []string
	seen := map[uint64]int{}
	cur := frn
	for depth := 0; depth < maxDepth; depth++ {
		if seen[cur] > 0 {
			break
		}
		seen[cur]++
		n, ok := nodes[cur]
		if !ok {
			break
		}
		parts = append(parts, n.name)
		if n.parent == 0 || n.parent == cur {
			break
		}
		cur = n.parent
	}
	for i, j := 0, len(parts)-1; i < j; i, j = i+1, j-1 {
		parts[i], parts[j] = parts[j], parts[i]
	}
	return strings.Join(parts, `\`)
}

// walkRootWithMFT 使用 MFT 枚举在卷根（如 C:\）下发现文件并回调；frnMap 可选，用于 USN 路径解析。
// 返回值为已发现并回调的文件数。
func walkRootWithMFT(ctx context.Context, root string, frnMap map[uint64]string, emitFile func(absPath string) error) (int, error) {
	drive, err := driveLetterFromRoot(root)
	if err != nil {
		return 0, err
	}
	nodes := make(map[uint64]mftNode, 1<<20)
	if err := enumerateMFTVolume(ctx, drive, nodes); err != nil {
		return 0, err
	}
	prefix := string(drive) + ":"
	emitted := 0
	for frn, n := range nodes {
		rel := resolveMFTPath(frn, nodes, 512)
		if rel == "" {
			continue
		}
		abs := filepath.Clean(prefix + `\` + rel)
		if frnMap != nil {
			frnMap[frn] = abs
		}
		if n.attrs&windows.FILE_ATTRIBUTE_DIRECTORY != 0 {
			continue
		}
		if err := emitFile(abs); err != nil {
			return emitted, err
		}
		emitted++
	}
	return emitted, nil
}
