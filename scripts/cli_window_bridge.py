from __future__ import annotations

import argparse
import ctypes
import ctypes.wintypes as wintypes
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


TITLE_PREFIX = "CursorHelper AI - "

AGENTS = {
    "gemini_cli": {"name": "Gemini", "executables": ["gemini.cmd", "gemini"]},
    "codex_cli": {"name": "Codex", "executables": ["codex.cmd", "codex"]},
    "openclaw_cli": {"name": "OpenClaw", "executables": ["openclaw.cmd", "openclaw"]},
    "qwen_cli": {"name": "Qwen", "executables": ["qwen.cmd", "qwen"]},
}

SW_RESTORE = 9
user32 = ctypes.windll.user32


def window_title(engine: str) -> str:
    return TITLE_PREFIX + AGENTS[engine]["name"]


def queue_dir(root: Path, engine: str) -> Path:
    return root / "cache" / "cli_queue" / engine


def find_executable(engine: str) -> str:
    for candidate in AGENTS[engine]["executables"]:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    if os.name == "nt":
        appdata = os.environ.get("APPDATA", "")
        local = os.environ.get("LOCALAPPDATA", "")
        npm_dirs = [
            Path(appdata) / "npm",
            Path(appdata) / "npm-global",
            Path(local) / "npm",
            Path(local) / "npm-global",
        ]
        for candidate in AGENTS[engine]["executables"]:
            for root in npm_dirs:
                p = root / candidate
                if p.is_file():
                    return str(p.resolve())
    raise FileNotFoundError(f"cannot resolve executable for {engine}")


def find_window_by_title(title: str) -> int:
    matches: list[int] = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    def enum_proc(hwnd: int, lparam: int) -> bool:
        if not user32.IsWindowVisible(hwnd):
            return True
        length = user32.GetWindowTextLengthW(hwnd)
        if length <= 0:
            return True
        buffer = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buffer, length + 1)
        if buffer.value == title:
            matches.append(hwnd)
            return False
        return True

    user32.EnumWindows(enum_proc, 0)
    return matches[0] if matches else 0


def activate_window(hwnd: int) -> None:
    if not hwnd:
        return
    user32.ShowWindow(hwnd, SW_RESTORE)
    user32.SetForegroundWindow(hwnd)


def ensure_worker_window(engine: str, workdir: Path) -> int:
    title = window_title(engine)
    existing = find_window_by_title(title)
    if existing:
        return existing

    worker_script = workdir / "scripts" / "cli_queue_worker.ps1"
    executable = find_executable(engine)
    queue_path = queue_dir(workdir, engine)
    queue_path.mkdir(parents=True, exist_ok=True)

    powershell = Path.home().anchor + "Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    if not Path(powershell).exists():
        powershell = r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

    subprocess.Popen(
        [
            str(powershell),
            "-NoExit",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(worker_script),
            "-Engine",
            engine,
            "-Title",
            title,
            "-Workdir",
            str(workdir),
            "-QueueDir",
            str(queue_path),
            "-Executable",
            executable,
        ],
        cwd=str(workdir),
        creationflags=subprocess.CREATE_NEW_CONSOLE,
    )

    deadline = time.time() + 12.0
    while time.time() < deadline:
        hwnd = find_window_by_title(title)
        if hwnd:
            return hwnd
        time.sleep(0.25)
    return 0


def enqueue_prompt(engine: str, prompt: str, workdir: Path) -> Path:
    target_dir = queue_dir(workdir, engine)
    target_dir.mkdir(parents=True, exist_ok=True)
    path = target_dir / f"{int(time.time() * 1000)}.txt"
    path.write_text(prompt, encoding="utf-8")
    return path


def handle_open(engines: list[str], workdir: Path) -> int:
    launched = 0
    for engine in engines:
        hwnd = ensure_worker_window(engine, workdir)
        if hwnd:
            activate_window(hwnd)
            launched += 1
            time.sleep(0.2)
    return 0 if launched else 1


def handle_send(engines: list[str], prompt: str, workdir: Path) -> int:
    launched = 0
    for engine in engines:
        hwnd = ensure_worker_window(engine, workdir)
        if not hwnd:
            continue
        enqueue_prompt(engine, prompt, workdir)
        activate_window(hwnd)
        launched += 1
        time.sleep(0.15)
    return 0 if launched else 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--action", choices=("open", "send"), required=True)
    parser.add_argument("--engines", required=True)
    parser.add_argument("--workdir", required=True)
    parser.add_argument("--prompt-file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    workdir = Path(args.workdir).resolve()
    engines = [engine.strip() for engine in args.engines.split(",") if engine.strip() in AGENTS]
    if not engines:
        return 1

    prompt = ""
    if args.prompt_file:
        prompt_file = Path(args.prompt_file)
        if prompt_file.exists():
            prompt = prompt_file.read_text(encoding="utf-8").strip()
            try:
                prompt_file.unlink()
            except OSError:
                pass

    if args.action == "send":
        if not prompt:
            return 1
        return handle_send(engines, prompt, workdir)
    return handle_open(engines, workdir)


if __name__ == "__main__":
    sys.exit(main())
