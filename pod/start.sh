#!/bin/bash
# POD. Bring the whole service up after a pod (re)start: tools, vLLM, the model, the server, the gateway, the tunnel.
# Idempotent: finished steps are skipped. Stops at the first failed step, so the tunnel never opens in front of a
# broken gateway.
# usage: bash /workspace/4090/pod/start.sh [heretic|original]      log: /workspace/logs/start.log
#   The model (see models.sh) is remembered in /workspace/.model once it serves; without an argument the last one is
#   served (heretic the first time). Switching downloads the other model if needed (the old one keeps serving meanwhile),
#   then restarts vLLM: about a minute without answers. The gateway and tunnel restart for a few seconds.
# As a RunPod container start command: bash -c "bash /workspace/4090/pod/start.sh; sleep infinity"
set -uo pipefail
mkdir -p /workspace/logs /workspace/bin /workspace/models
exec > >(tee -a /workspace/logs/start.log) 2>&1
echo "== $(date -u +%FT%TZ) start"
P=/workspace/4090/pod
fail() { echo "!! $*"; echo "== $(date -u +%FT%TZ) stopped"; exit 1; }
# vLLM is up and serving the chosen model (not the other one, from before a switch)
serving() { curl -sf -H "Authorization: Bearer $(cat /workspace/.api_key)" http://127.0.0.1:8000/v1/models | grep -qF "\"id\":\"$MODEL_ID\""; }

# bootstrap.sh provides all of these; run it unless every one is present
export PATH=/root/.local/bin:$PATH
if ! command -v tmux jq uv hf >/dev/null || [ ! -x /usr/local/cuda-12.8/bin/nvcc ] || [ ! -s /workspace/.api_key ]; then
  bash $P/bootstrap.sh > /workspace/logs/bootstrap.log 2>&1 || fail "bootstrap failed: /workspace/logs/bootstrap.log"
fi
cp $P/env.sh /workspace/env.sh   # always the version that came with this code
. /workspace/env.sh
. $P/models.sh
MODEL=${1:-$(cat "$MODEL_CHOICE_FILE" 2>/dev/null || echo heretic)}
model_preset "$MODEL" || fail "unknown model '$MODEL' (one of: $MODELS)"
echo "model: $MODEL ($MODEL_REPO, served as $MODEL_ID)"
bash $P/install_vllm.sh | tail -2 || fail "vLLM install failed"
[ -f "$MODEL_DIR/.download-complete" ] ||
  { bash $P/fetch_model.sh "$MODEL" | tail -1 || fail "model download failed"; }
if ! serving; then
  bash $P/serve.sh "$MODEL" || fail "serve.sh failed"
  for _ in $(seq 180); do   # first boot compiles and captures graphs: ~4 min
    serving && break
    tmux has-session -t serve 2>/dev/null || { tail -20 "/workspace/logs/serve_$MODEL.log"; fail "vLLM exited"; }
    sleep 5
  done
fi
serving || fail "vLLM is not serving $MODEL_ID after 15 min; not starting the gateway (tail /workspace/logs/serve_$MODEL.log)"
# remember the choice only once it is really serving, so a failed switch does not stick for the next restart
echo "$MODEL" > "$MODEL_CHOICE_FILE.tmp" && mv "$MODEL_CHOICE_FILE.tmp" "$MODEL_CHOICE_FILE"
echo "vLLM ready: $MODEL_ID"
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
