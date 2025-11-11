#!/usr/bin/env python3
"""
installer_bootstrap.py
用于首次在设备上部署 zykid 命令：
- 下载 launcher.py 到 ~/.zykid_installer/launcher.py
- 在 /usr/local/bin/zykid 创建快捷命令（需要 sudo）
使用：
curl -sL https://raw.githubusercontent.com/你的用户名/my_installer/main/installer_bootstrap.py | sudo python3 -
"""
import os
import sys
import urllib.request
from pathlib import Path

REPO_RAW_BASE = "https://raw.githubusercontent.com/你的用户名/my_installer/main"
LOCAL_DIR = Path.home() / ".zykid_installer"
LAUNCHER_URL = f"{REPO_RAW_BASE}/launcher.py"
LAUNCHER_PATH = LOCAL_DIR / "launcher.py"
CMD_PATH = Path("/usr/local/bin/zykid")

def download(url, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    print("Downloading:", url)
    urllib.request.urlretrieve(url, dest)
    dest.chmod(0o755)

def create_command():
    content = f"#!/bin/bash\npython3 {LAUNCHER_PATH} \"$@\"\n"
    with open(CMD_PATH, "w") as f:
        f.write(content)
    os.chmod(CMD_PATH, 0o755)
    print("Created command:", CMD_PATH)

def main():
    download(LAUNCHER_URL, LAUNCHER_PATH)
    create_command()
    print("Bootstrap complete. You can now run 'zykid'")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("请以 root 或 sudo 运行此脚本（需要在 /usr/local/bin 创建命令）。")
        sys.exit(1)
    main()
  
