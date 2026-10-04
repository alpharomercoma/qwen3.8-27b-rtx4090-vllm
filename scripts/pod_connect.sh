#!/bin/bash
# MAC. Point the scripts at a RunPod pod: read its public SSH address and SSH host keys through RunPod's own SSH proxy
# (whose host key is pinned in scripts/runpod_known_hosts), then write .pod_env and .pod_known_hosts. Run it once per pod, and again when a restarted pod gets a new address.
# usage: scripts/pod_connect.sh <pod-id>-<suffix>@ssh.runpod.io        (the "SSH" command RunPod shows for the pod)
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
PROXY=${1:?usage: scripts/pod_connect.sh <pod-id>-<suffix>@ssh.runpod.io}
[[ $PROXY =~ ^[a-z0-9]+-[a-f0-9]+@ssh\.runpod\.io$ ]] || { echo "expected something like abc123xyz-64411cf3@ssh.runpod.io"; exit 2; }
# The proxy only gives an interactive terminal: send commands to it and pick the marked lines out of the echo.
out=$( { printf '%s\n' \
  'printf "@@ADDR %s %s\n" "$RUNPOD_PUBLIC_IP" "$RUNPOD_TCP_PORT_22"' \
  'for f in /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ecdsa_key.pub; do [ -f $f ] && printf "@@KEY %s\n" "$(cut -d" " -f1,2 $f)"; done' \
  'exit'; } | ssh -tt -o ConnectTimeout=20 -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile="$HERE/scripts/runpod_known_hosts" -i ~/.ssh/id_ed25519 "$PROXY" 2>/dev/null | tr -d '\r' )
# the terminal puts escape sequences (e.g. ESC[?2004l) before output lines, so match the markers anywhere; the echoed
# commands cannot match because they contain %s where the values go
addr=$(printf '%s\n' "$out" | grep -oE '@@ADDR [0-9.]+ [0-9]+$' | tail -1 | cut -d' ' -f2,3)
keys=$(printf '%s\n' "$out" | grep -oE '@@KEY (ssh-ed25519|ecdsa-sha2-nistp256) [A-Za-z0-9+/=]+$' | cut -d' ' -f2,3)
[ -n "$addr" ] || { echo "no answer with the pod's address. Is the pod running with SSH over TCP exposed? If ssh reports a"
                    echo "changed host key for ssh.runpod.io, check RunPod's current key before updating scripts/runpod_known_hosts."; exit 1; }
[ -n "$keys" ] || { echo "could not read the pod's SSH host keys"; exit 1; }
ip=${addr% *}; port=${addr#* }
printf 'POD_SSH_HOST=root@%s\nPOD_SSH_PORT=%s\nPOD_SSH_PROXY=%s\n' "$ip" "$port" "$PROXY" > "$HERE/.pod_env"
printf '%s\n' "$keys" | sed "s|^|[$ip]:$port |" > "$HERE/.pod_known_hosts"
echo "pod at root@$ip port $port; $(wc -l < "$HERE/.pod_known_hosts" | tr -d ' ') host key(s) pinned in .pod_known_hosts"
