# CapsLock+T 截图助手不弹出问题排查

## 问题描述
按 CapsLock+T 后，截图助手不弹出。

## 已添加的调试代码

我在代码中添加了以下调试信息，帮助定位问题：

### 1. 快捷键触发检测（第 19442 行）
- 当按下 CapsLock+T 时，会显示 "CapsLock+T 被触发"
- 如果 `HandleDynamicHotkey` 返回 false，会显示 "HandleDynamicHotkey 返回 false"
- 如果返回 true，会显示 "HandleDynamicHotkey 返回 true，已处理"

### 2. 快捷键匹配检测（第 19225 行）
- 在 `HandleDynamicHotkey` 函数中，当 ActionType 为 "T" 时，会显示：
  - KeyLower（按下的键，小写）
  - ConfigKey（配置的快捷键，小写）
  - HotkeyT（全局变量值）

### 3. 执行流程检测（第 19335 行）
- 进入 case "T" 分支时，显示 "进入 case T，准备调用 ExecuteScreenshotWithMenu()"
- 调用完成后，显示 "ExecuteScreenshotWithMenu() 调用完成"

### 4. 截图助手调用检测（第 22798 行）
- 准备调用 `ShowScreenshotEditor()` 时，显示 ScreenshotClipboard 是否存在
- 调用成功后，显示 "ShowScreenshotEditor() 调用成功"

### 5. 窗口显示检测（第 27169 行）
- 准备显示窗口时，显示窗口尺寸和位置信息
- 窗口显示后，显示 "截图助手窗口已显示！"

## 排查步骤

1. **重新加载脚本**
   - 保存文件后，重新加载 AutoHotkey 脚本

2. **按 CapsLock+T**
   - 观察托盘提示，记录每一步的提示信息

3. **根据提示信息判断问题位置**

### 情况 1：没有看到 "CapsLock+T 被触发"
- **可能原因**：快捷键没有被注册或 `#HotIf GetCapsLockState()` 返回 false
- **检查**：
  - 确认 CapsLock 键确实被按下
  - 检查 `GetCapsLockState()` 函数是否正常工作
  - 检查是否有其他程序占用了 CapsLock+T 快捷键

### 情况 2：看到 "CapsLock+T 被触发" 但显示 "HandleDynamicHotkey 返回 false"
- **可能原因**：快捷键配置不匹配
- **检查**：
  - 查看调试信息中的 KeyLower、ConfigKey、HotkeyT 值
  - 确认 `HotkeyT` 变量值是否为 "t"
  - 检查配置文件 `CursorShortcut.ini` 中 `[Hotkeys]` 部分的 `T` 值

### 情况 3：看到 "进入 case T" 但没有看到 "ExecuteScreenshotWithMenu() 调用完成"
- **可能原因**：`ExecuteScreenshotWithMenu()` 函数执行出错
- **检查**：
  - 查看是否有错误提示
  - 检查截图工具（Win+Shift+S）是否能正常启动
  - 检查是否在 30 秒内完成了截图

### 情况 4：看到 "准备调用 ShowScreenshotEditor()" 但 ScreenshotClipboard 为空
- **可能原因**：截图数据没有正确保存
- **检查**：
  - 确认截图是否成功完成
  - 检查剪贴板是否包含图片数据
  - 查看调试窗口中的详细步骤信息

### 情况 5：看到 "ShowScreenshotEditor() 调用成功" 但没有看到 "截图助手窗口已显示！"
- **可能原因**：窗口创建或显示失败
- **检查**：
  - 查看是否有错误提示
  - 检查 GDI+ 是否正常初始化
  - 检查窗口是否被其他窗口遮挡
  - 检查屏幕坐标是否正确

## 常见问题

### 问题 1：HotkeyT 配置错误
**解决方案**：
1. 打开 `CursorShortcut.ini` 文件
2. 检查 `[Hotkeys]` 部分是否有 `T=t`
3. 如果没有，添加 `T=t`
4. 重新加载脚本

### 问题 2：截图工具无法启动
**解决方案**：
1. 手动按 Win+Shift+S 测试截图工具是否正常
2. 如果无法启动，可能是 Windows 截图工具被禁用
3. 检查 Windows 设置中的截图工具设置

### 问题 3：GDI+ 初始化失败
**解决方案**：
1. 检查 `lib\Gdip_All.ahk` 文件是否存在
2. 检查脚本是否有管理员权限
3. 检查系统是否支持 GDI+

### 问题 4：窗口被遮挡或显示在屏幕外
**解决方案**：
1. 检查多屏幕设置
2. 检查窗口坐标计算是否正确
3. 尝试按 Alt+Tab 查看是否有隐藏的窗口

## 移除调试代码

问题解决后，可以移除调试代码。搜索以下内容并删除：
- `TrayTip("调试", ...)`
- 相关的调试提示信息

或者直接告诉我，我可以帮您移除。
