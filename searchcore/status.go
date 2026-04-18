package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
)

type serverStatus struct {
	Base                 string `json:"base"`
	ClipboardDB          string `json:"clipboardDbPath"`
	MainIsCursorData     bool   `json:"mainIsCursorDataDb"`
	CursorDataAttached   bool   `json:"cursorDataAttached"`
	ClipMainPresent      bool   `json:"clipMainPresent"`
	CurClipMainPresent   bool   `json:"curClipMainPresent"`
	ClipboardHistoryFTS  bool   `json:"clipboardHistoryFts"`
	EverythingDLLPresent bool   `json:"everythingDllPresent"`
	EverythingExeFound   bool   `json:"everythingExeFound"`
}

func handleStatus(w http.ResponseWriter, r *http.Request, db *sql.DB, absBase string) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")

	st := serverStatus{
		Base:                 absBase,
		ClipboardDB:          filepath.Join(absBase, "Clipboard.db"),
		MainIsCursorData:     clipboardMainIsCursorData,
		CursorDataAttached:   curDatabaseAttached,
		EverythingDLLPresent: fileExists(filepath.Join(absBase, "lib", "everything64.dll")),
		EverythingExeFound:   resolveEverythingExe(absBase) != "",
	}
	st.ClipMainPresent = tableNameExists(db, "ClipMain")
	st.CurClipMainPresent = curDatabaseAttached && tableExistsInAttached(db, "cur", "ClipMain")
	_, fts := detectClipboardFTS(db)
	st.ClipboardHistoryFTS = fts

	_ = json.NewEncoder(w).Encode(st)
}

func fileExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}

func tableNameExists(db *sql.DB, name string) bool {
	var n string
	err := db.QueryRow(`SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name=? LIMIT 1`, name).Scan(&n)
	return err == nil && n != ""
}
