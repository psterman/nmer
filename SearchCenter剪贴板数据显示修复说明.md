# SearchCenter 剪贴板数据显示修复说明

## 📋 问题描述

用户反馈 SearchCenter 的 ListView 没有匹配剪贴板的数据，只显示标题、来源和时间两个标签。需要汇总展示剪贴板 ClipMain 的新增数据，并配上对应的标签。

## 🔧 修复内容

### 1. 修复 Source 字段传递问题

**问题**：SearchClipboardFTS5ForSearchCenter 函数返回的 ResultItem 对象缺少 Source 字段，导致 ListView 无法正确显示来源标签。

**修复**：
- 在 `SearchClipboardFTS5ForSearchCenter()` 函数中添加 `Source` 字段
- 在 `DebouncedSearchCenter()` 函数中优先使用 `Item.Source` 字段

```ahk
; SearchClipboardFTS5ForSearchCenter 函数中
ResultItem := {
    DataType: "clipboard",
    DataTypeName: DataTypeDisplayName,
    Source: DataTypeDisplayName,  ; 【新增】添加 Source 字段
    Title: DisplayTitle,
    Time: TimeFormatted,
    Content: Content,
    // ...
}

; DebouncedSearchCenter 函数中
SourceText := ""
if (Item.HasProp("Source") && Item.Source != "") {
    SourceText := Item.Source  ; 【修复】优先使用 Item.Source
} else if (Item.HasProp("DataTypeName") && Item.DataTypeName != "") {
    SourceText := Item.DataTypeName
} else {
    SourceText := TypeData.HasProp("DataTypeName") ? TypeData.DataTypeName : DataType
}
```

### 2. 添加无关键词时显示最新数据功能

**新增功能**：当用户没有输入搜索关键词时，自动显示最新的剪贴板数据（汇总展示）。

**实现逻辑**：
1. 检测关键词为空
2. 查询 ClipMain 表的最新数据（最多 50 条）
3. 按时间倒序排列（最新的在前）
4. 显示在 ListView 中，包含标题、来源、时间三列

```ahk
if (StrLen(Keyword) < 1) {
    ; 显示最新的剪贴板数据
    SQL := "SELECT ID, Content, SourceApp, DataType, CharCount, Timestamp, LastCopyTime 
            FROM ClipMain 
            ORDER BY LastCopyTime DESC 
            LIMIT 50"
    
    ; 遍历结果，构建显示项
    for each row in results {
        Results.Push({
            Title: "📝 [文本] 内容预览...",
            Source: "文本",  // 或 "代码片段"、"链接"、"图片"等
            Time: "2026-01-06 12:00:00",
            Content: "完整内容",
            // ...
        })
    }
    
    ; 更新 ListView
    SearchCenterResultLV.Add(, Item.Title, Item.Source, Item.Time)
}
```

## 📊 数据显示格式

### ListView 列结构

| 列序号 | 列名 | 内容 | 示例 |
|--------|------|------|------|
| 1 | 标题 | 带 Emoji 前缀的内容预览 | `📝 [文本] 这是内容预览...` |
| 2 | 来源 | 数据类型标签 | `文本`、`代码片段`、`链接`、`图片`、`颜色`、`邮箱` |
| 3 | 时间 | 最后复制时间 | `2026-01-06 12:00:00` |

### 数据类型标签映射

| DataType | 显示标签 | Emoji 前缀 |
|----------|----------|------------|
| Text | 文本 | 📝 |
| Code | 代码片段 | 💻 |
| Link | 链接 | 🔗 |
| Image | 图片 | 🖼️ |
| Color | 颜色 | 🎨 |
| Email | 邮箱 | 📧 |

## 🎯 功能特点

### 1. 即时匹配

- ✅ **有关键词时**：搜索匹配的剪贴板数据
- ✅ **无关键词时**：显示最新的 50 条剪贴板数据
- ✅ **实时更新**：按时间倒序排列，最新数据在前

### 2. 标签显示

- ✅ **来源标签**：显示数据类型（文本、代码片段、链接等）
- ✅ **时间标签**：显示最后复制时间
- ✅ **标题标签**：显示带 Emoji 前缀的内容预览

### 3. 数据汇总

- ✅ **汇总展示**：无关键词时汇总显示最新数据
- ✅ **分类标签**：根据数据类型显示对应标签
- ✅ **最新优先**：按 LastCopyTime 倒序排列

## 🔄 使用流程

### 场景 1：有搜索关键词

1. 用户在输入框输入关键词（如 "1"）
2. 150ms 防抖后触发搜索
3. 查询 ClipMain 表，匹配 Content 和 SourceApp 字段
4. 显示匹配结果，包含标题、来源、时间

### 场景 2：无搜索关键词（新增）

1. 用户打开 SearchCenter（输入框为空）
2. 自动查询 ClipMain 表的最新数据
3. 显示最新的 50 条数据
4. 每条数据包含：
   - **标题**：带 Emoji 前缀的内容预览
   - **来源**：数据类型标签（文本、代码片段等）
   - **时间**：最后复制时间

## 📝 代码修改位置

### 1. SearchClipboardFTS5ForSearchCenter 函数

**文件**：`CursorHelper (1).ahk`  
**位置**：约第 11544 行  
**修改**：添加 `Source` 字段

```ahk
ResultItem := {
    Source: DataTypeDisplayName,  // 新增
    // ...
}
```

### 2. DebouncedSearchCenter 函数

**文件**：`CursorHelper (1).ahk`  
**位置**：约第 21697 行  
**修改**：
1. 修复 Source 字段优先级
2. 添加无关键词时显示最新数据功能

## ✅ 修复完成状态

- ✅ 修复 Source 字段传递问题
- ✅ 添加无关键词时显示最新数据功能
- ✅ 确保标签正确显示（来源、时间）
- ✅ 按时间倒序排列最新数据
- ✅ 支持所有数据类型标签显示

## 🎉 效果展示

### 有搜索关键词时

```
标题: 📝 [文本] 这是包含"1"的内容...
来源: 文本
时间: 2026-01-06 12:00:00
```

### 无搜索关键词时（汇总展示）

```
标题: 📝 [文本] 最新复制的内容1...
来源: 文本
时间: 2026-01-06 12:00:00

标题: 💻 [代码] function test() {...
来源: 代码片段
时间: 2026-01-06 11:59:00

标题: 🔗 [链接] https://example.com...
来源: 链接
时间: 2026-01-06 11:58:00
```

现在 SearchCenter 的 ListView 可以正确显示剪贴板数据，包含标题、来源和时间三个标签，并且在没有搜索关键词时会自动汇总展示最新的剪贴板数据！
