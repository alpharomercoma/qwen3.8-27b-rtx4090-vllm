# shellcheck shell=bash
# MAC. Sourced by the scripts that talk to the pod. The pod's address (.pod_env) and its SSH host keys
# (.pod_known_hosts) are written by scripts/pod_connect.sh; both files are gitignored. Host keys are checked strictly,
# so a connection to anything else at that address fails instead of silently trusting it.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [ ! -f "$HERE/.pod_env" ] || [ ! -s "$HERE/.pod_known_hosts" ]; then
  echo "No pod configured: run scripts/pod_connect.sh <pod-id>-<suffix>@ssh.runpod.io first." >&2
  exit 1
fi
set -a; . "$HERE/.pod_env"; set +a
: "${POD_SSH_HOST:?POD_SSH_HOST missing in .pod_env}" "${POD_SSH_PORT:?POD_SSH_PORT missing in .pod_env}"
# shellcheck disable=SC2034  # used by the scripts that source this file
POD_SSH_OPTS=(-S none -o ControlMaster=no -o LogLevel=ERROR -o StrictHostKeyChecking=yes
              -o UserKnownHostsFile="$HERE/.pod_known_hosts" -o IdentitiesOnly=yes -i "$HOME/.ssh/id_ed25519"
              -p "$POD_SSH_PORT")
