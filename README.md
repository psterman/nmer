# Cursor助手 - Cursor 编辑器快捷工具

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)
[![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2-blue.svg)](https://www.autohotkey.com/)

一个专为 [Cursor](https://cursor.sh/) 编辑器设计的 Windows 快捷工具，通过 CapsLock+ 快捷键方案，让代码操作更加高效流畅。

## ✨ 项目特色

- 🚀 **CapsLock+ 快捷键方案**：保留 CapsLock 原有功能，长按调出快捷面板，短按正常切换大小写
- ⚡ **即时响应**：所有操作零延迟，流畅体验
- 🎨 **Cursor 风格界面**：深色主题，与 Cursor 编辑器完美融合
- 📋 **智能剪贴板管理**：连续复制、合并粘贴、历史管理
- 🤖 **AI 代码助手集成**：一键解释、重构、优化代码
- ⚙️ **高度可配置**：支持自定义提示词、快捷键、面板位置等

## 🎯 主要功能

### 1. 代码操作快捷面板
- **长按 CapsLock** 调出快捷操作面板
- **CapsLock + E**：解释代码（快速理解代码逻辑）
- **CapsLock + R**：重构代码（规范化、添加注释）
- **CapsLock + O**：优化代码（性能分析和优化建议）
- **CapsLock + S**：分割代码（插入分割标记）
- **CapsLock + B**：批量操作（批量解释/重构/优化）

### 2. 连续复制与合并粘贴
- **CapsLock + C**：连续复制多个文本片段（静默操作，无干扰）
- **CapsLock + V**：将所有复制的内容合并后粘贴到 Cursor 输入框
- **CapsLock + X**：打开剪贴板管理面板，查看、管理所有复制历史

### 3. 剪贴板管理面板
- 📋 查看所有复制历史（显示预览）
- 🔄 双击快速复制
- ✂️ 删除不需要的项目
- 📤 直接粘贴选中项到 Cursor
- 🗑️ 一键清空所有记录

### 4. 配置面板
- 📁 自定义 Cursor 安装路径
- ⏱️ 调整 AI 响应等待时间
- 💬 自定义提示词（解释/重构/优化）
- ⌨️ 自定义快捷键
- 🖥️ 多屏幕支持，自定义面板位置

## 📥 下载

### 方式一：直接下载
1. 访问 [Releases](https://github.com/your-username/cursor_helper/releases) 页面
2. 下载最新版本的 `CursorHelper.ahk` 文件

### 方式二：克隆仓库
```bash
git clone https://github.com/your-username/cursor_helper.git
cd cursor_helper
```

## 🔧 环境准备

### 系统要求
- **操作系统**：Windows 10/11
- **AutoHotkey**：v2.0 或更高版本
- **Cursor 编辑器**：已安装并可以正常运行

### 安装 AutoHotkey v2

1. **下载 AutoHotkey v2**
   - 访问 [AutoHotkey 官网](https://www.autohotkey.com/)
   - 下载并安装 AutoHotkey v2 版本

2. **验证安装**
   - 打开命令提示符或 PowerShell
   - 运行 `ahk --version` 检查版本
   - 应该显示 v2.x.x

3. **关联 .ahk 文件（可选）**
   - 右键点击 `.ahk` 文件
   - 选择「打开方式」→「选择其他应用」
   - 选择 AutoHotkey v2 并勾选「始终使用此应用打开 .ahk 文件」

## 📦 安装方式

### 步骤 1：下载脚本
将 `CursorHelper.ahk` 文件保存到任意目录（建议放在固定位置，如 `D:\Tools\CursorHelper\`）

### 步骤 2：首次运行
1. 双击 `CursorHelper.ahk` 文件
2. 如果提示需要管理员权限，点击「是」
3. 脚本会自动创建配置文件 `CursorShortcut.ini`

### 步骤 3：配置 Cursor 路径
1. 右键点击系统托盘中的图标
2. 选择「打开配置面板」
3. 如果 Cursor 不在默认路径，点击「浏览」选择 `Cursor.exe` 的位置
4. 点击「保存配置」

### 步骤 4：设置开机自启（可选）
1. 按 `Win + R` 打开运行对话框
2. 输入 `shell:startup` 并回车
3. 将 `CursorHelper.ahk` 的快捷方式复制到启动文件夹
4. 或者使用任务计划程序设置开机自启

## 🚀 快速开始

### 基础使用

1. **解释代码**
   - 在 Cursor 中选中代码
   - 长按 `CapsLock`，按 `E` 键
   - AI 会自动将提示词和代码发送到 Cursor

2. **连续复制**
   - 选中第一段文本，按 `CapsLock + C`
   - 选中第二段文本，按 `CapsLock + C`
   - 继续复制更多内容...
   - 按 `CapsLock + V` 将所有内容合并粘贴到 Cursor

3. **管理剪贴板**
   - 按 `CapsLock + X` 打开管理面板
   - 双击项目快速复制
   - 使用底部按钮进行管理操作

### 快捷键一览

| 快捷键 | 功能 |
|--------|------|
| `长按 CapsLock` | 调出快捷操作面板 |
| `CapsLock + E` | 解释代码 |
| `CapsLock + R` | 重构代码 |
| `CapsLock + O` | 优化代码 |
| `CapsLock + S` | 分割代码 |
| `CapsLock + B` | 批量操作 |
| `CapsLock + C` | 连续复制 |
| `CapsLock + V` | 合并粘贴到 Cursor |
| `CapsLock + X` | 打开剪贴板管理面板 |
| `CapsLock + Q` | 打开配置面板 |
| `ESC` | 关闭面板 |

## ⚠️ 异常处理

### 常见问题

#### 1. 脚本无法启动
**问题**：双击 `.ahk` 文件没有反应

**解决方案**：
- 确认已安装 AutoHotkey v2（不是 v1）
- 检查文件是否损坏，重新下载
- 尝试右键「以管理员身份运行」

#### 2. 提示需要管理员权限
**问题**：每次运行都提示需要管理员权限

**解决方案**：
- 这是正常行为，脚本需要管理员权限才能正常工作
- 可以右键脚本，选择「属性」→「兼容性」→勾选「以管理员身份运行此程序」

#### 3. Cursor 未响应
**问题**：按快捷键后 Cursor 没有反应

**解决方案**：
- 检查 Cursor 是否正在运行
- 确认配置面板中的 Cursor 路径是否正确
- 尝试手动打开 Cursor，然后再次使用快捷键
- 检查 AI 响应等待时间设置是否过短（建议 15000ms）

#### 4. 快捷键冲突
**问题**：快捷键与其他软件冲突

**解决方案**：
- 在配置面板中修改快捷键设置
- 或者关闭冲突的软件

#### 5. 剪贴板管理面板无法打开
**问题**：按 `CapsLock + X` 没有反应

**解决方案**：
- 确认已使用 `CapsLock + C` 复制过内容
- 检查脚本是否正在运行（查看系统托盘图标）
- 尝试重启脚本

#### 6. 面板显示位置不对
**问题**：面板显示在错误的屏幕上

**解决方案**：
- 打开配置面板
- 在「面板位置设置」中选择正确的屏幕
- 保存配置并重新打开面板

### 调试模式

如果遇到问题，可以：

1. **查看错误信息**
   - 脚本运行时的错误会显示在消息框中
   - 记录错误信息以便排查

2. **检查配置文件**
   - 配置文件位置：脚本目录下的 `CursorShortcut.ini`
   - 可以手动编辑配置文件（注意格式）

3. **重新初始化**
   - 删除 `CursorShortcut.ini` 文件
   - 重新运行脚本，会自动创建默认配置

## 🛠️ 高级配置

### 自定义提示词

在配置面板中可以自定义三个操作的提示词：

- **解释代码提示词**：控制 AI 如何解释代码
- **重构代码提示词**：控制 AI 如何重构代码
- **优化代码提示词**：控制 AI 如何优化代码

### 性能调优

- **AI 响应等待时间**：根据电脑性能调整
  - 低配机：建议 20000ms
  - 高配机：建议 10000-15000ms
  - 默认：15000ms

### 多屏幕支持

- 支持在多屏幕环境下使用
- 可以在配置面板中选择面板显示的屏幕
- 面板始终居中显示

## 📝 更新日志

### v1.0.0
- ✨ 初始版本发布
- ✨ CapsLock+ 快捷键方案
- ✨ 代码解释/重构/优化功能
- ✨ 连续复制与合并粘贴
- ✨ 剪贴板管理面板
- ✨ 配置面板
- ✨ 多屏幕支持

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 贡献指南
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 版权声明

本项目采用 **CC BY-NC-SA 4.0**（知识共享 署名-非商业性使用-相同方式共享 4.0 国际）许可证。

### 您可以：
- ✅ **自由使用**：个人或非商业用途
- ✅ **修改**：可以修改代码以适应您的需求
- ✅ **分享**：可以分享给他人使用

### 您不可以：
- ❌ **商业使用**：禁止用于任何商业目的
- ❌ **移除版权声明**：必须保留原始版权声明

### 详细条款
请访问 [CC BY-NC-SA 4.0 许可证](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh) 查看完整条款。

## 🙏 致谢

- [AutoHotkey](https://www.autohotkey.com/) - 强大的 Windows 自动化工具
- [Cursor](https://cursor.sh/) - 优秀的 AI 代码编辑器
- 所有贡献者和用户的支持

## 📮 联系方式

- **Issues**：[GitHub Issues](https://github.com/your-username/cursor_helper/issues)
- **Discussions**：[GitHub Discussions](https://github.com/your-username/cursor_helper/discussions)

---

**⭐ 如果这个项目对您有帮助，请给个 Star！**








