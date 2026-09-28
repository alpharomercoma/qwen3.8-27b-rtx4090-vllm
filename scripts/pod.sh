#!/bin/bash
# MAC. Run commands on the pod over direct TCP SSH.   usage: scripts/pod.sh <<'CMDS' ... CMDS   or  scripts/pod.sh <<<'cmd'
# Address and pinned host keys come from scripts/pod_connect.sh (via scripts/lib.sh). POD_TIMEOUT kills a hung call
# (default 600 s).
. "$(dirname "$0")/lib.sh"
{ echo 'export GIT_PAGER=cat PAGER=cat PATH=/root/.local/bin:/usr/local/cuda/bin:$PATH; [ -f /workspace/env.sh ] && . /workspace/env.sh'; cat; } | \
  ssh "${POD_SSH_OPTS[@]}" -o ConnectTimeout=20 -o ServerAliveInterval=15 "$POD_SSH_HOST" 'bash -s' 2>&1 &
pid=$!; ( sleep "${POD_TIMEOUT:-600}"; kill $pid 2>/dev/null ) & killer=$!
wait $pid; rc=$?; kill $killer 2>/dev/null; exit $rc
