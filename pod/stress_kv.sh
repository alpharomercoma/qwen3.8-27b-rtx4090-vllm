#!/bin/bash
# POD. Heavy multi-agent load against the running vLLM while sampling GPU memory every 0.5 s: does a KV pool size
# survive peak activations? usage: bash stress_kv.sh <tag>     results: /workspace/results/raw/*<tag>*, vram_<tag>.csv
set -uo pipefail
. /workspace/env.sh; cd /workspace/4090 || exit 1
TAG=${1:?tag}
KEY=$(cat /workspace/.api_key)
nvidia-smi --query-gpu=timestamp,memory.used --format=csv,noheader,nounits -lms 500 > /workspace/results/raw/vram_$TAG.csv &
SMI=$!
LG="uv run -q --with aiohttp python bench/loadgen.py --base-url http://127.0.0.1:8000/v1 --api openai --api-key $KEY --model qwen3.8-27b-heretic --engine vllm --tag $TAG --out /workspace/results/raw"
$LG agent --users 8 12 16 --turns 8 --tool-tokens 1500 --output-len 150 --prefix-request bench/pi_opening_request.json
$LG team --groups 3,3,3,3 8,1,1,1,1 --prefix-request bench/pi_opening_request.json
kill $SMI
echo "peak VRAM MiB: $(cut -d, -f2 /workspace/results/raw/vram_$TAG.csv | sort -n | tail -1) of $(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)"
grep -c -i "out of memory\|CUDA error" /workspace/logs/serve_*.log | tail -3
echo STRESS_DONE
