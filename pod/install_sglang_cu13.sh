#!/bin/bash
# POD. SGLang latest (0.5.20, CUDA 13 build) for hosts with driver >= 580. Plain resolve, no cu129 swap needed.
# On the container disk (/root) to spare the volume quota; the uv cache lives in RAM so the root disk cannot fill.
set -x
export PATH=/root/.local/bin:$PATH UV_CACHE_DIR=/dev/shm/uv-cache UV_LINK_MODE=copy
rm -rf /root/venvs/sglang; uv venv /root/venvs/sglang --python 3.11 --seed
VIRTUAL_ENV=/root/venvs/sglang uv pip install --prerelease=allow "sglang==0.5.20"
rm -rf /dev/shm/uv-cache; df -h / | tail -1; du -sh /root/venvs/sglang
/root/venvs/sglang/bin/python -c "import torch, sglang; print('torch', torch.__version__, torch.version.cuda, torch.cuda.is_available()); print('sglang', sglang.__version__)"
echo INSTALL_EXIT=$?
