# ClipboardFTS5 高性能剪贴板管理器模块

## 概述

这是一个基于 SQLite FTS5 全文搜索的高性能剪贴板管理器模块，支持文本和图片的异步入库，具备智能内容分类、图片缩略图生成和数据自动清理功能。

## 功能特性

- ✅ **SQLite FTS5 全文搜索**：高效的全文索引和搜索能力
- ✅ **WAL 模式**：支持并发读写，提升性能
- ✅ **智能内容分类**：自动识别 URL、代码块、Email、普通文本
- ✅ **图片处理**：自动保存图片并生成 64x64 缩略图（Base64 编码）
- ✅ **数据清理**：自动清理 30 天前的数据，收藏的永不删除
- ✅ **触发器同步**：FTS5 虚拟表与主表自动同步

## 使用方法

### 1. 初始化数据库

```autohotkey
#Include modules\ClipboardFTS5.ahk

; 在主脚本初始化时调用
if (!InitClipboardFTS5DB()) {
    MsgBox("数据库初始化失败")
    ExitApp
}
```

### 2. 采集剪贴板内容

```autohotkey
; 文本采集
CaptureClipboardTextToFTS5("chrome.exe")

; 图片采集
CaptureClipboardImageToFTS5("chrome.exe")

; 智能采集（自动判断文本或图片）
CaptureClipboardToFTS5()
```

### 3. 全文搜索

```autohotkey
; 搜索关键词
results := SearchClipboardFTS5("关键词", 100)

; 遍历结果
for index, row in results {
    MsgBox("ID: " . row["ID"] . "`n内容: " . row["Content"])
}
```

### 4. 数据清理

```autohotkey
; 清理 30 天前的数据（收藏的保留）
deletedCount := CleanupClipboardFTS5(30)
MsgBox("已删除 " . deletedCount . " 条记录")
```

### 5. 收藏管理

```autohotkey
; 标记为收藏
MarkAsFavorite(123)

; 取消收藏
UnmarkAsFavorite(123)
```

## 数据库结构

### ClipMain 主表

| 字段名 | 类型 | 说明 |
|--------|------|------|
| ID | INTEGER PRIMARY KEY | 自增主键 |
| Content | TEXT | 文本内容或图片路径 |
| SourceApp | TEXT | 来源进程名 |
| DataType | TEXT | 类型：Text/Code/Link/Email/Image |
| CharCount | INTEGER | 字符数 |
| Timestamp | DATETIME | 时间戳 |
| ImagePath | TEXT | 图片文件路径 |
| ThumbnailData | BLOB | 缩略图 Base64 数据 |
| IsFavorite | INTEGER | 是否收藏（0/1） |

### ClipFTS 虚拟表（FTS5）

FTS5 虚拟表用于全文搜索，通过触发器与主表自动同步。

## API 参考

### InitClipboardFTS5DB()

初始化数据库，创建表结构和触发器。

**返回值**：`true` 成功，`false` 失败

---

### CaptureClipboardToFTS5()

智能采集剪贴板内容（自动判断文本或图片）。

**返回值**：`true` 成功，`false` 失败

---

### CaptureClipboardTextToFTS5(SourceApp)

采集文本到数据库。

**参数**：
- `SourceApp` (String)：来源进程名

**返回值**：`true` 成功，`false` 失败

---

### CaptureClipboardImageToFTS5(SourceApp)

采集图片到数据库。

**参数**：
- `SourceApp` (String)：来源进程名

**返回值**：`true` 成功，`false` 失败

**说明**：
- 图片保存到 `Cache\Images\` 目录
- 自动生成 64x64 JPG 缩略图
- 缩略图以 Base64 编码存储在数据库

---

### SearchClipboardFTS5(keyword, limit := 100)

使用 FTS5 进行全文搜索。

**参数**：
- `keyword` (String)：搜索关键词
- `limit` (Integer)：返回结果数量限制，默认 100

**返回值**：数组，每个元素是一个 Map，包含 ID、Content、SourceApp、DataType、CharCount、Timestamp、ImagePath、IsFavorite

---

### CleanupClipboardFTS5(keepDays := 30)

清理数据库，删除指定天数前的数据。

**参数**：
- `keepDays` (Integer)：保留天数，默认 30

**返回值**：删除的记录数

**说明**：
- 标记为收藏（IsFavorite = 1）的记录永不删除

---

### MarkAsFavorite(id)

标记记录为收藏。

**参数**：
- `id` (Integer)：记录 ID

**返回值**：`true` 成功，`false` 失败

---

### UnmarkAsFavorite(id)

取消收藏标记。

**参数**：
- `id` (Integer)：记录 ID

**返回值**：`true` 成功，`false` 失败

---

## 内容分类规则

### Text（普通文本）
默认类型，不符合其他规则的文本。

### Link（链接）
匹配正则：`^(https?://|www\.|ftp://)[^\s]+$`

### Email（邮箱）
匹配正则：`^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$`

### Code（代码）
包含以下特征之一：
- 代码符号：`{}[]();`
- 操作符：`=>`, `:=`
- 关键字：`function`, `const`, `import`, `class`, `def`, `return`, `var`, `let`, `public`, `private`, `namespace`, `using`, `#include`, `<?php`, `<?xml`, `<!DOCTYPE`

### Image（图片）
从剪贴板采集的图片。

## 注意事项

1. **SQLite 版本要求**：需要 SQLite 3.9.0 或更高版本（支持 FTS5）
2. **GDI+ 初始化**：确保在使用前已初始化 GDI+（通常在主脚本中调用 `Gdip_Startup()`）
3. **文件路径**：
   - 数据库文件：`Clipboard.db`（脚本目录）
   - 图片缓存：`Cache\Images\`（脚本目录）
4. **性能优化**：
   - WAL 模式提升并发性能
   - 索引优化查询速度
   - FTS5 虚拟表提供高效的全文搜索

## 示例：完整的剪贴板监听

```autohotkey
#Include modules\ClipboardFTS5.ahk

; 初始化
if (!InitClipboardFTS5DB()) {
    ExitApp
}

; 监听剪贴板变化（示例）
OnClipboardChange(ClipChanged)
ClipChanged(Type) {
    if (Type = 1) {  ; 文本
        CaptureClipboardTextToFTS5(WinGetProcessName("A"))
    } else if (Type = 2) {  ; 图片
        CaptureClipboardImageToFTS5(WinGetProcessName("A"))
    }
}
```

## 许可证

本模块遵循项目主许可证。
