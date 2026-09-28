#!/bin/bash
# POD. Second half of the SGLang CUDA 12 install (see install_sglang.sh): drop the CUDA 13 wheels the first resolve
# pulled in (including nvcc 13, whose JIT output a 570 driver cannot load), then add torch / cuDNN / sglang-kernel /
# deep-gemm built for CUDA 12.9. The uv cache lives in RAM so the 20 GB root disk cannot fill up.
set -x
export VIRTUAL_ENV=/root/venvs/sglang PATH=/root/.local/bin:$PATH UV_CACHE_DIR=/dev/shm/uv-cache UV_LINK_MODE=copy
uv pip uninstall nvidia-cublas nvidia-cuda-cupti nvidia-cuda-nvrtc nvidia-cuda-runtime nvidia-cudnn-cu13 nvidia-cufft \
  nvidia-cufile nvidia-curand nvidia-cusolver nvidia-cusparse nvidia-cusparselt-cu13 nvidia-nccl-cu13 nvidia-nvshmem-cu13 \
  nvidia-nvtx nvidia-nvjitlink nvidia-cutlass-dsl-libs-cu13 nvidia-cuda-nvcc nvidia-cuda-crt nvidia-nvvm nvidia-cuda-nvdisasm
df -h / | tail -1
uv pip install --no-deps torch==2.13.0 --index-url https://download.pytorch.org/whl/cu129
uv pip install nvidia-cudnn-cu12 --index-url https://download.pytorch.org/whl/cu129
uv pip install --force-reinstall --no-deps sglang-kernel --index-url https://docs.sglang.ai/whl/cu129/
uv pip install --force-reinstall --no-deps sgl-deep-gemm --index-url https://docs.sglang.ai/whl/cu129/
rm -rf /dev/shm/uv-cache; df -h / | tail -1
uv pip check 2>&1 | head -8
/root/venvs/sglang/bin/python -c "import torch, sglang, sgl_kernel; print('torch', torch.__version__, torch.version.cuda, torch.cuda.is_available()); print('sglang', sglang.__version__)"
echo INSTALL_EXIT=$?
