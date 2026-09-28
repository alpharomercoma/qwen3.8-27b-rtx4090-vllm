#!/bin/bash
# POD. vLLM 0.30.0 in /workspace/venvs/vllm. The cu129 wheel runs on driver 570+ (CUDA 12.8) through CUDA minor-version
# compatibility; FlashInfer's JIT needs the apt cuda-nvcc-12-8 that bootstrap.sh installs. Idempotent.
set -euo pipefail
. /workspace/env.sh
V=0.30.0
WHEEL=vllm-$V+cu129-cp38-abi3-manylinux_2_28_x86_64.whl
WHEEL_SHA256=e98cb69659bfcfc849cf11ce0781a7161d40b02b51a6c3636924a5909f2aabcc   # GitHub's digest for the release asset
if ! /workspace/venvs/vllm/bin/python -c "import vllm, sys; sys.exit(vllm.__version__ != '$V')" 2>/dev/null; then
  mkdir -p /workspace/.cache/wheels
  W=/workspace/.cache/wheels/$WHEEL
  [ -f "$W" ] || curl -fsSL -o "$W" "https://github.com/vllm-project/vllm/releases/download/v$V/${WHEEL//+/%2B}"
  echo "$WHEEL_SHA256  $W" | sha256sum -c - || { rm -f "$W"; echo "vLLM wheel failed its checksum"; exit 1; }
  uv venv /workspace/venvs/vllm --python 3.11 --seed --allow-existing
  # dependencies come from PyPI and PyTorch's cu129 index over TLS (not hash-pinned)
  VIRTUAL_ENV=/workspace/venvs/vllm uv pip install --torch-backend=cu129 "$W"
fi
# uv takes torchcodec from PyPI, whose wheel is built for CUDA 13 (libnvrtc.so.13): vLLM then dies on import on a
# CUDA 12.8 driver. Swap in PyTorch's cu129 build of the same version.
if ! /workspace/venvs/vllm/bin/python -c "import torchcodec.decoders" 2>/dev/null; then
  TC=$(/workspace/venvs/vllm/bin/python -c "import importlib.metadata as m; print(m.version('torchcodec').split('+')[0])")
  VIRTUAL_ENV=/workspace/venvs/vllm uv pip install --reinstall-package torchcodec \
    --index-url https://download.pytorch.org/whl/cu129 "torchcodec==$TC+cu129"
fi
/workspace/venvs/vllm/bin/python -c "import torch, vllm; print('torch', torch.__version__, torch.version.cuda, torch.cuda.is_available(), torch.cuda.get_device_name(0)); print('vllm', vllm.__version__)"
echo INSTALL_VLLM_DONE
