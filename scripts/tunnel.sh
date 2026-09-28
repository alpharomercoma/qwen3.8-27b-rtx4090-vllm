#!/bin/bash
# MAC. Forward the pod's serving ports to this Mac over the direct SSH connection (no RunPod HTTPS proxy in the path).
#   127.0.0.1:18000 -> pod :8000 (SGLang / vLLM)    127.0.0.1:18080 -> pod :8080 (llama-server)
#   127.0.0.1:21434 -> pod :11434 (Ollama)
# usage: scripts/tunnel.sh        (foreground; Ctrl-C to close)   scripts/tunnel.sh -f  (background)
. "$(dirname "$0")/lib.sh"
exec ssh "${POD_SSH_OPTS[@]}" -o ServerAliveInterval=15 -o ExitOnForwardFailure=yes -N "$@" \
  -L 18000:127.0.0.1:8000 -L 18080:127.0.0.1:8080 -L 21434:127.0.0.1:11434 "$POD_SSH_HOST"
