CONFIG_FILE="$HOME/.zykid_installer/config.json"
if [ -f "$CONFIG_FILE" ]; then
  BOT_TOKEN=$(jq -r '.BOT_TOKEN' "$CONFIG_FILE")
  CHAT_ID=$(jq -r '.CHAT_ID' "$CONFIG_FILE")
  NAS_PATH=$(jq -r '.NAS_PATH' "$CONFIG_FILE")
  NAS_USER=$(jq -r '.NAS_USER' "$CONFIG_FILE")
  NAS_PASS=$(jq -r '.NAS_PASS' "$CONFIG_FILE")
  MOUNT_POINT=$(jq -r '.MOUNT_POINT' "$CONFIG_FILE")
else
  echo "请先创建配置文件：$CONFIG_FILE"
  exit 1
fi

