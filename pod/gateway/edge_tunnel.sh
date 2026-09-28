#!/bin/bash
# POD. Keep a reverse SSH tunnel open to the edge server (alphaexperiments.com). Its Caddy reaches this pod's
# gateway at 127.0.0.1:18443 on the edge; the pod only dials out and exposes no port of its own.
# usage: bash edge_tunnel.sh          (tmux session "edge"; reconnects by itself)
#        bash edge_tunnel.sh pubkey   (print the public key the edge server must allow; see edge/install.sh)
set -euo pipefail
EDGE=${EDGE_HOST:-alphaexperiments.com}
KEY=/workspace/.secrets/edge_tunnel_ed25519
KNOWN=/workspace/4090/edge/known_hosts   # the edge server's host keys, pinned in the repo
mkdir -p /workspace/.secrets && chmod 700 /workspace/.secrets
[ -f $KEY ] || ssh-keygen -q -t ed25519 -N "" -C "heretic-pod-$(hostname)" -f $KEY
chmod 600 $KEY
if [ "${1:-}" = pubkey ]; then cat $KEY.pub; exit 0; fi
tmux kill-session -t edge 2>/dev/null || true
. /workspace/env.sh; killp "ssh .*heretic-tunnel@"
# ExitOnForwardFailure: if the edge still holds the old forward (dead connection not yet noticed), exit and retry
# instead of staying connected without a tunnel. The edge drops dead clients after ~45 s (ClientAlive*).
tmux new-session -d -s edge "while true; do
  ssh -N -T -i $KEY -o IdentitiesOnly=yes -o UserKnownHostsFile=$KNOWN -o StrictHostKeyChecking=yes \
      -o Compression=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=15 \
      -R 127.0.0.1:18443:127.0.0.1:8443 heretic-tunnel@$EDGE;
  echo \"\$(date -u +%FT%TZ) tunnel down (exit \$?), retrying in 5 s\"; sleep 5;
done >> /workspace/logs/edge_tunnel.log 2>&1"
sleep 4; tmux has-session -t edge && echo "tunnel loop running (log /workspace/logs/edge_tunnel.log)"; tail -2 /workspace/logs/edge_tunnel.log 2>/dev/null || true
