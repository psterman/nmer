package main

// curDatabaseAttached 为 true 时表示已成功 ATTACH Data/CursorData.db 为 cur，可使用 cur.ClipboardHistory
var curDatabaseAttached bool

// clipboardMainIsCursorData 为 true 表示主连接已是 Data\CursorData.db（与 AHK ClipboardDB 一致），此时无需 cur 前缀即可查 ClipboardHistory
var clipboardMainIsCursorData bool
