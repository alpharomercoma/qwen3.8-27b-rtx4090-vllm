#!/bin/bash
# MAC. Run a script as root on the edge server (alphaexperiments.com, the PengePassportPH Caddy host).
# usage: scripts/edge.sh <<'CMDS' ... CMDS        scripts/edge.sh install   (push edge/ and run edge/install.sh)
# The server's firewall rate-limits new SSH connections (6 per 30 s), so one multiplexed connection is reused.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p ~/.ssh/cm && chmod 700 ~/.ssh/cm
SSH=(ssh -o ControlMaster=auto -o ControlPath=~/.ssh/cm/edge-%C -o ControlPersist=10m -o ConnectTimeout=20
     -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HERE/edge/known_hosts" -o IdentitiesOnly=yes
     -i ~/.ssh/id_ed25519 root@alphaexperiments.com)
if [ "${1:-}" = install ]; then
  PUB=${POD_PUBKEY:?POD_PUBKEY (bash /workspace/4090/pod/gateway/edge_tunnel.sh pubkey, on the pod)}
  # The key comes from the pod, so treat it as untrusted: exactly "ssh-ed25519 <base64> [comment]" with a plain
  # comment, and it travels base64-encoded so no character of it is ever parsed by the remote root shell.
  [[ $PUB =~ ^ssh-ed25519\ [A-Za-z0-9+/]+=*(\ [A-Za-z0-9@._-]+)?$ ]] || { echo "POD_PUBKEY is not a plain ed25519 public key" >&2; exit 1; }
  B64=$(printf '%s' "$PUB" | base64 | tr -d '\n')
  tar -C "$HERE/edge" -czf - . | "${SSH[@]}" 'rm -rf /tmp/heretic-edge && mkdir -p /tmp/heretic-edge && tar --no-same-owner -C /tmp/heretic-edge -xzf -'
  "${SSH[@]}" "POD_PUBKEY=\"\$(printf %s $B64 | base64 -d)\" bash /tmp/heretic-edge/install.sh"
else
  "${SSH[@]}" 'bash -s'
fi
