#!/bin/bash
# ==============================================================================
# RARETRICCKS MULTI PROTOCOL - 07-xray-vless.sh
# Xray-core install + VLESS multi-transport config:
#   WS+TLS (via HAProxy 443)      WS+NoTLS (via HAProxy 80)
#   XHTTP mode=auto + TLS (9443)  TCP plain (9880)
#   TCP+TLS (9444)                gRPC (9005)
# ==============================================================================
set -e
source /etc/raretriccks/00-common.sh

DOMAIN=$(require_domain_or_die)

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}   ${PANEL_NAME} - XRAY (V2RAY) VLESS SETUP          ${NC}"
echo -e "${CYAN}====================================================${NC}"

if ! command -v xray &>/dev/null; then
    echo -e "${BLUE}Installing Xray-core...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
fi

mkdir -p /usr/local/etc/xray

# NOTE: Xray ka official installer ek khaali/stub config.json ("{}") bana deta hai
# install ke time. Isliye sirf "file exists?" check karna galat hai — hamesha
# check karo ki asli inbounds config already likhi hui hai ya nahi.
if ! grep -q '"inbounds"' "$XRAY_CONFIG" 2>/dev/null; then
cat << XR_EOF > "$XRAY_CONFIG"
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "ws-tls-in",
      "listen": "127.0.0.1",
      "port": ${XRAY_WS_TLS_PORT},
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "${V2RAY_WS_PATH}" } }
    },
    {
      "tag": "ws-plain-in",
      "listen": "127.0.0.1",
      "port": ${XRAY_WS_PLAIN_PORT},
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "${V2RAY_WS_PATH}" } }
    },
    {
      "tag": "xhttp-tls-in",
      "listen": "0.0.0.0",
      "port": ${XRAY_XHTTP_PORT},
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem",
            "keyFile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
          }]
        },
        "xhttpSettings": { "path": "${V2RAY_XHTTP_PATH}", "mode": "auto" }
      }
    },
    {
      "tag": "tcp-plain-in",
      "listen": "0.0.0.0",
      "port": ${XRAY_TCP_PLAIN_PORT},
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "tcp", "security": "none" }
    },
    {
      "tag": "tcp-tls-in",
      "listen": "0.0.0.0",
      "port": ${XRAY_TCP_TLS_PORT},
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem",
            "keyFile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
          }]
        }
      }
    },
    {
      "tag": "grpc-in",
      "listen": "0.0.0.0",
      "port": ${XRAY_GRPC_PORT},
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "tag": "direct" } ]
}
XR_EOF
fi

# ------------------------------------------------------------------
# Xray "nobody" user se chalta hai, lekin Let's Encrypt certs
# root-only (0700) permission ke saath store hote hain. ACL laga ke
# nobody ko sirf read+traverse access de rahe hain — har run par
# (idempotent), aur is har SSL renewal ke baad bhi zaroori hai.
# ------------------------------------------------------------------
if [[ -d "/etc/letsencrypt/live/${DOMAIN}" ]]; then
    command -v setfacl &>/dev/null || apt-get install -y acl >/dev/null 2>&1
    setfacl -R -m u:nobody:rx /etc/letsencrypt/live /etc/letsencrypt/archive 2>/dev/null || true
    setfacl -R -m u:nobody:r "/etc/letsencrypt/archive/${DOMAIN}"/*.pem 2>/dev/null || true
fi

systemctl enable xray
systemctl restart xray

echo -e "\n${GREEN}[DONE] Xray live with 6 inbounds. Users add karne ke liye 09-user-manager.sh use karo.${NC}"
