#!/bin/bash
# POD. Make a fresh container on this network volume ready: everything on /workspace survives a pod change, but apt
# packages, uv, the hf CLI and anything under /root do not. Idempotent. usage: bash /workspace/4090/pod/bootstrap.sh
set -euxo pipefail
mkdir -p /workspace/logs /workspace/bin /workspace/models
cp /workspace/4090/pod/env.sh /workspace/env.sh
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# tmux/jq: job control; zstd: Ollama installer; CUDA 12.8 compiler + headers: FlashInfer JIT in the cu129 vLLM needs nvcc >= 12.8
apt-get install -y -qq tmux jq zstd cmake cuda-nvcc-12-8 cuda-cudart-dev-12-8 cuda-cccl-12-8 cuda-nvrtc-dev-12-8 \
  libcublas-dev-12-8 libcurand-dev-12-8 > /workspace/logs/bootstrap_apt.log 2>&1
# uv: a pinned release, checked against the SHA-256 GitHub lists for it, instead of piping an installer into sh
UV_VERSION=0.12.19
UV_SHA256=23bf5552d220e0842b65c862097b2ebaeba0064b74eda5e565e77fd25969d8c8
if ! command -v uv >/dev/null; then
  curl -fsSL -o /tmp/uv.tgz "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-x86_64-unknown-linux-gnu.tar.gz"
  echo "$UV_SHA256  /tmp/uv.tgz" | sha256sum -c - || { echo "uv download failed its checksum"; exit 1; }
  tar -xzf /tmp/uv.tgz -C /tmp && mkdir -p /root/.local/bin &&
    install -m 755 /tmp/uv-x86_64-unknown-linux-gnu/uv /tmp/uv-x86_64-unknown-linux-gnu/uvx /root/.local/bin/
  rm -rf /tmp/uv.tgz /tmp/uv-x86_64-unknown-linux-gnu
fi
. /workspace/env.sh
command -v hf >/dev/null || uv tool install -q "huggingface_hub[hf_xet]"
[ -f /workspace/.api_key ] || { python3 -c "import secrets;print('sk-4090-'+secrets.token_hex(20))" > /workspace/.api_key; chmod 600 /workspace/.api_key; }
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
# everything start.sh relies on, or stop here with a clear failure
for tool in tmux jq uv hf; do command -v "$tool" >/dev/null || { echo "bootstrap: $tool is missing"; exit 1; }; done
/usr/local/cuda-12.8/bin/nvcc --version | tail -1
[ -s /workspace/.api_key ] || { echo "bootstrap: /workspace/.api_key is missing"; exit 1; }
echo BOOTSTRAP_DONE
