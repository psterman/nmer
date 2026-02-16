# CapsLock+F 激活大写状态 - 终极修复方案

## 问题现象
- CapsLock+F 启动搜索中心后，CapsLock 大写灯亮起
- 单击 CapsLock 无法切换中文输入法
- 必须长按 CapsLock 才能切换输入法

## 根本原因

**`~` 前缀 + 系统 CapsLock 处理 = 竞争条件**

```
时间线：
1. 用户按下 CapsLock
2. 系统立即切换大写状态（灯亮）← ~ 前缀导致
3. 脚本执行 SetCapsLockState("Off") ← 试图关闭
4. 系统 vs 脚本 = 状态混乱
5. CapsLock 灯最终保持亮起
```

## 终极解决方案

### 核心思路
**完全禁用 CapsLock 大写功能，让脚本完全接管**

```ahk
#InstallKeybdHook          ; 安装键盘钩子
SetCapsLockState("AlwaysOff")  ; 完全禁用大写功能
```

### 修复步骤

#### 方法1：一键自动修复（推荐）

1. **双击运行** `Apply_CapsLock_Final_Fix.ahk`
2. 点击"应用修复"
3. 等待修复完成
4. **完全退出脚本**（托盘图标右键->退出）
5. **重新启动脚本**
6. 测试 CapsLock+F

#### 方法2：手动修复

**步骤1**：打开 `CursorHelper (1).ahk`，找到第 8 行附近，添加：

```ahk
; ===================== 基础配置 =====================
#SingleInstance Force
SetTitleMatchMode(2)
; ... 其他配置 ...

; 【修复】完全禁用 CapsLock 大写功能
#InstallKeybdHook
SetCapsLockState("AlwaysOff")
Loop 3 {
    SetCapsLockState("AlwaysOff")
    Sleep(50)
}
```

**步骤2**：找到 `~CapsLock::`（约第 3799 行），改为：

```ahk
; 修改前
~CapsLock:: {

; 修改后
CapsLock:: {
```

**步骤3**：在 `~CapsLock::` 热键内部的 `KeyWait(