# 修复说明：ExportData return 语法错误

## 错误信息
```
Error: The following reserved word must not be used as a variable name: "return"

	842: If (raw = "EXPORT_MD")
	842: {
▶	843: ExportData("md"), return
```

## 问题原因

在 AutoHotkey v2 中，`return` 是保留字，不能与逗号在同一行使用。以下写法是错误的：

```autohotkey
; ❌ 错误写法
ExportData("md"), return
```

## 修复方法

将 `return` 放在单独一行：

```autohotkey
; ✅ 正确写法
If (raw = "EXPORT_MD")
{
    ExportData("md")
    return
}
```

## AutoHotkey v2 语法规则

1. **`return` 必须单独一行**：不能与逗号或其他语句在同一行
2. **不能将 `return` 作为变量名**：`return` 是保留字
3. **正确的使用方式**：
   ```autohotkey
   ; 正确：return 单独一行
   MyFunction()
   return
   
   ; 错误：return 与逗号在同一行
   MyFunction(), return
   
   ; 错误：return 后跟值在同一行（某些情况下）
   MyFunction(), return Value
   ```

## 查找和修复步骤

1. 在文件中搜索 `ExportData("md"), return`
2. 或者搜索包含 `), return` 的模式
3. 将找到的代码改为：
   ```autohotkey
   ExportData("md")
   return
   ```

## 类似错误检查

检查整个文件中是否还有其他类似的错误模式：
- `), return`
- `), Return`
- `), RETURN`

如果发现，都按照相同方式修复。
