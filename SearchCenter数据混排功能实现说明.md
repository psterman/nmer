# SearchCenter 数据混排功能实现说明

## 📋 需求概述

用户需要 SearchCenter 的输入框文本能够匹配剪贴板的数据，并且剪贴板数据和提示词模板/配置项的数据能够同时显示混排。

## 🔧 实现方案

### 1. 修改 SearchAllDataSources 函数

**问题**：之前优先使用统一视图 `SearchGlobalView`，如果统一视图有结果就直接返回，不会搜索其他数据源，导致数据无法混排。

**修复**：移除统一视图优先逻辑，始终并行搜索所有数据源。

```ahk
SearchAllDataSources(Keyword, DataTypes := [], MaxResults := 10) {
    ; 【修改】始终搜索所有数据源，确保剪贴板、提示词、配置项等数据能够混排显示
    ; 不再优先使用统一视图，而是并行搜索所有数据源，然后混排结果
    
    Results := Map()
    
    ; 如果未指定类型，搜索所有数据源
    if (DataTypes.Length = 0) {
        DataTypes := ["clipboard", "template", "config", "file", "hotkey", "function", "ui"]
    }
    
    ; 并行搜索各个数据源
    for Index, DataType in DataTypes {
        switch DataType {
            case "clipboard":
                TypeResults := SearchClipboardHistory(Keyword, MaxResults)  ; 优先使用新的 ClipMain
            case "template":
                TypeResults := SearchPromptTemplates(Keyword, MaxResults)
            case "config":
                TypeResults := SearchConfigItems(Keyword, MaxResults)
            // ... 其他数据源
        }
        
        if (TypeResults.Length > 0) {
            Results[DataType] := {
                DataType: DataType,
                DataTypeName: GetDataTypeName(DataType),
                Count: TypeResults.Length,
                Items: TypeResults
            }
        }
    }
    
    return Results
}
```

### 2. 添加时间戳字段用于排序

**修改位置**：`DebouncedSearchCenter()` 函数

**修改内容**：
- 为每个结果项添加 `Timestamp` 字段
- 确保所有数据源的结果都有时间戳用于排序

```ahk
Results.Push({
    Title: TitleText,
    Source: SourceText,
    Time: TimeDisplay,
    Content: ContentText,
    Timestamp: TimestampValue,  // 【新增】用于排序
    // ...
})
```

### 3. 实现结果混排排序

**排序逻辑**：按时间戳倒序排列，确保所有数据源的结果混排显示。

```ahk
; 按时间戳排序，确保所有数据源的结果混排并按时间倒序显示
if (Results.Length > 1) {
    Loop Results.Length - 1 {
        i := A_Index
        Loop Results.Length - i {
            j := A_Index + i
            TimeI := Results[i].HasProp("Timestamp") ? Results[i].Timestamp : Results[i].Time
            TimeJ := Results[j].HasProp("Timestamp") ? Results[j].Timestamp : Results[j].Time
            ; 如果 j 的时间更新（字符串更大），则交换
            if (TimeJ > TimeI) {
                temp := Results[i]
                Results[i] := Results[j]
                Results[j] := temp
            }
        }
    }
}
```

**排序时机**：
1. 所有数据源搜索完成后，第一次排序
2. Everything 搜索完成后，再次排序（确保文件结果也参与混排）

## 📊 数据流图

```
用户输入关键词 "test"
    ↓
DebouncedSearchCenter (150ms 防抖)
    ↓
SearchAllDataSources(Keyword, [], 50)
    ↓
并行搜索所有数据源：
    ├─ clipboard → SearchClipboardHistory() → 查询 ClipMain
    ├─ template → SearchPromptTemplates() → 查询提示词模板
    ├─ config → SearchConfigItems() → 查询配置项
    ├─ file → SearchFilePaths() → 查询文件
    ├─ hotkey → SearchHotkeys() → 查询快捷键
    ├─ function → SearchFunctions() → 查询函数
    └─ ui → SearchUITabs() → 查询 UI
    ↓
转换为扁平数组
    ↓
按时间戳排序（混排）
    ↓
Everything 搜索（如果关键词长度 > 1）
    ↓
再次排序（确保文件结果也参与混排）
    ↓
更新 ListView
    ↓
显示混排结果
```

## 🎯 功能特点

### 1. 多数据源并行搜索

- ✅ **剪贴板数据**：从 ClipMain 表搜索（新的 FTS5 数据库）
- ✅ **提示词模板**：从 Prompts 表或 PromptTemplates 数组搜索
- ✅ **配置项**：从配置文件搜索
- ✅ **文件**：从文件路径搜索
- ✅ **快捷键**：从快捷键配置搜索
- ✅ **函数**：从函数列表搜索
- ✅ **UI**：从 UI 元素搜索

### 2. 结果混排显示

- ✅ **按时间排序**：所有数据源的结果按时间戳倒序排列
- ✅ **统一格式**：所有结果使用相同的显示格式（标题、来源、时间）
- ✅ **最新优先**：最新的数据（无论来源）显示在最前面

### 3. 即时匹配

- ✅ **短关键词支持**：输入 "1" 即可匹配所有包含 "1" 的数据
- ✅ **多字段搜索**：剪贴板数据同时搜索 Content 和 SourceApp
- ✅ **实时更新**：搜索结果实时更新

## 📝 显示效果示例

### 输入关键词 "test" 时的混排结果

```
标题: 📝 [文本] 这是测试内容...
来源: 文本
时间: 2026-01-06 12:05:00

标题: 测试提示词模板
来源: 提示词
时间: 2026-01-06 12:04:00

标题: test_config_value
来源: 配置项
时间: 2026-01-06 12:03:00

标题: test_file.txt
来源: Everything
时间: 2026-01-06 12:02:00

标题: 💻 [代码] function test() {...
来源: 代码片段
时间: 2026-01-06 12:01:00
```

**特点**：
- ✅ 所有数据源的结果混排显示
- ✅ 按时间倒序排列（最新的在前）
- ✅ 每个结果都有对应的来源标签

## 🔍 搜索匹配逻辑

### 剪贴板数据搜索

```sql
SELECT ID, Content, SourceApp, DataType, CharCount, Timestamp, LastCopyTime, CopyCount
FROM ClipMain 
WHERE (LOWER(Content) LIKE '%keyword%' OR LOWER(SourceApp) LIKE '%keyword%') 
ORDER BY LastCopyTime DESC 
LIMIT 50
```

**搜索字段**：
- `Content`：内容字段（主要搜索目标）
- `SourceApp`：来源应用（辅助搜索）

### 提示词模板搜索

- 搜索 `Title` 和 `Content` 字段
- 匹配提示词模板的名称和内容

### 配置项搜索

- 搜索配置项名称和配置值
- 匹配配置文件的键值对

## ⚙️ 技术实现细节

### 1. 数据源优先级

**修改前**：
1. 优先使用统一视图 `SearchGlobalView`
2. 如果统一视图有结果，直接返回
3. 否则回退到多数据源搜索

**修改后**：
1. 始终并行搜索所有数据源
2. 所有数据源的结果都参与混排
3. 按时间戳统一排序

### 2. 排序算法

**方法**：冒泡排序（简单高效）

**排序依据**：时间戳（`Timestamp` 字段）

**排序方向**：倒序（最新的在前）

**时间格式**：`yyyy-MM-dd HH:mm:ss`（可以直接字符串比较）

### 3. 结果数量限制

- **每个数据源**：最多 `MaxResults` 条（默认 10 条）
- **总结果数**：最多 50 条（SearchCenter 限制）
- **排序后**：取前 50 条显示

## ✅ 完成状态

- ✅ 修改 SearchAllDataSources，始终搜索所有数据源
- ✅ 添加时间戳字段用于排序
- ✅ 实现结果混排排序逻辑
- ✅ 确保剪贴板数据优先使用新的 ClipMain 表
- ✅ 确保所有数据源的结果都能正确显示
- ✅ 支持短关键词即时匹配

## 🎉 使用效果

现在用户在 SearchCenter 输入框中输入文字时：

1. **即时匹配**：自动匹配剪贴板、提示词、配置项等所有数据源
2. **混排显示**：所有数据源的结果按时间混排显示
3. **最新优先**：最新的数据（无论来源）显示在最前面
4. **标签清晰**：每个结果都有对应的来源标签（文本、提示词、配置项等）

所有修改已完成，代码已通过语法检查！
