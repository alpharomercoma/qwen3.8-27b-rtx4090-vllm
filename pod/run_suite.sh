#!/bin/bash
# POD. Start a serving config, wait until it answers, then run the same load-generator suite against it from the pod
# itself (no network in the measurement). Results: /workspace/results/raw/*.jsonl + *.summary.json, plus VRAM snapshots.
# usage: bash run_suite.sh <config> [scenarios...]     scenarios default: prefill decode agent
#   SKIP_START=1  reuse the server that is already up
set -uo pipefail
. /workspace/env.sh
CFG=${1:?config}; shift
SCEN=${*:-prefill decode agent}
OUT=/workspace/results/raw; mkdir -p $OUT
KEY=$(cat /workspace/.api_key)
case "$CFG" in
  lcpp-*)   ENGINE=llamacpp; URL=http://127.0.0.1:8080/v1; API=openai; HEALTH=http://127.0.0.1:8080/health ;;
  heretic*) ENGINE=vllm;     URL=http://127.0.0.1:8000/v1; API=openai; HEALTH=http://127.0.0.1:8000/health; MODEL=${MODEL:-qwen3.8-27b-heretic} ;;
  original) ENGINE=vllm;     URL=http://127.0.0.1:8000/v1; API=openai; HEALTH=http://127.0.0.1:8000/health ;;
  vllm-*)   ENGINE=vllm;     URL=http://127.0.0.1:8000/v1; API=openai; HEALTH=http://127.0.0.1:8000/health ;;
  sglang-*) ENGINE=sglang;   URL=http://127.0.0.1:8000/v1; API=openai; HEALTH=http://127.0.0.1:8000/health ;;
  ollama-*) ENGINE=ollama;   URL=http://127.0.0.1:11434;   API=ollama; HEALTH=http://127.0.0.1:11434/api/version ;;
  *) echo "unknown engine for $CFG"; exit 2 ;;
esac
TAG=${CFG#*-}${TAG_SUFFIX:-}   # TAG_SUFFIX (e.g. "-h2") keeps runs from different hosts apart
MODEL=${MODEL:-qwen3.8-27b}; [ "$ENGINE" = ollama ] && MODEL=${OLLAMA_MODEL:-qwen3.8:27b}

if [ "${SKIP_START:-0}" != 1 ]; then
  bash /workspace/4090/pod/serve.sh "$CFG" || exit 1
fi
t0=$(date +%s)
until curl -sf -H "Authorization: Bearer $KEY" "$HEALTH" >/dev/null; do
  sleep 3
  if ! tmux has-session -t serve 2>/dev/null; then echo "server exited:"; tail -n 30 /workspace/logs/serve_${CFG}.log; exit 1; fi
  if [ $(( $(date +%s) - t0 )) -gt 1200 ]; then echo "not ready after 20 min"; tail -n 30 /workspace/logs/serve_${CFG}.log; exit 1; fi
done
echo "ready after $(( $(date +%s) - t0 )) s"
if [ "$ENGINE" = ollama ]; then  # load the model and pin it before measuring
  curl -s $URL/api/generate -d "{\"model\":\"$MODEL\",\"prompt\":\"hi\",\"stream\":false,\"options\":{\"num_predict\":1}}" >/dev/null
fi
snap() { nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader | sed "s/^/$1 /" >> $OUT/${ENGINE}_${TAG}_vram.txt; }
snap "after_load $(date -u +%FT%TZ)"

LG="uv run -q --with aiohttp python /workspace/4090/bench/loadgen.py --base-url $URL --api $API --api-key $KEY ${LG_EXTRA:-}
    --model $MODEL --engine $ENGINE --tag $TAG --out $OUT"
for s in $SCEN; do
  case $s in
    prefill) $LG prefill --lengths 1024 4096 8192 16384 32768 --reps 3 ;;
    decode)  $LG decode --concurrency 1 2 4 8 16 --input-len 1024 --output-len 256 --rounds 3 ;;
    agent)   $LG agent --users 1 2 4 8 --turns 8 --tool-tokens 1500 --output-len 150 \
                 --prefix-request /workspace/4090/bench/pi_opening_request.json ;;
    agent16) $LG agent --users 12 16 --turns 8 --tool-tokens 1500 --output-len 150 \
                 --prefix-request /workspace/4090/bench/pi_opening_request.json ;;
  esac
  snap "after_$s $(date -u +%FT%TZ)"
done
echo SUITE_DONE $CFG
