# CapsLock+F 激活大写状态 - 终极修复

## 问题
- CapsLock+F 后大写灯亮起
- 单击 CapsLock 无法切换中文

## 原因
`~` 前缀让系统和脚本同时处理 CapsLock，产生竞争条件

## 修复方案

### 方案1：一键修复（推荐）
1. 双击运行 `Apply_CapsLock_Final_Fix.ahk`
2. 点击"应用修复"
3. 完全退出脚本并重启

### 方案2：手动修复

**步骤1**：在脚本开头（第7行后）添加：
```ahk
#InstallKeybdHook
SetCapsLockState("AlwaysOff")
Loop 3 {
    SetCapsLockState("AlwaysOff")
    Sleep(50)
}
```

**步骤2**：将 `~CapsLock::` 改为 `CapsLock::`

**步骤3**：在 CapsLock 热键的 `KeyWait` 后添加：
```ahk
KeyWait("CapsLock")
SetCapsLockState("AlwaysOff")  ; 确保状态关闭
```

## 原理
- `#InstallKeybdHook`：安装键盘钩子，完全控制按键
- `SetCapsLockState("AlwaysOff")`：完全禁用大写功能
- 移除 `~` 前缀：不让系统处理 CapsLock
- 脚本完全接管 CapsLock，不再产生竞争

## 预期效果
- ✅ CapsLock 灯永远不会亮起
- ✅ CapsLock+F 正常打开搜索
- ✅ 单击 CapsLock 正常切换中文输入法
- ✅ 所有其他快捷键正常工作

## 如果输入法仍无法切换
某些输入法使用 Shift 切换，修改 CapsLock 热键的 else 分支：
```ahk
} else {
    ; 使用 Shift 切换输入法
    Send("{LShift}")
    CapsLock := false
}
```
