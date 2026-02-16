# SearchCenter HTML 标签栏状态管理解决方案

## 问题描述

在 HTML 版本的 SearchCenter 中，标签栏点击逻辑存在以下缺陷：
1. **样式固定**：HTML 中"全部"标签被硬编码了 `active` 类名
2. **缺少状态切换逻辑**：点击后前端没有更新 CSS 类，只通过 `postMessage` 通知 AHK
3. **单向通信**：只有"网页 -> AHK"，缺少"AHK -> 网页"的状态同步

## 解决方案

### 1. HTML 生成逻辑（AHK 端）

```autohotkey
; ===================== 生成 SearchCenter HTML（修复版）=====================
GenerateSearchCenterHTML(ActiveFilterType := "") {
    global SearchCenterFilterType
    
    ; 过滤标签配置
    FilterConfigs := [
        Map("Type", "", "Text", "全部"),
        Map("Type", "File", "Text", "文件"),
        Map("Type", "clipboard", "Text", "剪贴板"),
        Map("Type", "template", "Text", "提示词"),
        Map("Type", "config", "Text", "配置"),
        Map("Type", "hotkey", "Text", "快捷键"),
        Map("Type", "function", "Text", "功能")
    ]
    
    ; 生成标签栏 HTML（动态判断 active 类）
    FilterTagsHTML := ""
    for Index, FilterConfig in FilterConfigs {
        FilterType := FilterConfig["Type"]
        FilterText := FilterConfig["Text"]
        
        ; 【关键修复】根据当前状态动态设置 active 类，而不是硬编码
        IsActive := (ActiveFilterType = FilterType)
        ActiveClass := IsActive ? " active" : ""
        
        FilterTagsHTML .= Format('
        (
            <button class="filter-tag{1}" data-filter-type="{2}" onclick="handleFilterTagClick(this, ''{2}'')">
                {3}
            </button>
        )', ActiveClass, FilterType, FilterText)
    }
    
    HTML := Format('
    (
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>搜索中心</title>
        <style>
            .filter-tag {{
                padding: 8px 16px;
                margin: 0 4px;
                border: none;
                border-radius: 4px;
                background-color: #2d2d30;
                color: #eaeaea;
                cursor: pointer;
                font-size: 14px;
                font-weight: 500;
                transition: all 0.2s;
            }}
            .filter-tag:hover {{
                background-color: #3d3d40;
            }}
            .filter-tag.active {{
                background-color: #FF6600;
                color: #FFFFFF;
            }}
        </style>
    </head>
    <body>
        <div class="filter-bar">
            {1}
        </div>
        
        <script>
            // 【关键修复】前端状态管理：立即更新 CSS 类
            function handleFilterTagClick(element, filterType) {{
                // 1. 移除所有标签的 active 类
                document.querySelectorAll('.filter-tag').forEach(tag => {{
                    tag.classList.remove('active');
                }});
                
                // 2. 添加当前标签的 active 类
                element.classList.add('active');
                
                // 3. 通知 AHK 进行过滤（双向通信）
                if (window.chrome && window.chrome.webview) {{
                    window.chrome.webview.postMessage({{
                        action: 'filter',
                        filterType: filterType
                    }});
                }}
            }}
            
            // 【关键修复】接收 AHK 的状态更新（双向通信）
            if (window.chrome && window.chrome.webview) {{
                window.chrome.webview.addEventListener('message', (event) => {{
                    const message = event.data;
                    if (message.action === 'updateFilter') {{
                        // 移除所有 active 类
                        document.querySelectorAll('.filter-tag').forEach(tag => {{
                            tag.classList.remove('active');
                        }});
                        
                        // 根据 AHK 的状态设置 active 类
                        const activeTag = document.querySelector(`[data-filter-type="${{message.filterType}}"]`);
                        if (activeTag) {{
                            activeTag.classList.add('active');
                        }}
                    }}
                }});
            }}
        </script>
    </body>
    </html>
    )', FilterTagsHTML)
    
    return HTML
}
```

### 2. AHK 端消息处理（双向通信）

```autohotkey
; ===================== 处理 WebView 消息（修复版）=====================
HandleSearchCenterWebViewMessage(Message) {
    global SearchCenterFilterType, SearchCenterWebView
    
    if (!IsObject(Message) || !Message.HasProp("action")) {
        return
    }
    
    ; 处理过滤标签点击
    if (Message.action = "filter") {
        FilterType := Message.HasProp("filterType") ? Message.filterType : ""
        
        ; 更新过滤类型
        SearchCenterFilterType := FilterType
        
        ; 【关键修复】双向通信：通知网页更新状态（确保网页和 AHK 状态一致）
        UpdateWebViewFilterState(SearchCenterFilterType)
        
        ; 刷新搜索结果
        RefreshSearchCenterResults()
    }
}

; ===================== 更新 WebView 标签状态（双向通信）=====================
UpdateWebViewFilterState(FilterType) {
    global SearchCenterWebView
    
    if (!SearchCenterWebView || SearchCenterWebView = 0) {
        return
    }
    
    ; 【关键修复】向网页发送状态更新消息（AHK -> 网页）
    try {
        ; 构建 JavaScript 代码来更新标签状态
        JS := Format('
        (
            (function() {{
                // 移除所有 active 类
                document.querySelectorAll('.filter-tag').forEach(tag => {{
                    tag.classList.remove('active');
                }});
                
                // 设置当前标签为 active
                const activeTag = document.querySelector(`[data-filter-type="{}"]`);
                if (activeTag) {{
                    activeTag.classList.add('active');
                }}
            }})();
        )', FilterType)
        
        ; 执行 JavaScript（如果使用 WebView2）
        if (SearchCenterWebView.HasMethod("ExecuteScript")) {
            SearchCenterWebView.ExecuteScript(JS)
        }
        ; 或者使用其他方式发送消息，取决于 WebView 实现
    } catch as err {
        OutputDebug("AHK_DEBUG: 更新 WebView 标签状态失败: " . err.Message)
    }
}
```

### 3. 搜索后保持标签状态

```autohotkey
; ===================== 刷新搜索结果（修复版：保持标签状态）=====================
RefreshSearchCenterResults() {
    global SearchCenterSearchResults, SearchCenterResultLV, SearchCenterFilterType
    global SearchCenterWebView  ; 如果有 WebView
    
    ; ... 过滤和显示结果的逻辑 ...
    
    ; 【关键修复】刷新后确保 WebView 标签状态正确（如果使用 HTML 版本）
    if (SearchCenterWebView && SearchCenterWebView != 0) {
        UpdateWebViewFilterState(SearchCenterFilterType)
    }
}
```

## 核心修复点

### 1. 动态 active 类（不硬编码）
- ❌ **错误**：`<button class="filter-tag active">全部</button>`
- ✅ **正确**：根据 `ActiveFilterType` 动态设置

### 2. 前端立即更新 CSS 类
- ❌ **错误**：只调用 `postMessage`，不更新 CSS
- ✅ **正确**：先更新 CSS 类，再通知 AHK

### 3. 双向通信
- ❌ **错误**：只有"网页 -> AHK"
- ✅ **正确**："网页 -> AHK" + "AHK -> 网页"状态同步

### 4. 搜索后保持状态
- ❌ **错误**：搜索后重置为"全部"
- ✅ **正确**：搜索后保持当前选中的标签状态

## 使用示例

```autohotkey
; 创建 WebView 并加载 HTML
ShowSearchCenterWebView() {
    global SearchCenterWebView, SearchCenterFilterType
    
    ; 生成 HTML（传入当前过滤类型，不硬编码）
    HTML := GenerateSearchCenterHTML(SearchCenterFilterType)
    
    ; 加载 HTML 到 WebView（根据实际使用的 WebView 库调整）
    ; SearchCenterWebView.NavigateToString(HTML)
    
    ; 或者使用文件方式
    ; HTMLFile := A_ScriptDir "\SearchCenter.html"
    ; FileAppend(HTML, HTMLFile)
    ; SearchCenterWebView.Navigate("file:///" . HTMLFile)
}
```

## 注意事项

1. **WebView 实现**：根据实际使用的 WebView 库（WebView2、Neutron 等）调整消息传递方式
2. **状态同步**：确保 AHK 端和网页端的 `SearchCenterFilterType` 始终保持一致
3. **性能优化**：CSS 类更新应在主线程同步执行，避免闪烁
