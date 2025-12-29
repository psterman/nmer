# NiuMa - Cursor Editor Efficiency Tool

<div align="center">
  <img src="./banner.jpg" alt="NiuMa" width="800">
</div>

[简体中文](README.md) | English

An efficiency tool for Windows, specially designed for the [Cursor](https://cursor.sh/) editor! With the "CapsLock NiuMa Summoner" shortcut scheme, let Cursor work tirelessly to handle tedious tasks, boosting your coding efficiency by 100%~

---

## ✨ Core Features

*   🚀 **CapsLock Summoner**: Short press maintains case switching, long press (0.5s) summons the NiuMa shortcut panel - thoughtful and non-intrusive.
*   ⚡ **Zero Latency Response**: All operations provide instant feedback, no waiting for NiuMa to respond.
*   🎨 **Cursor-native Style**: Dark theme for seamless integration - NiuMa understands aesthetics.
*   📋 **NiuMa Memory Clipboard**: Continuous copying, merged pasting, history management - effortless material collection.
*   🤖 **AI Workhorse Spirit**: One-click code explanation, refactoring, and optimization without manual prompt typing.
*   ⚙️ **Highly Customizable**: Custom prompts, shortcuts, and panel positions - create your perfect NiuMa assistant.

---

## 🎯 Key Functions

### 1. Code Operation Panel

*   **Long press CapsLock** to summon the NiuMa shortcut panel.
*   **CapsLock + E**: Code Translator (NiuMa explains core logic and pitfalls in plain language).
*   **CapsLock + R**: Code Organizer (refactors and adds comments according to standards - NiuMa-style tidying).
*   **CapsLock + O**: Code Accelerator (analyzes performance bottlenecks and provides optimization solutions).
*   **CapsLock + S**: Code Splitter (inserts split markers for batch processing).
*   **CapsLock + B**: Batch Mode (process multiple code blocks at once - NiuMa works efficiently... I mean, productively).

### 2. Continuous Copy + Merged Paste

*   **CapsLock + C**: NiuMa Memory Collection (silently copies multiple fragments without interrupting workflow).
*   **CapsLock + V**: NiuMa Organized Output (automatically merges content with spaces/newlines and pastes to Cursor).
*   **CapsLock + X**: Memory Management Panel (view all copy history and access as needed).

### 3. NiuMa Memory Management Panel

*   📋 Preview all copy history at a glance.
*   🔄 Double-click to quickly recall - no repeated copying.
*   ✂️ Delete useless memories to lighten NiuMa's burden.
*   📤 Directly paste selected content to Cursor in one step.
*   🗑️ Clear records with one click - let NiuMa start fresh.

### 4. NiuMa Configuration Panel (`CapsLock + Q`)

*   📁 **Specify Cursor Path**: Help NiuMa find its master by locating `Cursor.exe`.
*   ⏱️ **Adjust AI Wait Time**: Adapt to different computer configurations.
*   💬 **Customize Prompts**: Modify the "PUA scripts" for explanation, refactoring, and optimization.
*   ⌨️ **Reset Shortcuts**: Avoid conflicts with other software.
*   🖥️ **Multi-monitor Support**: Customize the panel display position.

---

## 📥 Installation

### Method 1: Direct Download (Recommended)

1.  Visit the [Releases](https://github.com/psterman/nmer/releases) page.
2.  **Prerequisite**: Install [AutoHotkey 2.0](https://www.autohotkey.com/download/ahk-v2.exe).
3.  Download the latest `NiuMa.ahk` file.

### Method 2: Install the EXE Lazy Package Version

*(Instructions for this method will be provided when available.)*

---

## 🔧 Getting Started

### Basic Requirements

*   **Operating System**: Windows 10/11 (NiuMa only recognizes its Windows home).
*   **AutoHotkey**: v2.0 or higher (NiuMa's essential sustenance - must be installed).
*   **Cursor Editor**: Installed and functioning properly.

### Step 1: Install AutoHotkey v2

1.  Download and install AutoHotkey v2 from the [official website](https://www.autohotkey.com/).
2.  (Optional) To run `.ahk` files directly:
    *   Right-click `NiuMa.ahk` → **Open with** → Select **AutoHotkey**.
    *   Check **Always use this app to open** `.ahk` files.

### Step 2: First Run & Configuration

1.  **Place the Script**: Save `NiuMa.ahk` in a permanent directory (e.g., `D:\Tools\NiuMa\`).
2.  **Run the Script**: Double-click `NiuMa.ahk`. Click **Yes** when prompted for administrator privileges (required for keyboard monitoring).
3.  **Configure Cursor Path**:
    *   Right-click the NiuMa icon in the system tray and select **Open Configuration Panel** (or press `CapsLock + Q`).
    *   If Cursor is not in the default path, click **Browse** to locate `Cursor.exe`.
    *   Click **Save Configuration**.

### Step 3: Set Auto-Start (Optional)

1.  Press `Win + R`, type `shell:startup`, and press Enter to open the Startup folder.
2.  Create a shortcut to `NiuMa.ahk` and place it in this folder.

---

## 🚀 Quick Start Guide

### 1. Let NiuMa Explain Code

1.  Select the target code in Cursor.
2.  Long press `CapsLock` to summon the panel and press `E`.
3.  NiuMa will automatically copy the code, fill in the prompt, and send it to Cursor. Just wait for the result.

### 2. Continuous Copy & Merged Paste

1.  Select the first text segment and press `CapsLock + C`.
2.  Select the second text segment and press `CapsLock + C`.
3.  Repeat as needed...
4.  In the Cursor input box, press `CapsLock + V` to merge and paste all collected content.

### 3. Manage NiuMa's Memory

1.  Press `CapsLock + X` to open the memory panel.
2.  Double-click any entry to copy it to your clipboard.
3.  Use the buttons at the bottom to **Delete** selected items or **Clear All** records.

---

## ⌨️ Full Command List

| Shortcut Key | Function Description |
|:----------- |:------------------- |
| `Long press CapsLock` | Summon the NiuMa shortcut panel |
| `CapsLock + E` | Explain code (NiuMa Translator) |
| `CapsLock + R` | Refactor code (NiuMa Architect) |
| `CapsLock + O` | Optimize code (NiuMa Accelerator) |
| `CapsLock + S` | Split code (NiuMa Splitter) |
| `CapsLock + B` | Batch operation (NiuMa Assembly Line) |
| `CapsLock + C` | Continuous copy (NiuMa Memory Collection) |
| `CapsLock + V` | Merged paste (Combine and organize output) |
| `CapsLock + X` | Open memory panel (NiuMa Memo) |
| `CapsLock + Q` | Open configuration panel (NiuMa Settings) |
| `ESC` | Close any open NiuMa panel |

---

## ⚠️ Troubleshooting

### Common Issues & Solutions

#### 1. NiuMa Doesn't Start (No response on double-click)

*   **Check AutoHotkey Version**: Ensure you have **v2.0+** installed, as v1.x is incompatible.
*   **Re-download**: The `NiuMa.ahk` file might be corrupted. Try downloading it again.
*   **Run as Admin**: Right-click the file and select **Run as administrator**.

#### 2. Repeated UAC Prompts for Administrator Access

*   This is normal. NiuMa needs admin rights to listen to global keyboard events.
*   **Fix**: Right-click `NiuMa.ahk` → **Properties** → **Compatibility** → Check **Run this program as an administrator**.

#### 3. Cursor Doesn't Respond to NiuMa's Commands

*   **Check Cursor**: Ensure Cursor is running.
*   **Verify Path**: Open the configuration panel (`CapsLock + Q`) and confirm the path to `Cursor.exe` is correct. The default path is usually `C:\Users\YourUsername\AppData\Local\Cursor\Cursor.exe`.
*   **Adjust Wait Time**: In the configuration panel, try increasing the **AI Response Wait Time** (e.g., to 20000ms).

#### 4. Shortcut Conflicts

*   If a shortcut doesn't work, it might be used by another program.
*   **Fix**: Open the configuration panel (`CapsLock + Q`) to reassign the conflicting shortcut.

---

## 🛠️ Advanced Tips

### Customizing AI Prompts

You can tailor NiuMa's behavior by modifying the prompts in the configuration panel:

*   **Explanation Prompt**: Control how detailed or concise the explanations are.
*   **Refactoring Prompt**: Enforce specific coding standards (e.g., PEP8 for Python).
*   **Optimization Prompt**: Guide NiuMa to prioritize certain aspects (e.g., speed, readability, or memory usage).

### Performance Tuning

*   **AI Response Wait Time**:
    *   **Low-end PCs**: Set to **20000ms** or higher.
    *   **High-end PCs**: Can be reduced to **10000-15000ms**.
    *   **Default**: **15000ms** (a balanced setting).

---

## 📝 Changelog

### v1.0.0
*   ✨ Initial release - NiuMa officially goes to work!
*   ✨ Core `CapsLock` summoner and shortcut panel.
*   ✨ AI-powered code explanation, refactoring, and optimization.
*   ✨ Continuous copy & merged paste with memory management.
*   ✨ Configuration panel for all settings.
*   ✨ Multi-monitor support.

---

## 🤝 Contributing

Contributions are welcome! Feel free to submit Issues and Pull Requests to help NiuMa evolve and become even more powerful.

---

## 📄 License

This project is licensed under the **Apache License 2.0**.

### You Can:
*   ✅ Use it freely for personal and commercial purposes.
*   ✅ Modify and distribute the source code.
*   ✅ Integrate it into your own commercial products.

### You Must:
*   ⚠️ Include a copy of the license and copyright notice in all copies or substantial portions of the software.
*   ⚠️ State any changes you made to the original code.

For more details, please see the [LICENSE](LICENSE) file or visit the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) website.

---

## 🙏 Acknowledgments

*   [AutoHotkey](https://www.autohotkey.com/) - The powerful scripting language that makes NiuMa possible.
*   [Cursor](https://cursor.sh/) - The amazing AI code editor that NiuMa serves.
*   [capslock+](https://github.com/wo52616111/capslock-plus/) - An inspiration for the CapsLock-based interaction model.
*   [SQLiteDB for AHK](https://www.autohotkey.com/boards/viewtopic.php?t=95389) - For providing the memory management capabilities.
*   All users and contributors who help improve NiuMa!

---

## 📮 Contact

*   **Issues & Feedback**: Please use the [GitHub Issues](https://github.com/psterman/nmer/issues) page.
*   **WeChat**: Scan the QR code below to connect with the developer and discuss NiuMa training techniques:

<img width="200" alt="WeChat QR Code" src="https://github.com/user-attachments/assets/68b79c9f-1311-4762-811a-4bbad9b4997a">

**⭐ If NiuMa has been helpful to you, please give it a Star on GitHub to show your support!**
