#!/bin/bash
# POD. SGLang 0.5.19 = last CUDA 12 release (0.5.20 is CUDA 13 only; this host's driver 570 tops out at CUDA 12.8,
# CUDA 12.9 wheels run through minor-version compatibility). Installed on the container disk to spare the volume quota.
# Follows SGLang's documented CUDA 12 route: install, then force-reinstall torch + kernels from the cu129 indexes
# (0.5.19's metadata asks for cuda-python>=13, which no cu129 torch satisfies, so a single resolve cannot work).
set -x
export PATH=/root/.local/bin:/usr/local/cuda/bin:$PATH UV_CACHE_DIR=/root/uv-cache
rm -rf /root/venvs/sglang; uv venv /root/venvs/sglang --python 3.11 --seed
export VIRTUAL_ENV=/root/venvs/sglang
uv pip install --prerelease=allow "sglang==0.5.19"
uv cache clean
uv pip install --force-reinstall torch==2.13.0 torchaudio==2.11.0 torchvision --index-url https://download.pytorch.org/whl/cu129
uv pip install --force-reinstall --no-deps sglang-kernel --index-url https://docs.sglang.ai/whl/cu129/
uv pip install --force-reinstall --no-deps sgl-deep-gemm --index-url https://docs.sglang.ai/whl/cu129/
uv cache clean
uv pip list 2>/dev/null | grep -iE "^(sglang|sglang-kernel|sgl-deep-gemm|torch|flashinfer-python|triton|cuda-python|cuda-bindings) "
du -sh /root/venvs/sglang
/root/venvs/sglang/bin/python -c "import torch, sglang; print('torch', torch.__version__, torch.version.cuda, torch.cuda.is_available()); print('sglang', sglang.__version__)"
echo INSTALL_EXIT=$?
