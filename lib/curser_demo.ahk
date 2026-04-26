; ======================================================================================================================
; Curser Demo - Cursor Chat Exporter 功能演示
; ======================================================================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; 演示GUI
demoGUI := Gui("+Resize", "Curser - Cursor Chat Exporter 演示")
demoGUI.Add("Text", "x10 y10 w580 h40", "🎯 Curser - Cursor Chat Exporter`nCursor 编辑器聊天记录导出工具")
demoGUI.Add("Text", "x10 y60 w580 h20", "功能特点：")

; 功能列表
features := "
✅ Markdown/HTML/JSON 多种导出格式
✅ 暗色/亮色主题切换 (参考v2ex风格)
✅ 搜索和过滤聊天内容
✅ 支持多工作区批量导出
✅ 导入恢复功能框架
✅ 高性能SQLite数据库访问
✅ 完整的错误处理和日志记录
✅ 自动检测Cursor工作区
✅ 用户友好的图形界面
✅ 兼容新旧版本Cursor"

demoGUI.Add("Text", "x10 y85 w580 h200", features)

; 使用说明
demoGUI.Add("Text", "x10 y295 w580 h30", "🚀 启动方式：")
instructions := "
1. 运行 curser.ahk 脚本
2. 自动扫描Cursor工作区
3. 双击工作区查看聊天记录
4. 选择导出格式和范围
5. 点击导出按钮开始导出"

demoGUI.Add("Text", "x10 y330 w580 h80", instructions)

; 演示按钮
demoGUI.Add("Button", "x10 y420 w120 h35 vStartDemo", "启动Curser").OnEvent("Click", StartCurser)
demoGUI.Add("Button", "x140 y420 w120 h35 vShowFeatures", "功能详情").OnEvent("Click", ShowFeatures)
demoGUI.Add("Button", "x270 y420 w120 h35 vCheckSystem", "系统检查").OnEvent("Click", CheckSystem)

; 状态信息
demoGUI.Add("Text", "x10 y470 w580 h25 vStatusText", "状态：准备就绪")

; 显示演示窗口
demoGUI.Show("w600 h520")

; ===================== 演示函数 =====================

StartCurser(*) {
    demoGUI["StatusText"].Text := "正在启动Curser..."
    try {
        Run(A_ScriptDir "\curser.ahk")
        demoGUI["StatusText"].Text := "Curser已启动！"
    } catch {
        demoGUI["StatusText"].Text := "启动失败，请检查脚本是否存在"
    }
}

ShowFeatures(*) {
    features := "
🎨 界面设计
   • 现代化的AHK GUI界面
   • 暗色/亮色主题切换
   • 参考v2ex的设计风格
   • 响应式布局和交互

📊 数据处理
   • SQLite数据库高效访问
   • JSON数据智能解析
   • 兼容新旧Cursor版本
   • 完整的错误处理机制

🔍 搜索过滤
   • 实时搜索聊天内容
   • 按类型过滤 (聊天/Composer)
   • 多条件组合查询
   • 搜索结果高亮显示

📁 导出功能
   • Markdown格式 (带代码高亮)
   • HTML格式 (美观网页)
   • JSON格式 (原始数据)
   • 批量导出多个工作区

⚙️ 高级特性
   • 导入恢复功能框架
   • 性能优化 (异步处理)
   • 完整的日志记录
   • 配置持久化保存

🛠️ 技术架构
   • 模块化设计
   • 面向对象编程
   • 异常安全处理
   • 内存优化管理"

    MsgBox(features, "Curser 功能详情", "Iconi")
}

CheckSystem(*) {
    demoGUI["StatusText"].Text := "正在检查系统..."

    ; 检查Cursor安装
    cursorPath := A_AppData "\Cursor\User\workspaceStorage"
    cursorStatus := DirExist(cursorPath) ? "✅ 已安装" : "❌ 未检测到"

    ; 检查工作区数量
    workspaceCount := 0
    if (DirExist(cursorPath)) {
        Loop Files cursorPath "\*", "D" {
            dbPath := A_LoopFilePath "\state.vscdb"
            if (FileExist(dbPath)) {
                workspaceCount++
            }
        }
    }

    ; 检查依赖库
    libStatus := ""
    libs := ["Class_SQLiteDB.ahk", "Gdip_All.ahk"]
    for lib in libs {
        libStatus .= FileExist(A_ScriptDir "\" lib) ? "✅ " lib "`n" : "❌ " lib "`n"
    }

    ; 检查输出目录
    outputStatus := ""
    dirs := ["..\config", "..\output\markdown", "..\output\html", "..\output\json", "..\logs"]
    for dir in dirs {
        outputStatus .= DirExist(A_ScriptDir "\" dir) ? "✅ " dir "`n" : "❌ " dir "`n"
    }

    report := "🔍 系统检查报告`n`n"
    report .= "Cursor状态: " cursorStatus "`n"
    report .= "工作区数量: " workspaceCount "`n`n"
    report .= "依赖库状态:`n" libStatus "`n"
    report .= "目录状态:`n" outputStatus

    demoGUI["StatusText"].Text := "检查完成"

    MsgBox(report, "系统检查报告", "Iconi")
}

demoGUI["StatusText"].Text := "演示程序运行中 - 点击按钮开始体验"</content>
<parameter name="filePath">C:\Users\pster\Desktop\小c\lib\curser_demo.ahk