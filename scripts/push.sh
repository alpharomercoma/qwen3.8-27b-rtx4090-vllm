#!/bin/bash
# MAC. Copy this repo's pod/, bench/ and edge/ (the tunnel needs edge/known_hosts) to /workspace/4090 on the pod
# (direct SSH; the pod has no rsync).
. "$(dirname "$0")/lib.sh"
tar -C "$HERE" -czf - --exclude __pycache__ pod bench edge | \
  ssh "${POD_SSH_OPTS[@]}" "$POD_SSH_HOST" 'mkdir -p /workspace/4090 && tar --no-same-owner -C /workspace/4090 -xzf - && ls /workspace/4090'
