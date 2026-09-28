#!/bin/bash
# POD. Bring the whole service up after a pod (re)start: tools, vLLM, the model, the server, the gateway, the tunnel.
# Idempotent: finished steps are skipped. Stops at the first failed step, so the tunnel never opens in front of a
# broken gateway. usage: bash /workspace/4090/pod/start.sh      log: /workspace/logs/start.log
# As a RunPod container start command: bash -c "bash /workspace/4090/pod/start.sh; sleep infinity"
set -uo pipefail
mkdir -p /workspace/logs /workspace/bin /workspace/models
exec > >(tee -a /workspace/logs/start.log) 2>&1
echo "== $(date -u +%FT%TZ) start"
P=/workspace/4090/pod
fail() { echo "!! $*"; echo "== $(date -u +%FT%TZ) stopped"; exit 1; }
healthy() { curl -sf -o /dev/null -H "Authorization: Bearer $(cat /workspace/.api_key)" http://127.0.0.1:8000/health; }

# bootstrap.sh provides all of these; run it unless every one is present
export PATH=/root/.local/bin:$PATH
if ! command -v tmux jq uv hf >/dev/null || [ ! -x /usr/local/cuda-12.8/bin/nvcc ] || [ ! -s /workspace/.api_key ]; then
  bash $P/bootstrap.sh > /workspace/logs/bootstrap.log 2>&1 || fail "bootstrap failed: /workspace/logs/bootstrap.log"
fi
cp $P/env.sh /workspace/env.sh   # always the version that came with this code
. /workspace/env.sh
bash $P/install_vllm.sh | tail -2 || fail "vLLM install failed"
[ -f /workspace/models/qwen38-heretic-ara-w4a16/.download-complete ] ||
  { bash $P/fetch_model.sh | tail -1 || fail "model download failed"; }
if ! healthy; then
  bash $P/serve.sh heretic || fail "serve.sh failed"
  for _ in $(seq 180); do   # first boot compiles and captures graphs: ~4 min
    healthy && break
    tmux has-session -t serve 2>/dev/null || { tail -20 /workspace/logs/serve_heretic.log; fail "vLLM exited"; }
    sleep 5
  done
fi
healthy || fail "vLLM is not healthy after 15 min; not starting the gateway (tail /workspace/logs/serve_heretic.log)"
echo "vLLM ready"
bash $P/gateway/run.sh || fail "gateway failed to start (tail /workspace/logs/gateway.log /workspace/logs/authz.log)"
bash $P/gateway/edge_tunnel.sh || fail "tunnel failed to start (tail /workspace/logs/edge_tunnel.log)"
# End to end through the edge: without a key the gateway answers 401; 502 means the tunnel is not connected yet.
for _ in $(seq 12); do
  code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' https://alphaexperiments.com/heretic-inference/v1/models)
  [ "$code" = 401 ] && break
  sleep 5
done
[ "$code" = 401 ] || fail "vLLM and the gateway run, but the public URL answers $code: is this pod's tunnel key installed on the edge (docs/DEPLOY.md step 4)? tail /workspace/logs/edge_tunnel.log"
echo "== $(date -u +%FT%TZ) up: https://alphaexperiments.com/heretic-inference"
