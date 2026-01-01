# AutoHotkey GUI option errors
_Exported on 12/31/2025 at 23:13:42 GMT+8 from Cursor via WayLog_


**User**

Error: Invalid option.

Specifically: NoActivate

	19522: }
	19525: InitGDI()
▶	19529: CountdownGui := Gui("+AlwaysOnTop +Disabled +NoActivate -Caption +E0x20", "ActionCountdown")
	Error: Invalid option.

Specifically: w80

	19530: CountdownGui.BackColor := "000000"
	19533: WindowSize := 80
▶	19534: CountdownGui.Opt("w" . WindowSize . " h" . WindowSize)

---


**User**

Error: Invalid option.

Specifically: NoActivate

	19522: }
	19525: InitGDI()
▶	19529: CountdownGui := Gui("+AlwaysOnTop +Disabled +NoActivate -Caption +E0x20", "ActionCountdown")
	Error: Invalid option.

Specifically: w80

	19530: CountdownGui.BackColor := "000000"
	19533: WindowSize := 80
▶	19534: CountdownGui.Opt("w" . WindowSize . " h" . WindowSize)
Error: Parameter #1 of SetTimer requires an Object, but received an empty string.

	19739: If (CountdownTimer != 0)
	19739: {
▶	19740: SetTimer(CountdownTimer, 0)1

---


**Cursor**

检查这些错误。先查看相关代码：



查看相关代码上下文，了解这些变量的定义和使用方式：

---


**User**

1/你弄错了，用户粘贴capslock+f后，要重新开启searchcenter选中listview数据才开始倒计时操作。
2/倒计时现在没有生效，而且是一个蓝色方块，而不是蓝色逐渐变黑的圆环
3/倒计时配置没有在配置的高级标签里

---


**Cursor**

检查相关代码，定位这三个问题：

---


**User**

继续

---


**Cursor**

继续在高级标签页添加倒计时配置选项：

---


**User**

Error: Unexpected "Catch"

	19518: }
	19519: }
▶	19519: Catch 考虑一下autohotkey2.0

---
