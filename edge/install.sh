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
# The PengePassportPH template (deploy/caddy/Caddyfile.template) carries this import line; add it to a Caddyfile
# rendered before that change, right after the site's header block.
if ! grep -q 'import /etc/caddy/apps.d/\*.caddy' /etc/caddy/Caddyfile; then
  cp /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.before-heretic.$(date +%s)"
  python3 - <<'PY'
import re
p = "/etc/caddy/Caddyfile"
s = open(p).read()
marker = "\t# The app lives under its own path; other paths on this host stay free.\n"
if marker not in s:
    raise SystemExit("could not find where to add the import line; add 'import /etc/caddy/apps.d/*.caddy' by hand")
s = s.replace(marker, "\t# Other apps on this host (one file each, e.g. /heretic-inference from ~/4090/edge).\n"
              "\timport /etc/caddy/apps.d/*.caddy\n\n" + marker, 1)
open(p, "w").write(s)
PY
fi
caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile >/dev/null 2>&1 || { caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile; exit 1; }
systemctl reload caddy
echo "installed"
