//go:build windows

package main

import (
	"database/sql"
	"errors"
	"fmt"
	"path/filepath"
	"strings"
)

type indexMetaStore struct {
	db *sql.DB
}

type indexPersistState struct {
	InitialScanDone bool
	IndexedFiles    int64
	ScanPhase       string
	LastUpdated     string
}

func openIndexMetaStore(indexDir string) (*indexMetaStore, error) {
	metaPath := filepath.Join(indexDir, "index_meta.db")
	db, err := sql.Open("sqlite", "file:"+filepath.ToSlash(metaPath)+"?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)")
	if err != nil {
		return nil, err
	}
	if _, err := db.Exec(`
CREATE TABLE IF NOT EXISTS file_meta (
  path TEXT PRIMARY KEY,
  size INTEGER NOT NULL,
  mtime_ns INTEGER NOT NULL,
  indexed_at TEXT NOT NULL,
  content_hash INTEGER NOT NULL DEFAULT 0,
  fast_hash INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_file_meta_mtime ON file_meta(mtime_ns);
CREATE TABLE IF NOT EXISTS usn_cursor (
  drive TEXT PRIMARY KEY,
  next_usn INTEGER NOT NULL,
  journal_id INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS index_state (
  id INTEGER PRIMARY KEY CHECK(id=1),
  initial_scan_done INTEGER NOT NULL DEFAULT 0,
  indexed_files INTEGER NOT NULL DEFAULT 0,
  scan_phase TEXT NOT NULL DEFAULT '',
  last_updated TEXT NOT NULL DEFAULT ''
);
`); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("init file_meta failed: %w", err)
	}
	_, _ = db.Exec(`ALTER TABLE file_meta ADD COLUMN content_hash INTEGER NOT NULL DEFAULT 0`)
	_, _ = db.Exec(`ALTER TABLE file_meta ADD COLUMN fast_hash INTEGER NOT NULL DEFAULT 0`)
	return &indexMetaStore{db: db}, nil
}

func (m *indexMetaStore) Close() error {
	if m == nil || m.db == nil {
		return nil
	}
	return m.db.Close()
}

func (m *indexMetaStore) Get(path string) (fileFingerprint, bool, error) {
	if m == nil || m.db == nil {
		return fileFingerprint{}, false, nil
	}
	var fp fileFingerprint
	err := m.db.QueryRow(`SELECT size, mtime_ns, COALESCE(content_hash,0), COALESCE(fast_hash,0) FROM file_meta WHERE path=?`, docIDForPath(path)).Scan(&fp.Size, &fp.ModNano, &fp.ContentHash, &fp.FastHash)
	if err == sql.ErrNoRows {
		return fileFingerprint{}, false, nil
	}
	if err != nil {
		return fileFingerprint{}, false, err
	}
	return fp, true, nil
}

func (m *indexMetaStore) Upsert(path string, fp fileFingerprint) error {
	if m == nil || m.db == nil {
		return nil
	}
	_, err := m.db.Exec(`
INSERT INTO file_meta(path, size, mtime_ns, content_hash, fast_hash, indexed_at)
VALUES(?,?,?,?,?,datetime('now'))
ON CONFLICT(path) DO UPDATE SET
  size=excluded.size,
  mtime_ns=excluded.mtime_ns,
  content_hash=excluded.content_hash,
  fast_hash=excluded.fast_hash,
  indexed_at=excluded.indexed_at
`, docIDForPath(path), fp.Size, fp.ModNano, fp.ContentHash, fp.FastHash)
	return err
}

func (m *indexMetaStore) Delete(path string) error {
	if m == nil || m.db == nil {
		return nil
	}
	_, err := m.db.Exec(`DELETE FROM file_meta WHERE path=?`, docIDForPath(path))
	return err
}

func (m *indexMetaStore) LoadAll() (map[string]fileFingerprint, error) {
	out := map[string]fileFingerprint{}
	if m == nil || m.db == nil {
		return out, nil
	}
	rows, err := m.db.Query(`SELECT path, size, mtime_ns, COALESCE(content_hash,0), COALESCE(fast_hash,0) FROM file_meta`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var path string
		var fp fileFingerprint
		if err := rows.Scan(&path, &fp.Size, &fp.ModNano, &fp.ContentHash, &fp.FastHash); err != nil {
			continue
		}
		out[path] = fp
	}
	return out, rows.Err()
}

func (m *indexMetaStore) LoadUSNCursor(driveKey string) (nextUSN int64, journalID int64, ok bool, err error) {
	if m == nil || m.db == nil {
		return 0, 0, false, nil
	}
	driveKey = strings.TrimSpace(driveKey)
	if driveKey == "" {
		return 0, 0, false, nil
	}
	var n, j sql.NullInt64
	err = m.db.QueryRow(`SELECT next_usn, journal_id FROM usn_cursor WHERE drive=?`, driveKey).Scan(&n, &j)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, 0, false, nil
	}
	if err != nil {
		return 0, 0, false, err
	}
	if !n.Valid || !j.Valid {
		return 0, 0, false, nil
	}
	return n.Int64, j.Int64, true, nil
}

func (m *indexMetaStore) SaveUSNCursor(driveKey string, nextUSN, journalID int64) error {
	if m == nil || m.db == nil {
		return nil
	}
	driveKey = strings.TrimSpace(driveKey)
	if driveKey == "" {
		return nil
	}
	_, err := m.db.Exec(`
INSERT INTO usn_cursor(drive, next_usn, journal_id)
VALUES(?,?,?)
ON CONFLICT(drive) DO UPDATE SET
  next_usn=excluded.next_usn,
  journal_id=excluded.journal_id
`, driveKey, nextUSN, journalID)
	return err
}

func (m *indexMetaStore) LoadIndexState() (indexPersistState, bool, error) {
	if m == nil || m.db == nil {
		return indexPersistState{}, false, nil
	}
	var (
		initialDone int64
		indexed     int64
		phase       string
		updated     string
	)
	err := m.db.QueryRow(`
SELECT initial_scan_done, indexed_files, scan_phase, last_updated
FROM index_state WHERE id=1
`).Scan(&initialDone, &indexed, &phase, &updated)
	if errors.Is(err, sql.ErrNoRows) {
		return indexPersistState{}, false, nil
	}
	if err != nil {
		return indexPersistState{}, false, err
	}
	return indexPersistState{
		InitialScanDone: initialDone > 0,
		IndexedFiles:    indexed,
		ScanPhase:       phase,
		LastUpdated:     updated,
	}, true, nil
}

func (m *indexMetaStore) SaveIndexState(st indexPersistState) error {
	if m == nil || m.db == nil {
		return nil
	}
	initialDone := int64(0)
	if st.InitialScanDone {
		initialDone = 1
	}
	_, err := m.db.Exec(`
INSERT INTO index_state(id, initial_scan_done, indexed_files, scan_phase, last_updated)
VALUES(1,?,?,?,?)
ON CONFLICT(id) DO UPDATE SET
  initial_scan_done=excluded.initial_scan_done,
  indexed_files=excluded.indexed_files,
  scan_phase=excluded.scan_phase,
  last_updated=excluded.last_updated
`, initialDone, st.IndexedFiles, strings.TrimSpace(st.ScanPhase), strings.TrimSpace(st.LastUpdated))
	return err
}
