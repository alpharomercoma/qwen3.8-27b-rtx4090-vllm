# pod/: runs on the RunPod GPU pod

Copied to `/workspace/4090/pod` by `scripts/push.sh`. Every script starts with a comment saying what it does.
Step-by-step use: [docs/DEPLOY.md](../docs/DEPLOY.md) and [docs/OPERATIONS.md](../docs/OPERATIONS.md).

## The production service

| File | What it is |
|---|---|
| `start.sh` | Brings everything up, skipping finished steps: bootstrap → vLLM install → model download → vLLM → gateway → tunnel |
| `env.sh` | Sourced by every script: caches on `/workspace`, `PATH`, and `killp` (kill by pattern, never tmux) |
| `bootstrap.sh` | Fresh container: apt tools, CUDA 12.8 compiler, uv, `hf`, vLLM's own key in `/workspace/.api_key` |
| `install_vllm.sh` | vLLM 0.30.0 (CUDA 12.9 build) in `/workspace/venvs/vllm`, with the CUDA 12.9 `torchcodec` |
| `fetch_model.sh` | Downloads `JC1DA/Qwen3.8-27B-heretic-ara-W4A16` (AutoRound W4A16 of the official Heretic model) at a pinned commit and checks it |
| `qwen38-heretic-ara-w4a16.sha256` | SHA-256 of every file of that commit |
| `serve.sh` | Starts one named server config in tmux `serve`. Production: `serve.sh heretic`. `serve.sh list` shows all |
| `gateway/Caddyfile` | The gateway on `127.0.0.1:8443`: `/v1/*` only, asks `authz.py`, calls vLLM with vLLM's key |
| `gateway/authz.py` | Allows team API keys (`/workspace/.team_api_keys`) and the web app's Vercel OIDC token |
| `gateway/authz.env` | Which Vercel team, project and environments may call the API (not secret) |
| `gateway/keys.sh` | `add <label>`, `list`, `revoke <label>` for team API keys |
| `gateway/run.sh` | Starts `authz.py` and Caddy in tmux `authz` and `gateway`; creates the first key (`team`) if none exists |
| `gateway/edge_tunnel.sh` | Keeps the reverse SSH tunnel to the edge open (tmux `edge`); `pubkey` prints the key the edge must allow |

## Benchmarks (docs/benchmarks)

| File | What it is |
|---|---|
| `run_suite.sh` | Start a config, wait for it, run the load generator's prefill / decode / agent scenarios |
| `stress_kv.sh` | Heavy multi-agent load while sampling GPU memory: does a KV pool size survive? |
| `llamabench.sh` | llama.cpp quant ladder (`llama-bench`, `llama-batched-bench`) |
| `ollama_serve.sh` | Ollama for the engine comparison |
| `install_sglang.sh`, `fix_sglang_cu129.sh`, `install_sglang_cu13.sh` | SGLang for the engine comparison (CUDA 12.8 and 13 hosts) |
| `run_extra.sh`, `run_gptoss_all.sh`, `run_gptoss_retry.sh` | One-off batches from the study (retention runs, gpt-oss-20b) |
