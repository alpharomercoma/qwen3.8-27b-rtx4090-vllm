#!/bin/bash
# EDGE. Install /heretic-inference on the alphaexperiments.com server (the PengePassportPH Caddy host). Runs as root,
# started by scripts/edge.sh install, which copies this directory to /tmp/heretic-edge and passes the pod's tunnel public
# key in POD_PUBKEY. Idempotent.
set -euo pipefail
SRC=${SRC:-/tmp/heretic-edge}
: "${POD_PUBKEY:?POD_PUBKEY (from: bash /workspace/4090/pod/gateway/edge_tunnel.sh pubkey)}"
# One line, "ssh-ed25519 <base64> [plain comment]": anything else (a newline, options, quotes) is refused.
[[ $POD_PUBKEY =~ ^ssh-ed25519\ [A-Za-z0-9+/]+=*(\ [A-Za-z0-9@._-]+)?$ ]] || { echo "POD_PUBKEY is not a plain ed25519 public key"; exit 1; }

echo "== tunnel account"
id heretic-tunnel >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/heretic-tunnel --shell /usr/sbin/nologin heretic-tunnel
install -d -o heretic-tunnel -g heretic-tunnel -m 700 /var/lib/heretic-tunnel/.ssh
printf 'restrict,port-forwarding,permitlisten="127.0.0.1:18443" %s\n' "$POD_PUBKEY" > /var/lib/heretic-tunnel/.ssh/authorized_keys
chown heretic-tunnel:heretic-tunnel /var/lib/heretic-tunnel/.ssh/authorized_keys; chmod 600 /var/lib/heretic-tunnel/.ssh/authorized_keys
install -m 644 "$SRC/sshd-heretic-tunnel.conf" /etc/ssh/sshd_config.d/20-heretic-tunnel.conf
sshd -t
systemctl reload ssh

echo "== tcp tuning for the tunnel"
modprobe tcp_bbr 2>/dev/null || true
grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control || { echo "kernel has no BBR"; exit 1; }
install -m 644 "$SRC/sysctl-heretic-tunnel.conf" /etc/sysctl.d/60-heretic-tunnel.conf
printf 'tcp_bbr\n' > /etc/modules-load.d/heretic-tunnel.conf
sysctl -q -p /etc/sysctl.d/60-heretic-tunnel.conf

echo "== caddy"
install -d -m 755 /etc/caddy/apps.d
install -m 644 "$SRC/heretic-inference.caddy" /etc/caddy/apps.d/heretic-inference.caddy
# /etc/caddy/Caddyfile belongs to the server's other project, which may regenerate it. Make sure the import line is
# inside the alphaexperiments.com site block itself (an import elsewhere would not add our routes to this site), as
# its first line; rerun this script after such a regeneration.
SITE=${EDGE_SITE:-alphaexperiments.com}
python3 - "$SITE" /etc/caddy/Caddyfile <<'PY'
import re, shutil, sys, time
site, path = sys.argv[1], sys.argv[2]
s = open(path).read()
m = re.search(r"(?m)^" + re.escape(site) + r"\s*\{[ \t]*\n", s)
if not m:
    raise SystemExit(f"no '{site} {{' block in {path}: add 'import /etc/caddy/apps.d/*.caddy' inside it by hand")
depth, end = 1, None  # find the block's closing brace ({placeholders} are balanced, so plain counting works)
for i in range(m.end(), len(s)):
    depth += {"{": 1, "}": -1}.get(s[i], 0)
    if depth == 0:
        end = i
        break
if end is None:
    raise SystemExit(f"unbalanced braces after '{site} {{' in {path}")
if re.search(r"(?m)^\s*import /etc/caddy/apps\.d/\*\.caddy\s*$", s[m.end():end]):
    sys.exit(0)
shutil.copy(path, f"{path}.before-heretic.{int(time.time())}")
s = s[:m.end()] + "\t# Other apps on this host, one file each (/heretic-inference: ~/4090/edge/install.sh).\n" \
    "\timport /etc/caddy/apps.d/*.caddy\n\n" + s[m.end():]
open(path, "w").write(s)
print(f"added the import line to the {site} block")
PY
caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile >/dev/null 2>&1 || { caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile; exit 1; }
systemctl reload caddy
echo "installed"
