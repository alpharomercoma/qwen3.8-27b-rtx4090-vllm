#!/bin/bash
# POD. Multi-user/multi-agent and cache-retention scenarios against the server that is already running.
# usage: bash run_extra.sh <config-tag> [port]      e.g. bash run_extra.sh int4-kv4-pin-h2 8000
. /workspace/env.sh
TAG=${1:?tag}; PORT=${2:-8000}; KEY=$(cat /workspace/.api_key); OUT=/workspace/results/raw
LG="uv run -q --with aiohttp python /workspace/4090/bench/loadgen.py --base-url http://127.0.0.1:$PORT/v1 --api-key $KEY
    --model qwen3.8-27b --engine vllm --tag $TAG --out $OUT"
P=/workspace/4090/bench/pi_opening_request.json
$LG team --groups 3,3,3,3 8,1,1,1,1 --shared-tokens 6000 --prefix-request $P
$LG retention --background 0 --delays 5 60 300 900 --prefix-request $P
$LG retention --background 4 --delays 5 30 60 120 240 480 --prefix-request $P
$LG retention --background 8 --delays 5 30 60 120 240 480 --prefix-request $P
echo EXTRA_DONE
