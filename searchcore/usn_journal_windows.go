//go:build windows

package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"golang.org/x/sys/windows"
)

const (
	fsctlCreateUsnJournal = uint32(0x000900e7)
	fsctlQueryUsnJournal  = uint32(0x000900b9)
	fsctlReadUsnJournal     = uint32(0x000900bb)

	usnReasonDataOverwrite = uint32(0x00000001)
	usnReasonDataExtend    = uint32(0x00000002)
	usnReasonRenameNew     = uint32(0x00002000)
	usnReasonFileCreate    = uint32(0x00000100)
	usnReasonFileDelete    = uint32(0x00000200)
	usnReasonClose         = uint32(0x80000000)

	usnReasonWatched = usnReasonDataOverwrite | usnReasonDataExtend | usnReasonRenameNew |
		usnReasonFileCreate | usnReasonFileDelete
)

type readUsnJournalDataV0 struct {
	StartUsn          int64
	ReasonMask        uint32
	ReturnOnlyOnClose uint32
	Timeout           uint32
	BytesToWaitFor    uint32
	UsnJournalID      uint64
	MinMajorVersion   uint16
	MaxMajorVersion   uint16
}

func ensureUSNJournal(h windows.Handle) error {
	var out [256]byte
	var br uint32
	err := windows.DeviceIoControl(h, fsctlQueryUsnJournal, nil, 0, &out[0], uint32(len(out)), &br, nil)
	if err == nil && br >= 24 {
		return nil
	}
	in := make([]byte, 8)
	binary.LittleEndian.PutUint32(in[0:4], 0x20000000)
	binary.LittleEndian.PutUint32(in[4:8], 0x100000)
	return windows.DeviceIoControl(h, fsctlCreateUsnJournal, &in[0], uint32(len(in)), nil, 0, &br, nil)
}

func queryUSNJournalInfo(h windows.Handle) (journalID int64, firstUSN int64, nextUSN int64, err error) {
	var out [256]byte
	var br uint32
	err = windows.DeviceIoControl(h, fsctlQueryUsnJournal, nil, 0, &out[0], uint32(len(out)), &br, nil)
	if err != nil {
		return 0, 0, 0, err
	}
	if br < 24 {
		return 0, 0, 0, errors.New("short USN_JOURNAL_DATA")
	}
	journalID = int64(binary.LittleEndian.Uint64(out[0:8]))
	firstUSN = int64(binary.LittleEndian.Uint64(out[8:16]))
	nextUSN = int64(binary.LittleEndian.Uint64(out[16:24]))
	return journalID, firstUSN, nextUSN, nil
}

func packReadUsnJournalData(r *readUsnJournalDataV0) []byte {
	b := make([]byte, 36)
	binary.LittleEndian.PutUint64(b[0:8], uint64(r.StartUsn))
	binary.LittleEndian.PutUint32(b[8:12], r.ReasonMask)
	binary.LittleEndian.PutUint32(b[12:16], r.ReturnOnlyOnClose)
	binary.LittleEndian.PutUint32(b[16:20], r.Timeout)
	binary.LittleEndian.PutUint32(b[20:24], r.BytesToWaitFor)
	binary.LittleEndian.PutUint64(b[24:32], r.UsnJournalID)
	binary.LittleEndian.PutUint16(b[32:34], r.MinMajorVersion)
	binary.LittleEndian.PutUint16(b[34:36], r.MaxMajorVersion)
	return b
}

func (b *blugeIndexer) usnJournalLoop(drive byte) {
	dKey := string([]byte{drive})
	ctx := b.ctx
	h, err := openNTFSVolumeHandle(drive)
	if err != nil {
		b.appendAlert(fmt.Sprintf("USN: 无法打开卷 %c: %v", drive, err))
		return
	}
	defer windows.CloseHandle(h)

	if err := ensureUSNJournal(h); err != nil {
		b.appendAlert(fmt.Sprintf("USN: 无法创建/查询日志 %c: %v", drive, err))
		return
	}
	journalID, firstUSN, _, err := queryUSNJournalInfo(h)
	if err != nil {
		b.appendAlert(fmt.Sprintf("USN: QUERY 失败 %c: %v", drive, err))
		return
	}

	startUSN := firstUSN
	if b.meta != nil {
		if saved, jid, ok, _ := b.meta.LoadUSNCursor(dKey); ok && jid == journalID {
			startUSN = saved
		}
	}

	outBuf := make([]byte, 1024*1024)
	ticker := time.NewTicker(800 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			read := readUsnJournalDataV0{
				StartUsn:          startUSN,
				ReasonMask:        usnReasonWatched,
				ReturnOnlyOnClose: 0,
				Timeout:           0,
				BytesToWaitFor:    0,
				UsnJournalID:      uint64(journalID),
				MinMajorVersion:   2,
				MaxMajorVersion:   4,
			}
			inBuf := packReadUsnJournalData(&read)
			var br uint32
			err := windows.DeviceIoControl(h, fsctlReadUsnJournal, &inBuf[0], uint32(len(inBuf)), &outBuf[0], uint32(len(outBuf)), &br, nil)
			if err != nil {
				continue
			}
			if br <= 8 {
				continue
			}
			nextPos := int64(binary.LittleEndian.Uint64(outBuf[0:8]))
			off := 8
			for off+60 <= int(br) {
				rec := outBuf[off:]
				reclen := binary.LittleEndian.Uint32(rec[0:4])
				if reclen < 60 || off+int(reclen) > int(br) {
					break
				}
				major := binary.LittleEndian.Uint16(rec[4:6])
				if major < 2 {
					off += int(reclen)
					continue
				}
				frn := binary.LittleEndian.Uint64(rec[8:16])
				parent := binary.LittleEndian.Uint64(rec[16:24])
				usn := int64(binary.LittleEndian.Uint64(rec[24:32]))
				reason := binary.LittleEndian.Uint32(rec[40:44])
				attrs := binary.LittleEndian.Uint32(rec[52:56])
				nameLen := int(binary.LittleEndian.Uint16(rec[56:58]))
				nameOff := int(binary.LittleEndian.Uint16(rec[58:60]))
				if nameOff < 0 || nameOff+nameLen > int(reclen) {
					off += int(reclen)
					continue
				}
				name, nerr := decodeUTF16LE(rec[nameOff : nameOff+nameLen])
				if nerr != nil || name == "" {
					off += int(reclen)
					continue
				}

				abs := b.resolveUSNPath(parent, name)
				if abs == "" {
					off += int(reclen)
					continue
				}
				abs = filepath.Clean(abs)

				isDel := (reason & usnReasonFileDelete) != 0
				if isDel {
					b.enqueueTask(indexTask{Path: abs, Delete: true})
					b.frnPathMu.Lock()
					delete(b.frnToAbs, frn)
					b.frnPathMu.Unlock()
				} else if (reason & (usnReasonDataOverwrite | usnReasonDataExtend | usnReasonRenameNew | usnReasonFileCreate | usnReasonClose)) != 0 {
					if attrs&uint32(windows.FILE_ATTRIBUTE_DIRECTORY) != 0 {
						b.rememberFRNPath(frn, abs)
						b.addWatch(abs)
					} else {
						b.rememberFRNPath(frn, abs)
						b.enqueueTask(indexTask{Path: abs})
					}
				}

				if usn > startUSN {
					startUSN = usn
				}
				off += int(reclen)
			}
			if nextPos > startUSN {
				startUSN = nextPos
			}
			if b.meta != nil {
				_ = b.meta.SaveUSNCursor(dKey, startUSN, journalID)
			}
		}
	}
}

func (b *blugeIndexer) resolveUSNPath(parentFRN uint64, childName string) string {
	b.frnPathMu.RLock()
	base, ok := b.frnToAbs[parentFRN]
	b.frnPathMu.RUnlock()
	if !ok || base == "" {
		return ""
	}
	return filepath.Join(base, childName)
}

func (b *blugeIndexer) rememberFRNPath(frn uint64, abs string) {
	if frn == 0 || abs == "" {
		return
	}
	b.frnPathMu.Lock()
	if b.frnToAbs == nil {
		b.frnToAbs = make(map[uint64]string)
	}
	b.frnToAbs[frn] = filepath.Clean(abs)
	b.frnPathMu.Unlock()
}

func isVolumeRootPath(p string) bool {
	c := filepath.Clean(p)
	if len(c) != 3 {
		return false
	}
	if c[1] != ':' {
		return false
	}
	if c[2] != '\\' && c[2] != '/' {
		return false
	}
	return true
}
