#!/bin/bash
# POD. Start the gateway: authz.py (tmux "authz") and Caddy (tmux "gateway") on 127.0.0.1:8443.
# usage: bash run.sh           Keys: keys.sh. Allowed Vercel project: authz.env. The model server keeps its own key.
set -euo pipefail
. /workspace/env.sh
HERE=/workspace/4090/pod/gateway
PORT=8443
BIN=/workspace/bin/caddy
if [ ! -x $BIN ]; then
  mkdir -p /workspace/bin
  # pinned release, checked against the SHA-512 in Caddy's caddy_2.10.2_checksums.txt before anything is extracted
  V=2.10.2
  SHA512=747df7ee74de188485157a383633a1a963fd9233b71fbb4a69ddcbcc589ce4e2cc82dacf5dbbe136cb51d17e14c59daeb5d9bc92487610b0f3b93680b2646546
  curl -fsSL -o /tmp/caddy.tgz "https://github.com/caddyserver/caddy/releases/download/v$V/caddy_${V}_linux_amd64.tar.gz"
  echo "$SHA512  /tmp/caddy.tgz" | sha512sum -c - || { echo "Caddy download failed its checksum"; exit 1; }
  tar --no-same-owner -xzf /tmp/caddy.tgz -C /workspace/bin caddy && rm -f /tmp/caddy.tgz
fi
if ! /workspace/venvs/gateway/bin/python -c "import jwt, cryptography" 2>/dev/null; then
  uv venv -q /workspace/venvs/gateway --python 3.11 --allow-existing
  VIRTUAL_ENV=/workspace/venvs/gateway uv pip install -q "pyjwt[crypto]>=2.10"
fi
[ -s /workspace/.team_api_keys ] || bash $HERE/keys.sh add team >/dev/null
[ -s /workspace/.api_key ] || { echo "no /workspace/.api_key (run bootstrap.sh)"; exit 1; }
grep -q __SET_AFTER $HERE/authz.env && echo "WARNING: authz.env has no Vercel project id; the web app will be rejected"
# tmux sessions inherit the tmux server's environment, not this shell's: settings go through env files on the
# container disk (mode 600), which also keeps keys out of the process list
( umask 077; printf 'GATEWAY_PORT=%s\nUPSTREAM_PORT=8000\nAUTHZ_PORT=8444\nUPSTREAM_API_KEY=%s\n' "$PORT" "$(cat /workspace/.api_key)" > /root/.gateway.env )
# Caddy ignores SIGHUP and binds with SO_REUSEPORT: a stale instance keeps answering a share of connections.
# Kill every instance by process and wait until the ports are free.
tmux kill-session -t gateway 2>/dev/null || true; tmux kill-session -t authz 2>/dev/null || true
killp "/workspace/bin/caddy run"; killp "gateway/authz.py"
for _ in $(seq 20); do ss -ltn | grep -qE ":($PORT|8444) " || break; sleep 0.5; done
tmux new-session -d -s authz "set -a; . $HERE/authz.env; set +a; exec /workspace/venvs/gateway/bin/python $HERE/authz.py >> /workspace/logs/authz.log 2>&1"
tmux new-session -d -s gateway "exec $BIN run --envfile /root/.gateway.env --config $HERE/Caddyfile --adapter caddyfile > /workspace/logs/gateway.log 2>&1"
for _ in $(seq 30); do ss -ltn | grep -q "127.0.0.1:8444 " && ss -ltn | grep -q ":$PORT " && break; sleep 0.5; done
n=$(ss -ltnp | grep -c ":$PORT .*caddy" || true)
[ "$n" = 1 ] || { echo "ERROR: $n caddy listeners on :$PORT"; tail -5 /workspace/logs/gateway.log; exit 1; }
ss -ltn | grep -q "127.0.0.1:8444 " || { echo "ERROR: authz is not listening"; tail -5 /workspace/logs/authz.log; exit 1; }
echo "gateway on 127.0.0.1:$PORT (1 listener), authz on 127.0.0.1:8444; keys: $(bash $HERE/keys.sh list | cut -d' ' -f1 | xargs)"
