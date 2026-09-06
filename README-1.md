# 🛡️ RARETRICCKS MULTI PROTOCOL

**Multi-protocol VPS tunneling panel** — SSH, SSH-WS, SSH+SSL, SSH-WS+SSL, and V2Ray (VLESS: WS / XHTTP / TCP / gRPC), all on one server, through a multi-port HAProxy multiplexer.

---

## 🚀 One-Click Installation

```bash
bash <(curl -Ls https://raw.githubusercontent.com/testn5165-collab/vps-script-1/main/install-all.sh) yourdomain.com
```

> Replace `yourdomain.com` with your real domain (its A record must point to your VPS IP, and port 80 must be free for SSL issuance).

After installation, launch the interactive menu (SSH and V2Ray management are separate submenus):

```bash
bash /etc/raretriccks/menu.sh
```

Or create a user directly from the command line:

```bash
bash /etc/raretriccks/09-user-manager.sh add <username> <password> <days> <ip_limit> <gb_limit>
```

Example:

```bash
bash /etc/raretriccks/09-user-manager.sh add grvpn-test7day ibrahim 7 2 Unlimited
```

---

## 📡 Ports Details

### SSH / SSH-WS (multi-port — the same account works on all of them)

| Type | Ports |
|---|---|
| **TLS (SSH-WS+SSL)** | `443, 2053, 2083, 2087, 2096, 8443, 445, 447, 777` |
| **Plain (SSH-WS, no SSL)** | `80, 8080, 8880, 2052, 2082, 2086, 2095` |
| **SSH Direct** | `22` |
| **SSH+SSL (raw, non-WS, via stunnel)** | `444` |
| **SSH Backup (Dropbear direct)** | `8022` |
| **Dropbear internal (WS backend)** | `109` (internal use) |

### V2Ray / Xray (VLESS)

| Transport | Port | TLS |
|---|---|---|
| WS | Every TLS port (list above) | ✅ TLS |
| WS | Every Plain port (list above) | ❌ Non-TLS |
| XHTTP (mode: auto) | `9443` | ✅ TLS |
| TCP | `9880` | ❌ Plain |
| TCP | `9444` | ✅ TLS |
| gRPC | `9005` | ❌ Plain (`serviceName=vless-grpc`) |

Paths: `/v2ray` (WS) • `/vless-xhttp` (XHTTP)

### Extra

| Service | Address |
|---|---|
| BadVPN UDPGW (Gaming/Calls) | `127.0.0.1:7300` |

---

## 🌐 Protocols Details

- **SSH Direct** — standard OpenSSH/Dropbear
- **SSH-WS** — SSH tunneled over WebSocket (HTTP upgrade), CDN/proxy-friendly
- **SSH-WS+SSL** — same as above, with TLS terminated at HAProxy
- **SSH+SSL (raw)** — SSH wrapped directly in TLS via stunnel (no WS layer)
- **V2Ray VLESS-WS** — both TLS and Non-TLS, same path (`/v2ray`) on every port
- **V2Ray VLESS-XHTTP** — `mode: auto` (packet-up/stream auto-negotiate)
- **V2Ray VLESS-TCP** — Plain and TLS variants
- **V2Ray VLESS-gRPC** — service-name based transport
- **DTunnel / HTTP-Injector compatible** — the same WS listener also accepts the CONNECT method

---

## ✨ Features

- A single HAProxy instance — 16 public ports (9 TLS + 7 plain), all sharing the same SSH-WS backend + V2Ray backend
- Automatic Let's Encrypt SSL + auto-renewal hook (auto-reloads HAProxy/Xray/stunnel)
- Unified account system — one command creates both SSH and V2Ray (UUID) at once
- Bandwidth (GB) and IP-limit tracking, with auto-lock on exceeding limits
- Built-in BadVPN UDPGW — fast UDP forwarding for gaming/calls
- Modular scripts — each protocol/component lives in its own `.sh` file, independently updatable
- DTunnel/HTTP-Injector custom payload support (same port, no extra config needed)

---

## 📂 File Structure

| File | Purpose |
|---|---|
| `00-common.sh` | Shared config, ports, colors, helper functions |
| `01-base-install.sh` | Base packages (haproxy, stunnel, dropbear, certbot, xray deps) |
| `02-ssl-cert.sh` | Let's Encrypt SSL + auto-renew hook |
| `03-dropbear-ssh.sh` | SSH Direct core |
| `04-ssh-ws.sh` | SSH-WebSocket engine |
| `05-ssh-ssl-stunnel.sh` | Raw SSH+SSL (non-WS) via stunnel |
| `06-haproxy-multiplexer.sh` | Multi-port HAProxy (TLS + plain) multiplexer |
| `07-xray-vless.sh` | Xray-core install + all VLESS inbounds |
| `08-badvpn-udpgw.sh` | BadVPN UDP Gateway |
| `09-user-manager.sh` | Unified SSH + V2Ray user create/delete |
| `10-dtunnel-support.sh` | DTunnel/HTTP-Injector payload compatibility patch |
| `menu.sh` | Interactive master menu — separate SSH and V2Ray management submenus |
| `install-all.sh` | Runs everything in correct order |

---

## ⚠️ Requirements

- Fresh Ubuntu/Debian VPS, root access
- Domain with A record pointed to VPS IP
- Port 80 temporarily free for SSL issuance

## ⚠️ Disclaimer

These scripts are intended for legitimate VPN/tunneling infrastructure only. You are responsible for your server, your users, and compliance with local laws.
