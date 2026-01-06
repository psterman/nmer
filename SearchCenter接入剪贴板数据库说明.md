# SearchCenter 接入剪贴板数据库说明

## 📋 功能概述

已成功将 SearchCenter 的 ListView 接入新的剪贴板数据库（ClipMain），实现用户输入文字时自动即时匹配剪贴板的最新数据。

## 🔧 实现方案

### 1. 新增搜索函数

创建了 `SearchClipboardFTS5ForSearchCenter()` 函数，专门从新的剪贴板数据库（ClipMain）搜索数据：

```ahk
SearchClipboardFTS5ForSearchCenter(Keyword, MaxResults := 10)
```

**功能特点**：
- ✅ 直接查询 `ClipMain` 表（新的 FTS5 数据库）
- ✅ 支持短关键词即时匹配（使用 LIKE 查询）
- ✅ 同时搜索 `Content` 和 `SourceApp` 字段
- ✅ 按时间倒序排列（优先显示最新数据）
- ✅ 动态检查字段存在情况（兼容不同版本的数据库）
- ✅ 返回格式与 SearchCenter 兼容

### 2. 修改现有搜索函数

修改了 `SearchClipboardHistory()` 函数，使其优先使用新数据库：

```ahk
SearchClipboardHistory(Keyword, MaxResults := 10) {
    ; 【新增】优先使用新的剪贴板数据库（ClipMain）
    if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
        Results := SearchClipboardFTS5ForSearchCenter(Keyword, MaxResults)
        if (Results.Length > 0) {
            return Results
        }
    }
    
    ; 回退到旧数据库（ClipboardHistory）
    ; ...
}
```

**优先级策略**：
1. **优先**：使用新的 FTS5 数据库（ClipMain）
2. **回退**：如果新数据库不可用，使用旧数据库（ClipboardHistory）

## 🔍 搜索逻辑

### 查询策略

```sql
SELECT ID, Content, SourceApp, DataType, CharCount, Timestamp, 
       SourcePath, LastCopyTime, CopyCount
FROM ClipMain 
WHERE (LOWER(Content) LIKE ? OR LOWER(SourceApp) LIKE ?) 
ORDER BY LastCopyTime DESC 
LIMIT ?
```

**搜索字段**：
- `Content`：内容字段（主要搜索目标）
- `SourceApp`：来源应用（辅助搜索）

**排序方式**：
- 按 `LastCopyTime`（最后复制时间）倒序排列
- 如果没有 `LastCopyTime` 字段，使用 `Timestamp` 字段

### 即时匹配机制

- **使用 LIKE 查询**：支持短关键词（如 "1"）即时匹配
- **不区分大小写**：使用 `LOWER()` 函数
- **通配符匹配**：`%keyword%` 格式，匹配包含关键词的所有内容

## 📊 数据格式

### 返回结果结构

```ahk
ResultItem := {
    DataType: "clipboard",
    DataTypeName: "剪贴板历史",
    ID: ID,
    Title: "📝 [文本] 内容预览...",
    SubTitle: "来自: Cursor.exe | 字数: 100 · 2026-01-06 12:00:00",
    Content: "完整内容",
    Preview: "内容预览（前100字符）",
    Time: "2026-01-06 12:00:00",
    Timestamp: "2026-01-06 12:00:00",
    Metadata: Map(
        "SourceApp", "Cursor.exe",
        "SourcePath", "C:\...",
        "DataType", "Text",
        "CharCount", 100,
        "CopyCount", 1
    )
}
```

### 标题格式

根据数据类型添加 Emoji 前缀：
- 💻 [代码] - 代码片段
- 🔗 [链接] - 链接
- 📧 [邮件] - 邮箱
- 🖼️ [图片] - 图片
- 🎨 [颜色] - 颜色
- 📝 [文本] - 文本

## 🚀 使用流程

### 1. 用户输入

用户在 SearchCenter 的输入框中输入文字（如 "1"）

### 2. 触发搜索

- **防抖延迟**：150ms（`DebouncedSearchCenter`）
- **搜索函数**：`SearchAllDataSources(Keyword, [], 50)`
- **剪贴板搜索**：调用 `SearchClipboardHistory(Keyword, MaxResults)`

### 3. 数据查询

1. 检查 `ClipboardFTS5DB` 是否可用
2. 如果可用，调用 `SearchClipboardFTS5ForSearchCenter()`
3. 查询 `ClipMain` 表，匹配 `Content` 和 `SourceApp` 字段
4. 按时间倒序返回结果

### 4. 显示结果

- 结果添加到 `SearchCenterSearchResults` 缓存
- 更新 `SearchCenterResultLV` ListView
- 显示格式：`["标题", "来源", "时间"]`

## ✨ 功能特点

### 即时匹配

- ✅ **短关键词支持**：输入 "1" 即可匹配所有包含 "1" 的内容
- ✅ **实时更新**：显示最新的剪贴板数据（按时间倒序）
- ✅ **多字段搜索**：同时搜索内容和来源应用

### 性能优化

- ✅ **防抖机制**：150ms 延迟，避免频繁查询
- ✅ **结果限制**：最多返回 50 条结果（SearchCenter 限制）
- ✅ **动态字段检查**：兼容不同版本的数据库结构

### 兼容性

- ✅ **向后兼容**：如果新数据库不可用，自动回退到旧数据库
- ✅ **格式统一**：返回格式与 SearchCenter 其他数据源一致
- ✅ **字段兼容**：动态检查字段存在情况

## 🔄 数据流图

```
用户输入 "1"
    ↓
DebouncedSearchCenter (150ms 防抖)
    ↓
SearchAllDataSources(Keyword, [], 50)
    ↓
SearchClipboardHistory(Keyword, MaxResults)
    ↓
SearchClipboardFTS5ForSearchCenter(Keyword, MaxResults)
    ↓
查询 ClipMain 表
    WHERE (Content LIKE '%1%' OR SourceApp LIKE '%1%')
    ORDER BY LastCopyTime DESC
    LIMIT 50
    ↓
返回结果数组
    ↓
更新 SearchCenterResultLV ListView
    ↓
显示在 SearchCenter 窗口
```

## 📝 代码位置

### 新增函数
- **文件**：`CursorHelper (1).ahk`
- **位置**：约第 11542 行
- **函数名**：`SearchClipboardFTS5ForSearchCenter()`

### 修改函数
- **文件**：`CursorHelper (1).ahk`
- **位置**：约第 11543 行
- **函数名**：`SearchClipboardHistory()`

## 🎯 使用示例

### 测试步骤

1. **打开 SearchCenter**
   - 按 `CapsLock + F` 打开搜索中心

2. **输入搜索关键词**
   - 在输入框中输入 "1" 或其他关键词

3. **查看结果**
   - ListView 中会显示匹配的剪贴板数据
   - 结果按时间倒序排列（最新的在前）
   - 显示格式：`📝 [文本] 内容预览... | 来源: Cursor.exe | 时间`

4. **选择并执行**
   - 使用方向键选择结果
   - 按 Enter 或双击执行操作（复制到剪贴板）

## ⚠️ 注意事项

1. **数据库初始化**
   - 确保 `ClipboardFTS5DB` 已正确初始化
   - 如果未初始化，会自动回退到旧数据库

2. **字段兼容性**
   - 函数会自动检查字段是否存在
   - 如果字段不存在，使用默认值或替代字段

3. **性能考虑**
   - 搜索使用 LIKE 查询，对于大量数据可能较慢
   - 建议限制结果数量（当前最多 50 条）

4. **数据同步**
   - 新数据通过 `clipboard.ahk` 的监听器自动保存
   - 保存后立即可在 SearchCenter 中搜索到

## 🔮 未来优化建议

1. **FTS5 全文搜索**
   - 对于长关键词，可以使用 FTS5 MATCH 语法提升性能
   - 当前使用 LIKE 查询，适合短关键词即时匹配

2. **搜索优化**
   - 可以添加搜索高亮功能
   - 可以添加搜索历史记录

3. **结果排序**
   - 可以添加相关性排序（匹配度高的在前）
   - 可以添加使用频率排序

## ✅ 完成状态

- ✅ 新增 `SearchClipboardFTS5ForSearchCenter()` 函数
- ✅ 修改 `SearchClipboardHistory()` 函数，优先使用新数据库
- ✅ 支持短关键词即时匹配
- ✅ 按时间倒序显示最新数据
- ✅ 返回格式与 SearchCenter 兼容
- ✅ 向后兼容旧数据库

现在用户可以在 SearchCenter 中输入文字，自动即时匹配剪贴板的最新数据了！
