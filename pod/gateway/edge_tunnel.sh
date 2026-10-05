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
# ssh refuses a private key others can read. A RunPod network volume (FUSE) ignores chmod, so then use a copy on the
# container's own disk, which does honour it (rewritten at every start, so it follows the volume's key).
if [ "$(stat -c %a $KEY)" != 600 ]; then
  install -d -m 700 /root/.heretic && install -m 600 $KEY /root/.heretic/edge_tunnel_ed25519
  KEY=/root/.heretic/edge_tunnel_ed25519
fi
tmux kill-session -t edge 2>/dev/null || true
. /workspace/env.sh; killp "ssh .*heretic-tunnel@"
# ExitOnForwardFailure: if the edge still holds the old forward (dead connection not yet noticed), exit and retry
# instead of staying connected without a tunnel. The edge drops dead clients after ~45 s (ClientAlive*).
# Retry after 5 s, doubling up to 60 s while connections fail fast (a key the edge does not accept yet): the
# edge's firewall rate-limits new SSH connections, and hammering it gets every attempt refused.
tmux new-session -d -s edge "delay=5; while true; do
  t0=\$(date +%s)
  ssh -N -T -i $KEY -o IdentitiesOnly=yes -o UserKnownHostsFile=$KNOWN -o StrictHostKeyChecking=yes \
      -o Compression=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=15 \
      -R 127.0.0.1:18443:127.0.0.1:8443 heretic-tunnel@$EDGE; rc=\$?
  if [ \$((\$(date +%s) - t0)) -gt 60 ]; then delay=5; else delay=\$((delay * 2 > 60 ? 60 : delay * 2)); fi
  echo \"\$(date -u +%FT%TZ) tunnel down (exit \$rc), retrying in \$delay s\"; sleep \$delay;
done >> /workspace/logs/edge_tunnel.log 2>&1"
sleep 4; tmux has-session -t edge && echo "tunnel loop running (log /workspace/logs/edge_tunnel.log)"; tail -2 /workspace/logs/edge_tunnel.log 2>/dev/null || true
