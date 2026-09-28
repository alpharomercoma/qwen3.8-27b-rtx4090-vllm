#!/bin/bash
# POD. Ollama server with benchmark-relevant settings from the environment (serve.sh sets the per-config ones).
. /workspace/env.sh
export OLLAMA_HOST=127.0.0.1:11434 OLLAMA_FLASH_ATTENTION=1 OLLAMA_KEEP_ALIVE=-1 OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL:-4} OLLAMA_CONTEXT_LENGTH=${OLLAMA_CONTEXT_LENGTH:-32768}
export OLLAMA_KV_CACHE_TYPE=${OLLAMA_KV_CACHE_TYPE:-q8_0}
env | grep ^OLLAMA_ | sort
exec ollama serve
