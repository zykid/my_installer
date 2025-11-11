#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import tempfile
import subprocess
import hashlib
from pathlib import Path

REPO_RAW_BASE = "https://raw.githubusercontent.com/你的用户名/my_installer/main"
INSTALLERS_JSON_URL = f"{REPO_RAW_BASE}/installers.json"
SELF_URL = f"{REPO_RAW_BASE}/launcher.py"

LOCAL_DIR = Path.home() / ".zykid_installer"
SELF_PATH = LOCAL_DIR / "launcher.py"

def sha256_of_bytes(b):
    import hashlib
    return hashlib.sha256(b).hexdigest()

def get_remote_bytes(url):
    with urllib.request.urlopen(url, timeout=15) as r:
        return r.read()

def check_self_update():
    try:
        remote = get_remote_bytes(SELF_URL)
        remote_hash = sha256_of_bytes(remote)
        if SELF_PATH.exists():
            local_hash = sha256_of_bytes(SELF_PATH.read_bytes())
        else:
            local_hash = ""
        if remote_hash != local_hash:
            print("检测到 launcher.py 新版本，正在更新...")
            LOCAL_DIR.mkdir(parents=True, exist_ok=True)
            SELF_PATH.write_bytes(remote)
            SELF_PATH.chmod(0o755)
            # 重启为新版本
            os.execv(sys.executable, [sys.executable, str(SELF_PATH)] + sys.argv[1:])
    except Exception as e:
        print("检查更新失败：", e)

def load_installers():
    try:
        data = get_remote_bytes(INSTALLERS_JSON_URL)
        return json.loads(data)
    except Exception as e:
        print("加载 installers.json 失败：", e)
        return {"programs": []}

def download_and_run(script_url, as_shell=False):
    try:
        data = get_remote_bytes(script_url)
        # 如果是脚本（bash），保存为临时文件并 chmod
        suffix = ".sh" if script_url.endswith(".sh") else ".py"
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
        tmp.write(data)
        tmp.flush()
        tmp.close()
        os.chmod(tmp.name, 0o755)
        if as_shell or suffix == ".sh":
            subprocess.run(["/bin/bash", tmp.name])
        else:
            subprocess.run([sys.executable, tmp.name])
    except Exception as e:
        print("执行失败：", e)

def main():
    # 确保本地 launcher 存在（首次 bootstrap 后会有）
    LOCAL_DIR.mkdir(parents=True, exist_ok=True)
    # 检查并自我更新（如果在 bootstrap 模式首次下载，SELF_PATH 可能就是本脚本）
    check_self_update()
    config = load_installers()
    progs = config.get("programs", [])
    while True:
        print("\n=== 安装面板 ===")
        for idx, p in enumerate(progs, 1):
            print(f"{idx}. {p.get('name')} — {p.get('desc')}")
        print("0. 退出")
        choice = input("请选择编号: ").strip()
        if choice == "0":
            break
        if not choice.isdigit() or not (1 <= int(choice) <= len(progs)):
            print("输入错误")
            continue
        sel = progs[int(choice)-1]
        print("准备执行：", sel.get("name"))
        download_and_run(sel.get("script_url"), as_shell=sel.get("shell", True))
        input("按回车返回菜单...")

if __name__ == "__main__":
    main()

