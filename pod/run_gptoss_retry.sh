#!/bin/bash
# POD. Second pass for gpt-oss-20b: SGLang with 16-token probes, llama.cpp on ggml-org's MXFP4 GGUF (Ollama's GGUF
# names the architecture 'gptoss', which upstream llama.cpp rejects). Restores the Qwen team server at the end.
. /workspace/env.sh
S=/workspace/4090/pod/run_suite.sh
hf download ggml-org/gpt-oss-20b-GGUF gpt-oss-20b-MXFP4.gguf --local-dir /workspace/models/gpt-oss-20b-gguf > /workspace/logs/dl_gptoss_gguf.log 2>&1
for cfg in sglang-gptoss lcpp-gptoss ollama-gptoss; do
  MODEL=gpt-oss-20b OLLAMA_MODEL=gpt-oss:20b TAG_SUFFIX=-h2 LG_EXTRA="--probe-max-tokens 16" bash $S $cfg prefill decode > /workspace/logs/suite_$cfg.log 2>&1
  MODEL=gpt-oss-20b OLLAMA_MODEL=gpt-oss:20b TAG_SUFFIX=-h2 SKIP_START=1 LG_EXTRA="--no-ignore-eos --probe-max-tokens 16" bash $S $cfg agent >> /workspace/logs/suite_$cfg.log 2>&1
  echo "$cfg finished $(date -u +%T)"
done
bash /workspace/4090/pod/serve.sh vllm-int4-kv4-pin
echo ALL_GPTOSS_RETRY_DONE
