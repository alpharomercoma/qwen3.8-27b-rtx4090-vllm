#!/bin/bash
# MAC. The on-pod agent and team scenarios, run from this Mac through the public URL (edge TLS, SSH tunnel, gateway
# auth), so the difference to the on-pod baseline is what the network path costs. Results: results/raw/*heretic-public*
# usage: HERETIC_API_KEY=... scripts/bench_public.sh
set -euo pipefail
: "${HERETIC_API_KEY:?export HERETIC_API_KEY}"
cd "$(dirname "$0")/.."
LG=(uv run -q --with aiohttp python bench/loadgen.py --base-url https://alphaexperiments.com/heretic-inference/v1
    --api openai --api-key "$HERETIC_API_KEY" --model qwen3.8-27b-heretic --engine vllm --tag heretic-public --out results/raw)
"${LG[@]}" agent --users 1 4 8 12 16 --turns 8 --tool-tokens 1500 --output-len 150 --prefix-request bench/pi_opening_request.json
"${LG[@]}" team --groups 3,3,3,3 8,1,1,1,1 --prefix-request bench/pi_opening_request.json
echo BENCH_PUBLIC_DONE
