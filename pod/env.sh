# shellcheck shell=bash
# POD. Sourced by every pod script (bootstrap.sh copies it to /workspace/env.sh). Keeps caches, uv's Python builds and
# tools on /workspace: the container disk is small and is wiped when the pod is re-provisioned.
export HF_HOME=/workspace/.cache/hf UV_CACHE_DIR=/workspace/.cache/uv UV_PYTHON_INSTALL_DIR=/workspace/.uv-python
export PATH=/root/.local/bin:/workspace/bin:/usr/local/cuda/bin:$PATH
# Kill processes whose command line matches a pattern, but never tmux: the tmux server keeps the command line of the
# first "tmux new-session ... <command>" that started it, so a plain `pkill -f "vllm serve"` can kill the tmux server
# and with it every session (vLLM, gateway, tunnel).
killp() { local p; for p in $(pgrep -f "$1"); do case "$(cat /proc/$p/comm 2>/dev/null)" in tmux*) ;; *) kill "$p" 2>/dev/null ;; esac; done; }
[ -d /workspace/llama.cpp/build/bin ] && export PATH=/workspace/llama.cpp/build/bin:$PATH
true
