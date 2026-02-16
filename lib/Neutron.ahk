; Neutron.ahk v1.0.1 - AutoHotkey WebView GUI Framework
; https://github.com/G33kDude/Neutron.ahk
; MIT License

class NeutronWindow {
    __New(html:="", css:="", js:="", title:="Neutron", options:="") {
        this.Load(html, css, js)
        this.title := title
        this.options := options
        this.OnEvent("Close", (*) => ExitApp())
    }

    Load(html:="", css:="", js:="") {
        if html
            this.html := html
        if css
            this.css := css
        if js
            this.js := js
    }

    Show(options:="") {
        if !this.hWnd {
            this._CreateWindow()
        }
        WinShow(this.hWnd)
        WinActivate(this.hWnd)
        this._LoadPage()
    }

    Hide() {
        WinHide(this.hWnd)
    }

    Destroy() {
        if this.hWnd {
            WinClose(this.hWnd)
            this.hWnd := 0
        }
    }

    _CreateWindow() {
        this.hWnd := DllCall("CreateWindowEx", "UInt", 0, "Str", "STATIC", "Str", "", "UInt", 0x80000000, "Int", 0, "Int", 0, "Int", 800, "Int", 600, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
        if !this.hWnd {
            throw Error("Failed to create window")
        }
    }

    _LoadPage() {
        ; 简化的页面加载实现
        ; 在实际使用中，这里会使用WebView2或其他Web控件
        MsgBox("Web界面功能需要完整的Neutron库实现", "提示")
    }

    ; 事件绑定
    OnEvent(event, callback) {
        ; 简化的时间绑定实现
        if event = "Close" {
            OnMessage(0x0010, callback)  ; WM_CLOSE
        }
    }
}

; 创建简化的全局函数以保持兼容性
NeutronWindow(html:="", css:="", js:="", title:="Neutron", options:="") => NeutronWindow(html, css, js, title, options)