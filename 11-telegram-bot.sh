#!/bin/bash
#############################################################
# 11-telegram-bot.sh
# Telegram Bot integration for RARETRICCKS MULTI PROTOCOL panel
#   - /adduser  <username> <password> <days> <ip_limit> <gb_limit>
#   - /deluser  <username>
#   - /listusers
#   - /status
#   - Admin-only notifications (new user, server status, errors)
#
# Usage:
#   bash 11-telegram-bot.sh
#   (or place it in /etc/raretriccks/ and run after install-all.sh)
#############################################################

BASE_DIR="/etc/raretriccks"
[[ -f "$BASE_DIR/00-common.sh" ]] && source "$BASE_DIR/00-common.sh"

BOT_DIR="$BASE_DIR/telegram-bot"
BOT_CONF="$BOT_DIR/bot.conf"
BOT_SCRIPT="$BOT_DIR/bot.sh"
NOTIFY_SCRIPT="$BOT_DIR/notify.sh"
BOT_SERVICE="/etc/systemd/system/raretriccks-bot.service"
USER_MGR="$BASE_DIR/09-user-manager.sh"

if [[ $EUID -ne 0 ]]; then
    echo "Root chahiye is script ko chalane ke liye (sudo/root se run karo)."
    exit 1
fi

mkdir -p "$BOT_DIR"

echo "==============================================="
echo "   Telegram Bot Setup - RARETRICCKS Panel"
echo "==============================================="
read -rp "Bot Token (BotFather se): " BOT_TOKEN
read -rp "Admin Telegram Chat ID: " ADMIN_ID

if [[ -z "$BOT_TOKEN" || -z "$ADMIN_ID" ]]; then
    echo "Bot Token aur Admin Chat ID dono zaroori hain. Exiting."
    exit 1
fi

echo "-> Installing dependencies (curl, jq)..."
apt-get update -y >/dev/null 2>&1
apt-get install -y curl jq >/dev/null 2>&1

cat > "$BOT_CONF" <<EOF
BOT_TOKEN="$BOT_TOKEN"
ADMIN_ID="$ADMIN_ID"
USER_MGR="$USER_MGR"
EOF
chmod 600 "$BOT_CONF"

# ---- notify.sh : other scripts can call this to alert admin ----
cat > "$NOTIFY_SCRIPT" <<'NOTIFY'
#!/bin/bash
# Usage: notify.sh "message text"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/bot.conf"
MSG="$1"
[[ -z "$MSG" ]] && exit 0
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${ADMIN_ID}" \
  -d parse_mode="Markdown" \
  --data-urlencode text="$MSG" > /dev/null
NOTIFY
chmod +x "$NOTIFY_SCRIPT"

# ---- bot.sh : polling bot for commands ----
cat > "$BOT_SCRIPT" <<'BOTEOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/bot.conf"
API="https://api.telegram.org/bot${BOT_TOKEN}"
OFFSET=0

send() {
    curl -s -X POST "${API}/sendMessage" \
        -d chat_id="$1" \
        -d parse_mode="Markdown" \
        --data-urlencode text="$2" > /dev/null
}

is_admin() { [[ "$1" == "$ADMIN_ID" ]]; }

while true; do
    UPDATES=$(curl -s "${API}/getUpdates?timeout=30&offset=$((OFFSET+1))")
    LEN=$(echo "$UPDATES" | jq '.result | length' 2>/dev/null)
    [[ -z "$LEN" ]] && { sleep 3; continue; }

    for ((i=0; i<LEN; i++)); do
        UPD=$(echo "$UPDATES" | jq ".result[$i]")
        UPDATE_ID=$(echo "$UPD" | jq '.update_id')
        OFFSET=$UPDATE_ID
        CHAT_ID=$(echo "$UPD" | jq '.message.chat.id')
        TEXT=$(echo "$UPD" | jq -r '.message.text // empty')
        [[ -z "$TEXT" ]] && continue

        if ! is_admin "$CHAT_ID"; then
            send "$CHAT_ID" "❌ Unauthorized. Ye bot sirf admin ke liye hai."
            continue
        fi

        CMD=$(echo "$TEXT" | awk '{print $1}')
        case "$CMD" in
            /start|/help)
                send "$CHAT_ID" "*RARETRICCKS Bot – Commands*
/adduser <username> <password> <days> <ip_limit> <gb_limit>
/deluser <username>
/listusers
/status"
                ;;
            /adduser)
                ARGS=$(echo "$TEXT" | cut -d' ' -f2-)
                if [[ -z "$ARGS" || "$ARGS" == "$TEXT" ]]; then
                    send "$CHAT_ID" "Usage:
/adduser <username> <password> <days> <ip_limit> <gb_limit>"
                    continue
                fi
                OUT=$(bash "$USER_MGR" add $ARGS 2>&1)
                send "$CHAT_ID" "✅ *Add user result:*
\`\`\`
$OUT
\`\`\`"
                ;;
            /deluser)
                UNAME=$(echo "$TEXT" | awk '{print $2}')
                if [[ -z "$UNAME" ]]; then
                    send "$CHAT_ID" "Usage: /deluser <username>"
                    continue
                fi
                OUT=$(bash "$USER_MGR" del "$UNAME" 2>&1)
                send "$CHAT_ID" "🗑️ *Delete user result:*
\`\`\`
$OUT
\`\`\`"
                ;;
            /listusers)
                OUT=$(bash "$USER_MGR" list 2>&1)
                send "$CHAT_ID" "📋 *Users:*
\`\`\`
$OUT
\`\`\`"
                ;;
            /status)
                UP=$(uptime -p 2>/dev/null)
                RAM=$(free -h | awk '/Mem:/ {print $3"/"$2}')
                DISK=$(df -h / | awk 'NR==2{print $3"/"$2}')
                send "$CHAT_ID" "🖥️ *Server Status*
Uptime: $UP
RAM: $RAM
Disk: $DISK"
                ;;
            *)
                send "$CHAT_ID" "Unknown command. /help bhejo."
                ;;
        esac
    done
done
BOTEOF
chmod +x "$BOT_SCRIPT"

# ---- systemd service so bot auto-runs & restarts ----
cat > "$BOT_SERVICE" <<EOF
[Unit]
Description=RARETRICCKS Telegram Bot
After=network.target

[Service]
ExecStart=/bin/bash $BOT_SCRIPT
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable raretriccks-bot >/dev/null 2>&1
systemctl restart raretriccks-bot

sleep 1
"$NOTIFY_SCRIPT" "✅ Telegram bot install ho gaya aur chal raha hai on *$(hostname)*."

echo ""
echo "==============================================="
echo " Telegram Bot LIVE hai."
echo " Apne bot ko Telegram par /help bhej ke test karo."
echo " Service manage karne ke commands:"
echo "   systemctl status raretriccks-bot"
echo "   systemctl restart raretriccks-bot"
echo "   journalctl -u raretriccks-bot -f"
echo "==============================================="
