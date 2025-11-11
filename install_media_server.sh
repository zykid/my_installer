#!/bin/bash
# ====================================================
# install_media_server.sh
# Plex + Emby + Telegram 状态机器人 一键安装脚本 (v3)
# 支持中文交互输入 + 自动生成配置文件
# 适用系统：Ubuntu 20.04 / 22.04 / 24.04
# ====================================================

CONFIG_FILE="/etc/media_installer.conf"
TELEGRAM_BOT_PATH="/usr/local/bin/plex_telegram_bot.py"

echo "===================================================="
echo " Plex + Emby + Telegram 状态机器人 一键安装脚本"
echo "===================================================="
echo ""

# --------- 检查 root 权限 ---------
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请以 root 身份运行此脚本 (sudo bash install_media_server.sh)"
    exit 1
fi

# --------- 检查是否已有配置文件 ---------
if [ -f "$CONFIG_FILE" ]; then
    echo "✅ 检测到已有配置文件，是否使用原配置？(y/n)"
    read -r USE_OLD
    if [[ "$USE_OLD" == "y" || "$USE_OLD" == "Y" ]]; then
        source "$CONFIG_FILE"
    fi
fi

# --------- 输入交互配置 ---------
if [ -z "$BOT_TOKEN" ]; then
    echo "🤖 请输入 Telegram 机器人令牌 (BOT_TOKEN):"
    read -r BOT_TOKEN
fi

if [ -z "$CHAT_ID" ]; then
    echo "💬 请输入 Telegram 聊天 ID (CHAT_ID):"
    read -r CHAT_ID
fi

if [ -z "$NAS_PATH" ]; then
    echo "💾 请输入 NAS 路径 (例如 //192.168.2.10/video):"
    read -r NAS_PATH
fi

if [ -z "$NAS_USER" ]; then
    echo "👤 请输入 NAS 用户名:"
    read -r NAS_USER
fi

if [ -z "$NAS_PASS" ]; then
    echo "🔑 请输入 NAS 密码:"
    read -r NAS_PASS
fi

if [ -z "$MOUNT_POINT" ]; then
    echo "📁 请输入 NAS 挂载目录 (默认 /mnt/nas_video):"
    read -r MOUNT_POINT
    MOUNT_POINT=${MOUNT_POINT:-/mnt/nas_video}
fi

# --------- 保存配置 ---------
echo "📝 正在保存配置..."
cat > "$CONFIG_FILE" << EOF
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
NAS_PATH="$NAS_PATH"
NAS_USER="$NAS_USER"
NAS_PASS="$NAS_PASS"
MOUNT_POINT="$MOUNT_POINT"
EOF

echo "✅ 配置已保存到: $CONFIG_FILE"
echo ""

# --------- 系统更新与依赖安装 ---------
echo "📦 正在更新系统并安装依赖..."
apt update -y && apt upgrade -y
apt install -y curl wget cifs-utils python3 python3-pip

# --------- 挂载 NAS ---------
echo "📂 正在挂载 NAS..."
mkdir -p "$MOUNT_POINT"

# 添加自动挂载配置
if ! grep -q "$MOUNT_POINT" /etc/fstab; then
    echo "//$NAS_PATH  $MOUNT_POINT  cifs  username=$NAS_USER,password=$NAS_PASS,iocharset=utf8,file_mode=0777,dir_mode=0777,nounix,noserverino  0  0" >> /etc/fstab
fi

mount -a

if mount | grep -q "$MOUNT_POINT"; then
    echo "✅ NAS 挂载成功: $MOUNT_POINT"
else
    echo "❌ NAS 挂载失败，请检查路径或凭据"
    exit 1
fi

# --------- 安装 Plex ---------
echo "🎬 正在安装 Plex..."
if ! dpkg -l | grep -q plexmediaserver; then
    wget -q https://downloads.plex.tv/plex-media-server-new/1.41.4.9463-630c9f557/debian/plexmediaserver_1.41.4.9463-630c9f557_amd64.deb -O /tmp/plex.deb
    dpkg -i /tmp/plex.deb || apt -f install -y
    systemctl enable plexmediaserver
    systemctl start plexmediaserver
    echo "✅ Plex 安装完成"
else
    echo "ℹ️ 已检测到 Plex，无需重复安装"
fi

# --------- 安装 Emby ---------
echo "🎞️ 正在安装 Emby..."
if ! dpkg -l | grep -q emby-server; then
    wget -q https://github.com/MediaBrowser/Emby.Releases/releases/download/4.9.0.28/emby-server-deb_4.9.0.28_amd64.deb -O /tmp/emby.deb
    dpkg -i /tmp/emby.deb || apt -f install -y
    systemctl enable emby-server
    systemctl start emby-server
    echo "✅ Emby 安装完成"
else
    echo "ℹ️ 已检测到 Emby，无需重复安装"
fi

# --------- 创建 Telegram 状态机器人 ---------
echo "🤖 正在创建 Telegram 状态机器人脚本..."

cat > "$TELEGRAM_BOT_PATH" << 'PYCODE'
#!/usr/bin/env python3
import os, time, requests, subprocess

BOT_TOKEN = os.getenv("BOT_TOKEN")
CHAT_ID = os.getenv("CHAT_ID")

def send(msg):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    requests.post(url, json={"chat_id": CHAT_ID, "text": msg})

def get_status(service):
    result = subprocess.run(["systemctl", "is-active", service], capture_output=True, text=True)
    return "✅ 运行中" if "active" in result.stdout else "❌ 未运行"

while True:
    plex_status = get_status("plexmediaserver")
    emby_status = get_status("emby-server")
    msg = f"🎬 Plex 状态: {plex_status}\n🎞️ Emby 状态: {emby_status}\n🕓 更新时间: {time.strftime('%Y-%m-%d %H:%M:%S')}"
    send(msg)
    time.sleep(3600)
PYCODE

chmod +x "$TELEGRAM_BOT_PATH"

# 设置环境变量
cat > /etc/systemd/system/plexbot.service << EOF
[Unit]
Description=Plex+Emby Telegram 状态机器人
After=network.target

[Service]
ExecStart=/usr/bin/python3 $TELEGRAM_BOT_PATH
Restart=always
Environment=BOT_TOKEN=$BOT_TOKEN
Environment=CHAT_ID=$CHAT_ID

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable plexbot
systemctl start plexbot

# --------- 完成提示 ---------
echo ""
echo "✅ 安装完成！🎉"
echo "----------------------------------------"
echo "🔹 Plex 管理页面: http://$(hostname -I | awk '{print $1}'):32400/web"
echo "🔹 Emby 管理页面: http://$(hostname -I | awk '{print $1}'):8096"
echo "🔹 Telegram Bot 已启用，每小时推送运行状态"
echo "🔹 NAS 挂载路径: $MOUNT_POINT"
echo "----------------------------------------"

