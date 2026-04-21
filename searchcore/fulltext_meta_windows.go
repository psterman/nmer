//go:build windows

package main

import (
	"database/sql"
	"fmt"
	"path/filepath"
)

type indexMetaStore struct {
	db *sql.DB
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
  indexed_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_file_meta_mtime ON file_meta(mtime_ns);
`); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("init file_meta failed: %w", err)
	}
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
	err := m.db.QueryRow(`SELECT size, mtime_ns FROM file_meta WHERE path=?`, docIDForPath(path)).Scan(&fp.Size, &fp.ModNano)
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
INSERT INTO file_meta(path, size, mtime_ns, indexed_at)
VALUES(?,?,?,datetime('now'))
ON CONFLICT(path) DO UPDATE SET
  size=excluded.size,
  mtime_ns=excluded.mtime_ns,
  indexed_at=excluded.indexed_at
`, docIDForPath(path), fp.Size, fp.ModNano)
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
	rows, err := m.db.Query(`SELECT path, size, mtime_ns FROM file_meta`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var path string
		var fp fileFingerprint
		if err := rows.Scan(&path, &fp.Size, &fp.ModNano); err != nil {
			continue
		}
		out[path] = fp
	}
	return out, rows.Err()
}
