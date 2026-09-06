#!/bin/bash
# ==============================================================================
# RARETRICCKS MULTI PROTOCOL - 02-ssl-cert.sh
# Let's Encrypt cert issue + HAProxy/stunnel/Xray ke liye bundle taiyar karta hai.
# Prerequisite: domain A record VPS IP par pointed ho, port 80 free ho.
# ==============================================================================
set -e
source /etc/raretriccks/00-common.sh

DOMAIN=$(require_domain_or_die)

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}   ${PANEL_NAME} - SSL SETUP (${DOMAIN})           ${NC}"
echo -e "${CYAN}====================================================${NC}"

systemctl stop haproxy 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

certbot certonly --standalone --preferred-challenges http --agree-tos \
    --register-unsafely-without-email -d "$DOMAIN"

if [[ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    echo -e "${RED}[ERROR] SSL fail. DNS/A-record check karo.${NC}"
    exit 1
fi

mkdir -p /etc/haproxy/certs
build_bundle() {
    cat "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" \
        "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" > /etc/haproxy/certs/haproxy.pem
    chmod 600 /etc/haproxy/certs/haproxy.pem
}
build_bundle

# Xray (XHTTP/TCP-TLS dedicated ports) apna cert seedha LE path se padhega,
# isliye alag copy ki zarurat nahi - config me seedha /etc/letsencrypt/live/... use hoga.

mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat << HOOK_EOF > /etc/letsencrypt/renewal-hooks/deploy/raretriccks-reload.sh
#!/bin/bash
DOM="${DOMAIN}"
mkdir -p /etc/haproxy/certs
cat "/etc/letsencrypt/live/\${DOM}/fullchain.pem" "/etc/letsencrypt/live/\${DOM}/privkey.pem" > /etc/haproxy/certs/haproxy.pem
chmod 600 /etc/haproxy/certs/haproxy.pem
systemctl restart haproxy 2>/dev/null
systemctl restart xray 2>/dev/null
systemctl restart stunnel4 2>/dev/null
HOOK_EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/raretriccks-reload.sh

echo -e "\n${GREEN}[DONE] SSL issued for ${DOMAIN}. HAProxy cert bundle ready + auto-renew hook installed.${NC}"
