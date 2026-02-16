# 修复方案：六个按钮（复制、Google、MD、TXT、JSON、CSV）失效问题

## 问题描述
在 `抠搜1.ahk` 中，每个选项后都设计了六个按钮（复制、Google、MD、TXT、JSON、CSV），但是六个按钮功能都失效了，显示为 `javascript:;`。

## 问题原因
按钮的 `href` 属性被错误地设置为 `javascript:;`，或者 `onclick` 事件处理器没有正确设置。

## 解决方案

### 步骤 1: 找到生成按钮的代码位置

这些按钮可能在以下位置之一：
1. 在 ListView 的自定义渲染中
2. 在某个 HTML 生成函数中
3. 在某个使用 WebView 的窗口中
4. 在某个字符串拼接生成 HTML 的代码中

### 步骤 2: 修复按钮的 href 和 onclick 属性

如果按钮使用 `<a>` 标签，需要将 `href="javascript:;"` 改为正确的格式：

```html
<!-- 修复前（错误）-->
<a href="javascript:;">复制</a>
<a href="javascript:;">Google</a>
<a href="javascript:;">MD</a>
<a href="javascript:;">TXT</a>
<a href="javascript:;">JSON</a>
<a href="javascript:;">CSV</a>

<!-- 修复后（正确）-->
<a href="javascript:void(0);" onclick="HandleCopyClick(this)" data-id="1">复制</a>
<a href="javascript:void(0);" onclick="HandleGoogleClick(this)" data-id="1">Google</a>
<a href="javascript:void(0);" onclick="HandleExportClick(this, 'md')" data-id="1">MD</a>
<a href="javascript:void(0);" onclick="HandleExportClick(this, 'txt')" data-id="1">TXT</a>
<a href="javascript:void(0);" onclick="HandleExportClick(this, 'json')" data-id="1">JSON</a>
<a href="javascript:void(0);" onclick="HandleExportClick(this, 'csv')" data-id="1">CSV</a>
```

### 步骤 3: 实现 JavaScript 处理函数

如果使用 WebView，需要在 HTML 中添加 JavaScript 函数：

```javascript
// 复制按钮处理函数
function HandleCopyClick(button) {
    const itemId = button.getAttribute('data-id');
    const content = GetItemContent(itemId); // 获取选项内容
    
    // 复制到剪贴板
    if (navigator.clipboard) {
        navigator.clipboard.writeText(content).then(() => {
            alert('已复制到剪贴板');
        });
    } else {
        // 兼容旧浏览器
        const textArea = document.createElement('textarea');
        textArea.value = content;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        alert('已复制到剪贴板');
    }
    
    // 如果使用 WebView，发送消息到 AHK
    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage({
            action: 'COPY',
            itemId: itemId,
            content: content
        });
    }
}

// Google 搜索按钮处理函数
function HandleGoogleClick(button) {
    const itemId = button.getAttribute('data-id');
    const content = GetItemContent(itemId);
    const searchUrl = 'https://www.google.com/search?q=' + encodeURIComponent(content);
    
    // 打开 Google 搜索
    window.open(searchUrl, '_blank');
    
    // 如果使用 WebView，发送消息到 AHK
    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage({
            action: 'SEARCH_GOOGLE',
            itemId: itemId,
            content: content
        });
    }
}

// 导出按钮处理函数
function HandleExportClick(button, format) {
    const itemId = button.getAttribute('data-id');
    const content = GetItemContent(itemId);
    
    // 如果使用 WebView，发送消息到 AHK
    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage({
            action: 'EXPORT',
            format: format, // 'md', 'txt', 'json', 'csv'
            itemId: itemId,
            content: content
        });
    } else {
        // 直接在浏览器中下载
        DownloadContent(content, format);
    }
}

// 获取选项内容的辅助函数
function GetItemContent(itemId) {
    // 根据实际情况实现，可能从 DOM 元素或数据对象中获取
    const itemElement = document.querySelector(`[data-item-id="${itemId}"]`);
    return itemElement ? itemElement.textContent : '';
}

// 下载内容的辅助函数
function DownloadContent(content, format) {
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `export_${Date.now()}.${format}`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}
```

### 步骤 4: 在 AHK 中处理 WebView 消息（如果使用 WebView）

如果使用 WebView，需要在 AHK 中处理消息：

```autohotkey
; ===================== 处理 WebView 消息 =====================
HandleWebViewMessage(Message) {
    global ClipboardDB, ClipboardHistory
    
    try {
        action := Message.Has("action") ? Message["action"] : ""
        itemId := Message.Has("itemId") ? Message["itemId"] : ""
        content := Message.Has("content") ? Message["content"] : ""
        format := Message.Has("format") ? Message["format"] : ""
        
        Switch action {
            case "COPY":
                ; 复制到剪贴板
                A_Clipboard := content
                TrayTip("已复制到剪贴板", "提示", "Iconi 1")
                
            case "SEARCH_GOOGLE":
                ; 打开 Google 搜索
                searchUrl := "https://www.google.com/search?q=" . UriEncode(content)
                Run(searchUrl)
                
            case "EXPORT":
                ; 导出内容
                ExportData(format, content, itemId)
        }
    } catch as err {
        TrayTip("处理消息失败: " . err.Message, "错误", "Iconx 2")
    }
}

; ===================== 导出数据 =====================
ExportData(format, content, itemId := "") {
    try {
        ; 选择保存位置
        defaultFileName := "export_" . A_Now . "." . format
        filePath := FileSelect("S16", A_ScriptDir, "保存文件", format . " 文件 (*." . format . ")")
        
        if (filePath = "") {
            return
        }
        
        ; 确保文件扩展名正确
        if (!InStr(filePath, "." . format)) {
            filePath .= "." . format
        }
        
        ; 根据格式处理内容
        Switch format {
            case "md":
                ; Markdown 格式
                output := content
                
            case "txt":
                ; 纯文本格式
                output := content
                
            case "json":
                ; JSON 格式
                jsonObj := Map("id", itemId, "content", content, "timestamp", FormatTime(, "yyyy-MM-dd HH:mm:ss"))
                output := JSONStringify(jsonObj)
                
            case "csv":
                ; CSV 格式
                output := '"ID","Content","Timestamp"' . "`n"
                output .= '"' . itemId . '","' . StrReplace(content, '"', '""') . '","' . FormatTime(, "yyyy-MM-dd HH:mm:ss") . '"'
        }
        
        ; 保存文件
        FileDelete(filePath)
        FileAppend(output, filePath, "UTF-8")
        TrayTip("导出成功", "文件已保存到: " . filePath, "Iconi 1")
        
    } catch as err {
        TrayTip("导出失败: " . err.Message, "错误", "Iconx 2")
    }
}
```

## 需要定位的代码位置

请检查以下位置，找到生成这些按钮的代码：

1. **搜索包含这些按钮文本的代码**：
   ```autohotkey
   ; 在 CursorHelper (1).ahk 中搜索：
   ; - "复制" 和 "Google" 和 "MD" 和 "TXT" 和 "JSON" 和 "CSV"
   ; - "href" 或 "onclick"
   ; - "javascript:;"
   ```

2. **检查可能的 HTML 生成函数**：
   - 可能在某处有生成 HTML 字符串的代码
   - 可能使用字符串拼接生成 HTML
   - 可能在 ListView 的自定义渲染中

3. **检查 WebView 相关代码**：
   - 如果使用 WebView，检查 WebView 的 HTML 内容生成
   - 检查 WebView 的消息处理函数

## 临时解决方案

如果需要立即修复，可以：

1. **在浏览器开发者工具中临时修复**：
   - 打开浏览器开发者工具（F12）
   - 找到这些按钮的 HTML 元素
   - 临时修改 `href` 或 `onclick` 属性进行测试
   - 确认功能正常后，在代码中进行永久修复

2. **使用 AutoHotkey 的 Gui 控件替代 HTML 按钮**：
   - 如果这些按钮在 ListView 中，可以考虑使用原生的 AHK 控件
   - 或者使用右键菜单来实现这些功能

## 注意事项

1. **确保按钮有正确的 data-id 属性**：用于标识对应的选项
2. **确保能获取到选项内容**：按钮需要知道要处理的内容
3. **处理错误情况**：如果内容为空或获取失败，应该给出提示
4. **安全性**：如果导出内容包含用户输入，需要进行适当的转义

## 下一步

请提供以下信息，以便精确定位和修复：

1. 这些按钮在哪个界面/窗口中？
2. 这些按钮是通过什么方式生成的？（HTML、ListView 自定义渲染等）
3. 相关的代码文件路径或函数名
4. 是否有错误日志或行号信息
