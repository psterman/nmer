# Raycast clipboard database architecture
_Exported on 01/04/2026 at 23:26:26 GMT+8 from Cursor via WayLog_


**User**

# Role: AutoHotkey v2 & SQLite 专家

# Task: 剪贴板系统重构 - 第一步：建立 Raycast 级数据库架构


## 1. 完善目录自动化
在数据库连接逻辑之前，确保脚本会自动检测并创建数据存放目录：
- 检查 `A_ScriptDir "\Data"` 文件夹是否存在，若不存在则调用 `DirCreate` 创建。

## 2. 彻底重构表结构 (破坏性更新)
请找到 `InitClipboardDB` 函数（或负责创建表的逻辑），执行以下 SQL 指令。
注意：必须先执行 `DROP TABLE IF EXISTS ClipboardHistory;` 以清除旧的不兼容结构。

创建全新的 `ClipboardHistory` 表，包含以下 11 个关键字段：
1.  **ID**: INTEGER PRIMARY KEY AUTOINCREMENT
2.  **Timestamp**: DATETIME DEFAULT (datetime('now', 'localtime'))
3.  **Content**: TEXT (存储：纯文本、代码片段、或图片/文件的本地绝对路径)
4.  **DataType**: TEXT (分类标签：Text, Code, Image, File, Link, Email)
5.  **SourceApp**: TEXT (来源程序名，如 chrome.exe)
6.  **SourceTitle**: TEXT (来源窗口标题)
7.  **SourcePath**: TEXT (来源程序在磁盘的完整路径，用于图标提取)
8.  **CharCount**: INTEGER (字符总数)
9.  **WordCount**: INTEGER (文字/单词总数)
10. **MetaData**: TEXT (存储 JSON 格式的扩展信息，如 {"hasHTML": 1})
11. **IsPinned**: INTEGER DEFAULT 0 (用于收藏/置顶功能)

## 3. AHK v2 代码规范要求
- 确保 `ClipboardDB` 对象被声明为 `global`。
- 在 `ClipboardDB.OpenDB` 失败或 `Exec` 失败时，必须使用 `MsgBox` 弹出具体的错误信息 `ClipboardDB.ErrorMsg`，方便调试。
- 整个初始化过程需放在一个名为 `InitClipboardDB()` 的独立函数中。

## 4. 验证要求
代码修改完成后，请确保脚本启动时会自动生成 `\Data\Clipboard.db` 文件，且表中包含上述所有字段。

---


**Cursor**

查看现有数据库初始化代码。



查看主脚本中的数据库初始化逻辑，并检查其调用位置：



检查 `InitClipboardDB_Function.ahk`，并确认主脚本中的调用点。按需求重构数据库初始化函数：



按需求重构数据库初始化函数：创建新的 `InitClipboardDB()`，替换现有的 `InitSQLiteDB()`。



验证修改并检查是否有遗漏的地方：



检查函数调用处是否正确更新：



验证修改是否完整，检查是否有语法错误：



重构完成。修改摘要：

## 完成的修改

### 1. **目录自动化**
- 在 `InitClipboardDB()` 函数开始时检查 `A_ScriptDir "\Data"` 目录
- 不存在时使用 `DirCreate()` 创建
- 添加了异常处理，创建失败时显示错误消息

### 2. **数据库路径更新**
- 全局变量 `ClipboardDBPath` 从 `A_ScriptDir "\CursorData.db"` 更新为 `A_ScriptDir "\Data\Clipboard.db"`
- 函数内部也会设置该路径以保持一致

### 3. **表结构重构（破坏性更新）**
- 执行 `DROP TABLE IF EXISTS ClipboardHistory` 删除旧表
- 创建包含 11 个字段的新 `ClipboardHistory` 表：
  1. ID (INTEGER PRIMARY KEY AUTOINCREMENT)
  2. Timestamp (DATETIME DEFAULT datetime('now', 'localtime'))
  3. Content (TEXT)
  4. DataType (TEXT)
  5. SourceApp (TEXT)
  6. SourceTitle (TEXT)
  7. SourcePath (TEXT)
  8. CharCount (INTEGER)
  9. WordCount (INTEGER)
  10. MetaData (TEXT)
  11. IsPinned (INTEGER DEFAULT 0)

### 4. **错误处理**
- 所有错误情况使用 `MsgBox` 显示 `ClipboardDB.ErrorMsg`
- 包括：目录创建失败、sqlite3.dll 未找到、数据库打开失败、表创建失败、索引创建失败等

### 5. **函数命名和调用**
- 函数名从 `InitSQLiteDB()` 改为 `InitClipboardDB()`
- 更新了所有调用处（第 2596 行）

### 6. **性能优化**
- 为常用查询字段创建了索引（Timestamp, Content, DataType, SourceApp, IsPinned）

## 验证要求
脚本启动时会：
1. 自动创建 `\Data` 目录（如不存在）
2. 在 `\Data\Clipboard.db` 创建数据库文件
3. 删除旧表并创建包含 11 个字段的新表结构

所有错误都会通过 `MsgBox` 显示详细错误信息，便于调试。

代码已通过语法检查，无 linter 错误。可以运行脚本测试数据库初始化功能。

---


**User**

# 强制执行第一步：重构数据库架构

请对 `CursorHelper (1).ahk` 进行以下修改，替换旧的数据库初始化部分：

1. **自动创建目录**：在初始化前添加 `if !DirExist(A_ScriptDir "\Data") { DirCreate(A_ScriptDir "\Data") }`。
2. **彻底重写建表 SQL**：执行 `DROP TABLE IF EXISTS ClipboardHistory;` 以清除旧结构。
创建全新的 `ClipboardHistory` 表，包含以下 11 个关键字段：
1.  **ID**: INTEGER PRIMARY KEY AUTOINCREMENT
2.  **Timestamp**: DATETIME DEFAULT (datetime('now', 'localtime'))
3.  **Content**: TEXT (存储：纯文本、代码片段、或图片/文件的本地绝对路径)
4.  **DataType**: TEXT (分类标签：Text, Code, Image, File, Link, Email)
5.  **SourceApp**: TEXT (来源程序名，如 chrome.exe)
6.  **SourceTitle**: TEXT (来源窗口标题)
7.  **SourcePath**: TEXT (来源程序在磁盘的完整路径，用于图标提取)
8.  **CharCount**: INTEGER (字符总数)
9.  **WordCount**: INTEGER (文字/单词总数)
10. **MetaData**: TEXT (存储 JSON 格式的扩展信息，如 {"hasHTML": 1})
11. **IsPinned**: INTEGER DEFAULT 0 (用于收藏/置顶功能)
3. **建立新表字段**：创建包含 ID, Timestamp, Content, DataType, SourceApp, SourceTitle, SourcePath, CharCount, WordCount, MetaData, IsPinned 的完整表。
4. **验证成功**：确保 `global ClipboardDB` 被正确初始化，若失败则通过 `MsgBox` 报错

---


**Cursor**

检查当前的数据库初始化代码，确保符合所有要求：



按你的要求进行最后调整：简化目录创建逻辑，确保字段顺序正确，并添加成功验证：



更新后续步骤的编号注释：



验证表结构是否完整：



重构完成。所有要求已实现：

## 完成的修改总结

### 1. **自动创建目录**
```autohotkey
if !DirExist(A_ScriptDir "\Data") {
    DirCreate(A_ScriptDir "\Data")
}
```

### 2. **彻底重写建表 SQL**
- 执行 `DROP TABLE IF EXISTS ClipboardHistory;` 清除旧结构
- 创建包含 11 个字段的新表

### 3. **完整的 11 个字段**
表结构已创建，包含：
1. **ID**: INTEGER PRIMARY KEY AUTOINCREMENT
2. **Timestamp**: DATETIME DEFAULT (datetime('now', 'localtime'))
3. **Content**: TEXT
4. **DataType**: TEXT
5. **SourceApp**: TEXT
6. **SourceTitle**: TEXT
7. **SourcePath**: TEXT
8. **CharCount**: INTEGER
9. **WordCount**: INTEGER
10. **MetaData**: TEXT
11. **IsPinned**: INTEGER DEFAULT 0

### 4. **验证成功机制**
```autohotkey
; 6. 验证成功：确认 global ClipboardDB 已正确初始化
if (!IsObject(ClipboardDB) || ClipboardDB = 0) {
    MsgBox("数据库初始化失败：ClipboardDB 对象未正确创建", "数据库初始化错误", "IconX")
    ClipboardDB := 0
    return
}
```

### 5. **错误处理**
所有关键步骤都使用 `MsgBox` 显示 `ClipboardDB.ErrorMsg`，包括：
- sqlite3.dll 未找到
- 数据库打开失败
- 删除旧表失败
- 创建新表失败
- ClipboardDB 对象验证失败

## 验证结果
- 代码无语法错误（linter 检查通过）
- 所有字段顺序和定义正确
- 数据库路径：`A_ScriptDir "\Data\Clipboard.db"`
- 函数名：`InitClipboardDB()`

脚本启动时会自动创建 `\Data` 目录，删除旧表，创建包含 11 个字段的新表结构，并验证 `ClipboardDB` 对象是否正确初始化。

---


**User**

# Role: AutoHotkey v2 & SQLite 专家

# Task: 强制执行第一步 - 数据库物理架构重写

请在 `CursorHelper (1).ahk` 中找到数据库初始化部分，并彻底替换为以下逻辑。我们需要能够存储深度元数据的表结构。

1. **自动创建目录**：确保在脚本目录下自动创建 `Data` 文件夹。
2. **重写建表逻辑**：
   - 执行 `DROP TABLE IF EXISTS ClipboardHistory;` 以彻底清除旧结构。
   - 执行以下 SQL 创建新表：
     CREATE TABLE ClipboardHistory (
         ID INTEGER PRIMARY KEY AUTOINCREMENT,
         Timestamp DATETIME DEFAULT (datetime('now', 'localtime')),
         Content TEXT,                -- 文本、代码或本地文件路径
         DataType TEXT,               -- 分类: Text, Code, Link, Image, File, Email
         SourceApp TEXT,              -- 程序名 (chrome.exe)
         SourceTitle TEXT,            -- 窗口标题
         SourcePath TEXT,             -- 程序完整路径 (用于提取图标)
         CharCount INTEGER,           -- 字符数
         WordCount INTEGER,           -- 词数
         MetaData TEXT,               -- JSON 格式扩展数据
         IsPinned INTEGER DEFAULT 0   -- 收藏/置顶
     );
3. **全局对象规范**：确保 `global ClipboardDB` 被正确初始化，若失败则通过 `MsgBox` 报错提示 `ClipboardDB.ErrorMsg`。

---


**Cursor**

检查当前的数据库初始化代码，确保完全符合要求：



按你提供的格式重写 SQL 语句，确保完全匹配：



修正 SQL 语句格式，确保清晰且符合要求：



修正 SQL 语句格式：



查看当前 SQL 语句的实际内容：



验证全局对象规范的错误处理：



查看完整的验证部分：



修正验证逻辑：若 ClipboardDB 未初始化，不应访问其属性。



再次修正验证逻辑：



验证已完成。检查整个函数确保符合所有要求：



## 第一步完成：数据库物理架构重写

### 1. 自动创建目录
```autohotkey
; 1. 自动创建目录
if !DirExist(A_ScriptDir "\Data") {
    DirCreate(A_ScriptDir "\Data")
}
```
在脚本目录下自动创建 `Data` 文件夹。

### 2. 重写建表逻辑
- 执行 `DROP TABLE IF EXISTS ClipboardHistory;` 清除旧结构
- 创建包含 11 个字段的新表，支持深度元数据：

| 字段 | 类型 | 说明 |
|------|------|------|
| ID | INTEGER PRIMARY KEY AUTOINCREMENT | 主键 |
| Timestamp | DATETIME DEFAULT (datetime('now', 'localtime')) | 时间戳 |
| Content | TEXT | 文本、代码或本地文件路径 |
| DataType | TEXT | 分类: Text, Code, Link, Image, File, Email |
| SourceApp | TEXT | 程序名 (chrome.exe) |
| SourceTitle | TEXT | 窗口标题 |
| SourcePath | TEXT | 程序完整路径 (用于提取图标) |
| CharCount | INTEGER | 字符数 |
| WordCount | INTEGER | 词数 |
| MetaData | TEXT | JSON 格式扩展数据 |
| IsPinned | INTEGER DEFAULT 0 | 收藏/置顶 |

### 3. 全局对象规范
- `global ClipboardDB` 已正确声明
- 验证：创建表后检查 `ClipboardDB` 是否初始化
- 错误处理：所有失败情况通过 `MsgBox` 显示 `ClipboardDB.ErrorMsg`

### 关键代码片段
```autohotkey
; 4. 重写建表逻辑：彻底清除旧结构
SQL := "DROP TABLE IF EXISTS ClipboardHistory;"

; 5. 创建全新的 ClipboardHistory 表（包含11个关键字段，支持深度元数据）
SQL := "CREATE TABLE ClipboardHistory (" .
       "ID INTEGER PRIMARY KEY AUTOINCREMENT, " .
       "Timestamp DATETIME DEFAULT (datetime('now', 'localtime')), " .
       "Content TEXT, " .
       "DataType TEXT, " .
       "SourceApp TEXT, " .
       "SourceTitle TEXT, " .
       "SourcePath TEXT, " .
       "CharCount INTEGER, " .
       "WordCount INTEGER, " .
       "MetaData TEXT, " .
       "IsPinned INTEGER DEFAULT 0)"

; 6. 全局对象规范：验证 ClipboardDB 已正确初始化
if (!IsObject(ClipboardDB) || ClipboardDB = 0) {
    ErrorMsg := "ClipboardDB 对象未正确创建"
    if (IsObject(ClipboardDB) && ClipboardDB.HasProp("ErrorMsg")) {
        ErrorMsg .= "`n错误: " . ClipboardDB.ErrorMsg
    }
    MsgBox("数据库初始化失败：" . ErrorMsg, "数据库初始化错误", "IconX")
    ClipboardDB := 0
    return
}
```

### 验证结果
- 无语法错误（linter 检查通过）
- 所有 11 个字段正确定义
- 数据库路径：`A_ScriptDir "\Data\Clipboard.db"`
- 错误处理完整，所有失败情况都会显示详细错误信息

数据库物理架构重写完成。脚本启动时会自动创建目录、清除旧表，并创建包含 11 个字段的新表结构。

---
