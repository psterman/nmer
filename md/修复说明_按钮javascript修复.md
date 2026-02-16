# 按钮 javascript:; 修复说明

## 问题描述
- Google 搜索按钮没有反应
- 复制按钮没有反应
- 四个导出按钮（导出 MD、JSON、TXT、HTML）都显示为 `javascript:;`，无法点击

## 问题原因
按钮的 `href` 属性被错误地设置为 `javascript:;`，或者 `onclick` 事件处理器没有正确设置。

## 解决方案

### 方案 1: 修复 href 属性
如果按钮使用 `<a>` 标签，需要将 `href="javascript:;"` 改为：
- 对于导出按钮：`href="javascript:void(0);" onclick="ExportData('md')"` （或其他格式）
- 对于 Google 搜索按钮：`href="javascript:void(0);" onclick="SearchGoogle()"` （或其他格式）
- 对于复制按钮：`href="javascript:void(0);" onclick="CopyContent()"` （或其他格式）

### 方案 2: 使用按钮标签
将 `<a>` 标签改为 `<button>` 标签，并使用 `onclick` 事件：

```html
<!-- 导出按钮示例 -->
<button onclick="ExportData('md')">导出 MD</button>
<button onclick="ExportData('json')">导出 JSON</button>
<button onclick="ExportData('txt')">导出 TXT</button>
<button onclick="ExportData('html')">导出 HTML</button>

<!-- Google 搜索按钮示例 -->
<button onclick="SearchGoogle()">Google 搜索</button>

<!-- 复制按钮示例 -->
<button onclick="CopyContent()">复制</button>
```

### 方案 3: 使用 WebView postMessage（如果使用 WebView）
如果这些按钮在 WebView 中，需要通过 `postMessage` 与 AHK 通信：

```javascript
// HTML 中
function ExportData(format) {
    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage({
            action: "EXPORT",
            format: format
        });
    }
}

function SearchGoogle() {
    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage({
            action: "SEARCH_GOOGLE"
        });
    }
}

function CopyContent() {
    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage({
            action: "COPY"
        });
    }
}
```

## 需要找到的代码位置
请提供以下信息以便精确定位：
1. 这些按钮在哪个界面/窗口中？
2. 相关的函数名或文件路径
3. 是否有错误日志或行号信息

## 临时解决方案
如果无法立即找到代码位置，可以：
1. 在浏览器中打开开发者工具（F12）
2. 查看按钮的 HTML 结构
3. 临时修改 `href` 或 `onclick` 属性进行测试
4. 找到正确的代码位置后，进行永久修复
