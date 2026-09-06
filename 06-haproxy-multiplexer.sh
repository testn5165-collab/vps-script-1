#!/bin/bash
# ==============================================================================
# RARETRICCKS MULTI PROTOCOL - 06-haproxy-multiplexer.sh
# Multi-port HAProxy multiplexer:
#   SSH_WS_TLS_PORTS   -> TLS terminated here, SSH-WS+SSL (+ V2Ray-WS+TLS on
#                          path /v2ray)
#   SSH_WS_PLAIN_PORTS -> plain HTTP, SSH-WS (+ V2Ray-WS non-TLS on /v2ray)
# Dono arrays 00-common.sh mein edit ho sakte hain. Har port same backend
# (ws-proxy.py, 127.0.0.1:${SSH_WS_INTERNAL_PORT}) par hi jaata hai, isliye
# sirf ek python process se saare ports serve hote hain.
# ==============================================================================
set -e
source /etc/raretriccks/00-common.sh

DOMAIN=$(require_domain_or_die)

if [[ ! -f "/etc/haproxy/certs/haproxy.pem" ]]; then
    echo -e "${RED}[ERROR] Cert bundle missing. Pehle 02-ssl-cert.sh chalao.${NC}"
    exit 1
fi

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}   ${PANEL_NAME} - HAPROXY MULTI-PORT MULTIPLEXER    ${NC}"
echo -e "${CYAN}====================================================${NC}"

mkdir -p /etc/haproxy/certs

{
cat << HAP_HEAD
global
    log /dev/log local0
    maxconn 20000
    tune.ssl.default-dh-param 2048
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 10s
    timeout client  86400s
    timeout server  86400s

HAP_HEAD

# ---- One TLS frontend per port in SSH_WS_TLS_PORTS ----
for p in "${SSH_WS_TLS_PORTS[@]}"; do
cat << HAP_TLS_FE
frontend ft_tls_${p}
    bind *:${p} ssl crt /etc/haproxy/certs/haproxy.pem alpn h2,http/1.1
    mode http
    option forwardfor
    acl is_v2ray path_beg ${V2RAY_WS_PATH}
    use_backend bk_xray_ws_tls if is_v2ray
    default_backend bk_ssh_ws

HAP_TLS_FE
done

# ---- One plain frontend per port in SSH_WS_PLAIN_PORTS ----
for p in "${SSH_WS_PLAIN_PORTS[@]}"; do
cat << HAP_PLAIN_FE
frontend ft_plain_${p}
    bind *:${p}
    mode http
    option forwardfor
    acl is_v2ray path_beg ${V2RAY_WS_PATH}
    use_backend bk_xray_ws_plain if is_v2ray
    default_backend bk_ssh_ws

HAP_PLAIN_FE
done

cat << HAP_BACKENDS
backend bk_ssh_ws
    mode http
    server ssh_ws 127.0.0.1:${SSH_WS_INTERNAL_PORT} check

backend bk_xray_ws_plain
    mode http
    server xray_ws_plain 127.0.0.1:${XRAY_WS_PLAIN_PORT} check

backend bk_xray_ws_tls
    mode http
    server xray_ws_tls 127.0.0.1:${XRAY_WS_TLS_PORT} check
HAP_BACKENDS
} > /etc/haproxy/haproxy.cfg

haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl enable haproxy
systemctl restart haproxy

echo -e "\n${GREEN}[DONE] HAProxy multiplexer live.${NC}"
echo -e "${CYAN}TLS ports   (SSH-WS+SSL / V2Ray-WS+TLS)  : ${SSH_WS_TLS_PORTS[*]}${NC}"
echo -e "${CYAN}Plain ports (SSH-WS / V2Ray-WS non-TLS)  : ${SSH_WS_PLAIN_PORTS[*]}${NC}"
