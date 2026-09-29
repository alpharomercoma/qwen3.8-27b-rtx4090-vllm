#!/bin/bash
# POD. Start one serving configuration in tmux session "serve" (any previous one is stopped first).
# usage: bash /workspace/4090/pod/serve.sh <config>        list: bash serve.sh list
# Production configs: heretic, original (the models in models.sh). The rest are benchmark configs (docs/benchmarks).
# Every engine listens on 127.0.0.1 only; the Mac reaches it through scripts/tunnel.sh.
# Ports: llama.cpp 8080, vLLM / SGLang 8000, Ollama 11434. Bearer key: /workspace/.api_key (Ollama has none).
set -euo pipefail
. /workspace/env.sh
CFG=${1:?config name}
KEY=$(cat /workspace/.api_key)
NAME=qwen3.8-27b
G=/workspace/models/qwen38-gguf
LOG=/workspace/logs/serve_${CFG}.log

# Common llama-server flags. -cms 1024: a hybrid (Gated DeltaNet) model can only reuse a prefix up to a saved state
# checkpoint; the default spacing of 8192 tokens throws most multi-turn reuse away.
LCPP="llama-server --alias $NAME --host 127.0.0.1 --port 8080 --api-key $KEY -ngl 99 -fa on --jinja --metrics
      -b 2048 -ub 2048 --ctx-checkpoints 32 -cms 1024 --cache-ram 16384"

# vLLM on 24 GB: drop the vision tower, fp8 KV, fp16 Gated DeltaNet state (halves 147 MiB per sequence),
# 2048-token prefill chunks so decode streams keep flowing while another user's prompt is prefilled.
VLLM_SERVE="env PATH=/workspace/venvs/vllm/bin:/usr/local/cuda-12.8/bin:$PATH CUDA_HOME=/usr/local/cuda-12.8 PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True /workspace/venvs/vllm/bin/vllm serve"
VLLM_FLAGS="--host 127.0.0.1 --port 8000 --api-key $KEY --language-model-only --gpu-memory-utilization 0.95
      --kv-cache-dtype fp8 --mamba-ssm-cache-dtype float16 --max-num-batched-tokens 2048
      --reasoning-parser qwen3 --enable-auto-tool-choice --tool-call-parser qwen3_coder
      --enable-prompt-tokens-details --compilation-config '{\"max_cudagraph_capture_size\":32}'"
VLLM="$VLLM_SERVE /workspace/models/qwen38-redhat-int4 --served-model-name $NAME $VLLM_FLAGS"
# Production: whichever model in models.sh, with the measured team settings of vllm-int4-kv4-pin (int4 KV on Triton
# attention, 4.5 GiB KV pool pinned = 246,094 tokens, 64k per request, 16 running, prefix caching)
. /workspace/4090/pod/models.sh
PROD_FLAGS="--max-model-len 65536 --max-num-seqs 16 --enable-prefix-caching --mamba-cache-mode align
            --kv-cache-dtype int4_per_token_head --attention-backend TRITON_ATTN"
prod() { model_preset "$1" && echo "$VLLM_SERVE $MODEL_DIR --served-model-name $MODEL_ID $VLLM_FLAGS $PROD_FLAGS"; }

# SGLang 0.5.19 (last CUDA 12 build) on the same INT4 checkpoint as vLLM. bf16 GDN state halves it; the state pool
# (--language-model-only exists in 0.5.19 but only for MuseGlimmer: the Qwen3.8 vision tower stays loaded, +1 GB vs vLLM)
# ratio follows the cookbook formula r = S x state_tokens / L = 3 x 2394 / ~15k ~= 0.5 instead of the 0.9 default.
SGL="env PATH=/root/venvs/sglang/bin:/usr/local/cuda-12.8/bin:$PATH CUDA_HOME=/usr/local/cuda-12.8 /root/venvs/sglang/bin/python -m sglang.launch_server
      --model-path /workspace/models/qwen38-redhat-int4 --served-model-name $NAME --host 127.0.0.1 --port 8000
      --api-key $KEY --context-length 65536 --mem-fraction-static 0.88 --max-running-requests 16
      --kv-cache-dtype fp8_e4m3 --mamba-ssm-dtype bfloat16 --mamba-full-memory-ratio 0.5 --chunked-prefill-size 2048
      --reasoning-parser qwen3 --tool-call-parser qwen3_coder --enable-metrics"

# ---- gpt-oss-20b (MoE, 3.6B active; 12 full-attention + 12 sliding-window layers, no recurrent state).
# Same engines, each on its defaults for this architecture: bf16 KV (24 KiB/token), no GDN/mamba flags.
OSS=/workspace/models/gpt-oss-20b
OSS_GGUF=/workspace/models/gpt-oss-20b-gguf/gpt-oss-20b-MXFP4.gguf  # ggml-org GGUF; Ollama's names the arch "gptoss", which llama.cpp rejects
VLLM_OSS="env PATH=/workspace/venvs/vllm/bin:/usr/local/cuda-12.8/bin:$PATH CUDA_HOME=/usr/local/cuda-12.8 PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
      /workspace/venvs/vllm/bin/vllm serve $OSS --served-model-name gpt-oss-20b --host 127.0.0.1 --port 8000 --api-key $KEY
      --max-model-len 65536 --max-num-seqs 16 --max-num-batched-tokens 2048 --enable-prefix-caching
      --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai --enable-prompt-tokens-details
      --compilation-config '{\"max_cudagraph_capture_size\":32}' --kv-cache-memory-bytes 6442450944"
SGL_OSS="env PATH=/root/venvs/sglang/bin:/usr/local/cuda-12.8/bin:$PATH CUDA_HOME=/usr/local/cuda-12.8 /root/venvs/sglang/bin/python -m sglang.launch_server
      --model-path $OSS --served-model-name gpt-oss-20b --host 127.0.0.1 --port 8000 --api-key $KEY --context-length 65536
      --mem-fraction-static 0.85 --max-running-requests 16 --cuda-graph-max-bs-decode 16 --chunked-prefill-size 2048
      --reasoning-parser gpt-oss --tool-call-parser gpt-oss --enable-metrics"

case "$CFG" in
  list) grep -E '^  [a-z0-9_-]+\)' "$0" | sed 's/).*//'; exit 0 ;;
  # ---- PRODUCTION (web app + pi/opencode through pod/gateway); start.sh picks one
  heretic)  CMD="$(prod heretic) --kv-cache-memory-bytes 4831838208" ;;
  original) CMD="$(prod original) --kv-cache-memory-bytes 4831838208" ;;
  # candidate: 1 GiB more KV (~300k tokens) for heavy multi-agent load; see docs/ARCHITECTURE.md for the stress run
  heretic-kv55) CMD="$(prod heretic) --kv-cache-memory-bytes 5905580032" ;;
  # ---- llama.cpp: quant ladder at the same 64k shared pool (--kv-unified: one pool for all slots; a long session can
  #      use what idle slots are not using, but when the sum of live contexts overflows the pool, requests FAIL)
  lcpp-q4kxl)   CMD="$LCPP -m $G/Qwen3.8-27B-UD-Q4_K_XL.gguf -c 65536 -np 8 --kv-unified -ctk q8_0 -ctv q8_0" ;;
  lcpp-iq4xs)   CMD="$LCPP -m $G/Qwen3.8-27B-UD-IQ4_XS.gguf  -c 65536 -np 8 --kv-unified -ctk q8_0 -ctv q8_0" ;;
  lcpp-q5km)    CMD="$LCPP -m $G/Qwen3.8-27B-UD-Q5_K_M.gguf  -c 65536 -np 8 --kv-unified -ctk q8_0 -ctv q8_0" ;;
  # ---- llama.cpp: capacity variants of the recommended file
  lcpp-q4kxl-128k) CMD="$LCPP -m $G/Qwen3.8-27B-UD-Q4_K_XL.gguf -c 131072 -np 8 --kv-unified -ctk q8_0 -ctv q8_0" ;;
  lcpp-q4kxl-f16kv) CMD="$LCPP -m $G/Qwen3.8-27B-UD-Q4_K_XL.gguf -c 65536 -np 8 --kv-unified" ;;
  lcpp-q4kxl-mtp) CMD="$LCPP -m $G/Qwen3.8-27B-UD-Q4_K_XL.gguf -c 65536 -np 8 --kv-unified -ctk q8_0 -ctv q8_0
                    --spec-type draft-mtp -md $G/MTP/mtp-Qwen3.8-27B-Q4_0.gguf --spec-draft-n-max 3" ;;
  # ---- llama.cpp: fixed per-slot caps (no shared pool): each slot owns ctx/np tokens, nothing can overflow another
  lcpp-q4kxl-4x32k) CMD="$LCPP -m $G/Qwen3.8-27B-UD-Q4_K_XL.gguf -c 131072 -np 4 --no-kv-unified -ctk q8_0 -ctv q8_0" ;;
  lcpp-iq4xs-6x32k) CMD="$LCPP -m $G/Qwen3.8-27B-UD-IQ4_XS.gguf  -c 196608 -np 6 --no-kv-unified -ctk q8_0 -ctv q8_0" ;;
  # ---- vLLM: W4A16 (Marlin) INT4 checkpoint
  vllm-int4)     CMD="$VLLM --max-model-len 65536 --max-num-seqs 16 --enable-prefix-caching --mamba-cache-mode align" ;;
  vllm-int4-nopc) CMD="$VLLM --max-model-len 65536 --max-num-seqs 16" ;;
  # MTP at fp8 KV does NOT boot at 65k: the MTP head + graphs leave 1.91 GiB of KV, less than one 65k request needs
  vllm-int4-mtp) CMD="$VLLM --max-model-len 65536 --max-num-seqs 16 --enable-prefix-caching --mamba-cache-mode align
                    --speculative-config '{\"method\":\"mtp\",\"num_speculative_tokens\":2}'" ;;
  # ---- vLLM: bigger KV pool for more simultaneous agents (int4 per-token-head KV on the Triton attention backend,
  #      0.97 of VRAM; the pod runs no display, so the last 0.02 is safe)
  vllm-int4-kv4) CMD="$VLLM --max-model-len 65536 --max-num-seqs 16 --enable-prefix-caching --mamba-cache-mode align
                   --kv-cache-dtype int4_per_token_head --attention-backend TRITON_ATTN --gpu-memory-utilization 0.97" ;;
  # fp8 KV (FlashInfer: fast long-prompt prefill) at 0.97 of VRAM
  vllm-int4-097) CMD="$VLLM --max-model-len 65536 --max-num-seqs 16 --enable-prefix-caching --mamba-cache-mode align
                   --gpu-memory-utilization 0.97" ;;
  # RECOMMENDED team config. KV memory pinned instead of --gpu-memory-utilization: vLLM sizes the pool from a profiling
  # run whose activation estimate changed with cache state (2.7 GiB on the first host, 0.5 GiB with a warm torch-compile
  # cache on the second), and the low estimate let fp8 at 0.97 hit a runtime OOM. 4.5 GiB leaves ~1 GB of headroom.
  vllm-int4-kv4-pin) CMD="$VLLM --max-model-len 65536 --max-num-seqs 16 --enable-prefix-caching --mamba-cache-mode align
                   --kv-cache-dtype int4_per_token_head --attention-backend TRITON_ATTN --kv-cache-memory-bytes 4831838208" ;;
  vllm-int4-kv8) CMD="$VLLM --max-model-len 65536 --max-num-seqs 16 --enable-prefix-caching --mamba-cache-mode align
                   --kv-cache-dtype int8_per_token_head --attention-backend TRITON_ATTN --gpu-memory-utilization 0.97" ;;
  vllm-int4-kv4-mtp) CMD="$VLLM --max-model-len 65536 --max-num-seqs 16 --enable-prefix-caching --mamba-cache-mode align
                   --kv-cache-dtype int4_per_token_head --attention-backend TRITON_ATTN --gpu-memory-utilization 0.97
                   --speculative-config '{\"method\":\"mtp\",\"num_speculative_tokens\":2}'" ;;
  # ---- SGLang
  # default radix strategy reserves 5 GDN state slots per request: with 12 slots SGLang caps itself at 2 running requests
  sglang-int4-default) CMD="$SGL --cuda-graph-max-bs-decode 16" ;;
  # extra_buffer_lazy (4 slots/request) x 8 requests = 32 slots = 2.4 GB of state: KV shrinks to 34.6k tokens and CUDA
  # graph capture crashes. no_buffer = 3 slots/request, but it requires the overlap scheduler off. With the vision tower
  # loaded and prefill CUDA graphs on, the first 2k-token prefill ran out of memory (SGLang's second process holds 448 MB).
  # 8 running (24 slots) leaves a 23.5k-token KV pool, smaller than one 32k prompt; 4 running (12 slots) is the balance.
  sglang-int4-r8)    CMD="$SGL --cuda-graph-max-bs-decode 8 --max-running-requests 8 --mamba-radix-cache-strategy no_buffer
                       --disable-overlap-schedule --max-mamba-cache-size 24 --cuda-graph-backend-prefill disabled" ;;
  sglang-int4)       CMD="$SGL --cuda-graph-max-bs-decode 4 --max-running-requests 4 --mamba-radix-cache-strategy no_buffer
                       --disable-overlap-schedule --max-mamba-cache-size 12 --cuda-graph-backend-prefill disabled" ;;
  sglang-int4-eager) CMD="$SGL --disable-cuda-graph" ;;
  # SGLang >= 0.5.20 on a CUDA 13 host: one byte buffer split dynamically between full-attn KV and GDN state instead
  # of fixed per-request state reservations (the reason 0.5.19 capped at 4 running). Needs the Triton backends.
  # fp8 KV + unified memory fails to compile on sm89 (Triton attention gets the pool's raw uint8 bytes: "only int8
  # supported!" in tl.dot), so the unified configs use bf16 KV.
  sglang-int4-um)    CMD="$SGL --enable-unified-memory --attention-backend triton --linear-attn-backend triton
                       --max-running-requests 16 --cuda-graph-max-bs-decode 16 --cuda-graph-backend-prefill disabled
                       --kv-cache-dtype bf16" ;;
  # unified memory still derives max_running_requests from a nominal state cache (10 slots / 5 per request = 2);
  # this variant sets the state budget and strategy explicitly
  sglang-int4-um16)  CMD="$SGL --enable-unified-memory --attention-backend triton --linear-attn-backend triton
                       --max-running-requests 16 --cuda-graph-max-bs-decode 16 --cuda-graph-backend-prefill disabled
                       --kv-cache-dtype bf16 --mamba-radix-cache-strategy no_buffer --disable-overlap-schedule
                       --max-mamba-cache-size 48 --mamba-full-memory-ratio 1.5 --mem-fraction-static 0.90" ;;
  sglang-int4-um-i8) CMD="$SGL --enable-unified-memory --attention-backend triton --linear-attn-backend triton
                       --max-running-requests 16 --cuda-graph-max-bs-decode 16 --cuda-graph-backend-prefill disabled
                       --kv-cache-dtype bf16 --enable-int8-mamba-checkpoint" ;;
  # ---- gpt-oss-20b
  vllm-gptoss)   CMD="$VLLM_OSS" ;;
  sglang-gptoss) CMD="$SGL_OSS" ;;
  lcpp-gptoss)   CMD="${LCPP/--alias $NAME/--alias gpt-oss-20b} -m $OSS_GGUF -c 131072 -np 8 --kv-unified" ;;
  ollama-gptoss) CMD="env OLLAMA_NUM_PARALLEL=4 OLLAMA_CONTEXT_LENGTH=32768 OLLAMA_KV_CACHE_TYPE=f16 bash /workspace/4090/pod/ollama_serve.sh" ;;
  # ---- Ollama: its own scheduler; parallel slots and KV type are server env vars
  ollama-p4)  CMD="env OLLAMA_NUM_PARALLEL=4 OLLAMA_CONTEXT_LENGTH=32768 bash /workspace/4090/pod/ollama_serve.sh" ;;
  ollama-p8)  CMD="env OLLAMA_NUM_PARALLEL=8 OLLAMA_CONTEXT_LENGTH=32768 bash /workspace/4090/pod/ollama_serve.sh" ;;
  *) echo "unknown config $CFG"; exit 2 ;;
esac

tmux kill-session -t serve 2>/dev/null || true
tmux kill-session -t ollama 2>/dev/null || true
killp "llama-server|vllm serve|ollama serve|sglang.launch_server"
for _ in $(seq 60); do nvidia-smi --query-compute-apps=pid --format=csv,noheader | grep -q . || break; sleep 1; done
CMD=$(echo $CMD)   # fold the multi-line flag blocks onto one line
echo "$(date -u +%FT%TZ) $CFG: ${CMD//$KEY/<key>}" | tee -a /workspace/logs/serve_history.log
tmux new-session -d -s serve "exec $CMD > $LOG 2>&1"
echo "started $CFG -> $LOG"
