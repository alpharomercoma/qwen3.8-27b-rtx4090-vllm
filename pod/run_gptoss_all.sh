#!/bin/bash
# POD. gpt-oss-20b on SGLang, llama.cpp and Ollama with the same suites as vLLM, then restore the Qwen team server.
# Decode keeps ignore_eos (fixed 256-token outputs); agent cells stop naturally (gpt-oss cannot be forced past its
# end-of-call marker).
. /workspace/env.sh
S=/workspace/4090/pod/run_suite.sh
for cfg in sglang-gptoss lcpp-gptoss ollama-gptoss; do
  MODEL=gpt-oss-20b OLLAMA_MODEL=gpt-oss:20b TAG_SUFFIX=-h2 bash $S $cfg prefill decode > /workspace/logs/suite_$cfg.log 2>&1
  MODEL=gpt-oss-20b OLLAMA_MODEL=gpt-oss:20b TAG_SUFFIX=-h2 SKIP_START=1 LG_EXTRA=--no-ignore-eos bash $S $cfg agent >> /workspace/logs/suite_$cfg.log 2>&1
  echo "$cfg finished $(date -u +%T)"
done
bash /workspace/4090/pod/serve.sh vllm-int4-kv4-pin
echo ALL_GPTOSS_DONE
