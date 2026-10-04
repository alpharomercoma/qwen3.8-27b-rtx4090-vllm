# Architecture

How a message gets from a browser or a CLI to the GPU and back, what each piece is, and how fast it is.
Setting it up from scratch: [DEPLOY.md](DEPLOY.md). Running it: [OPERATIONS.md](OPERATIONS.md). Why it is secure:
[SECURITY.md](SECURITY.md).

```
 browser ──HTTPS──▶ alphaexperiments.com  (edge: Caddy on the PengePassportPH server, Manila)
                     ├─ /heretic-inference*        ──HTTPS──▶ Vercel: Next.js chat app (apps/web), functions in sin1
                     │                                             │ server-side call, Vercel OIDC token
 pi / opencode ─HTTPS┴─ /heretic-inference/v1/* ◀──────HTTPS──────┘
      (team key)          │
                          ▼ 127.0.0.1:18443 on the edge = reverse SSH tunnel, opened by the pod (no inbound port)
                     RunPod pod (RTX 4090):  gateway 127.0.0.1:8443 (Caddy) ──asks──▶ authz.py :8444 (key or OIDC)
                                              └──▶ vLLM 127.0.0.1:8000 serving qwen3.8-27b-heretic or qwen3.8-27b
```

## The pieces

| Piece | Where | Listens on | What it is | Source |
|---|---|---|---|---|
| Edge | `alphaexperiments.com` (Huawei Cloud, Manila; shared with PengePassportPH) | 443 | Caddy with the domain's TLS certificate. Sends `/heretic-inference/v1/*` into the tunnel and the rest of `/heretic-inference*` to Vercel | `edge/heretic-inference.caddy` |
| Web app | Vercel project `heretic-inference` (team `alpharomercoma-projects`), functions in `sin1` | – | Next.js 16 + AI SDK 7 chat UI: password page, streaming chat, status pill | `apps/web/` |
| Tunnel | pod → `heretic-tunnel@alphaexperiments.com` | edge `127.0.0.1:18443` | `ssh -N -R`: the pod dials out and the edge gets a local port that leads to the pod's gateway | `pod/gateway/edge_tunnel.sh`, `edge/sshd-heretic-tunnel.conf` |
| Gateway | pod | `127.0.0.1:8443` | Caddy. Serves only `/v1/*` and `/healthz`, asks `authz.py` about every request, then calls vLLM with vLLM's own key | `pod/gateway/Caddyfile` |
| authz | pod | `127.0.0.1:8444` | Python. Allows a team API key or a Vercel OIDC token; everything else gets 401 | `pod/gateway/authz.py`, `authz.env`, `keys.sh` |
| vLLM | pod (RTX 4090, 24 GB) | `127.0.0.1:8000` | vLLM 0.30.0 serving one of two models (below) as `qwen3.8-27b-heretic` or `qwen3.8-27b` | `pod/serve.sh`, `pod/models.sh` |

## A chat message, step by step

1. The browser posts the conversation to `https://alphaexperiments.com/heretic-inference/api/chat`.
2. The edge forwards it to `heretic-inference.vercel.app` (same path; the app is built with `basePath: "/heretic-inference"`).
3. The Vercel function checks the session cookie, gets its OIDC token from Vercel, and calls
   `https://alphaexperiments.com/heretic-inference/v1/chat/completions` through the AI SDK's OpenAI-compatible provider.
4. The edge strips `/heretic-inference` and forwards `/v1/chat/completions` to `127.0.0.1:18443`, which the SSH tunnel
   carries to the pod's gateway.
5. The gateway asks `authz.py`: the token is checked against Vercel's signing keys and must be for this team, this
   project and the production environment. Allowed → the gateway swaps in vLLM's key and forwards.
6. vLLM streams tokens back the same way. The function turns them into the AI SDK's UI stream: reasoning, text, and
   timing metadata (time to first token, tokens per second, token counts) that the UI shows under each answer.

A CLI request is the same from step 4 on, with a team key instead of the OIDC token.

The web app does not need to be told which model runs: it asks the pod (`GET /v1/models`, remembered for a minute)
and sends chats to that id; the status poll carries the model's name and description to the UI.

## The two models

One runs at a time; `pod/start.sh heretic|original` chooses ([OPERATIONS.md → Switch model](OPERATIONS.md#switch-model)).

| | `heretic` (default) | `original` |
|---|---|---|
| What | The official Heretic (ARA) abliteration of Qwen3.8-27B (`heretic-org/Qwen3.8-27B-heretic-ara`; `trohrbaugh/…` has byte-identical weights). Answers requests the original refuses | Qwen3.8-27B as Qwen released it |
| Checkpoint | `JC1DA/Qwen3.8-27B-heretic-ara-W4A16`, commit `0a19146` | `RedHatAI/Qwen3.8-27B-INT4`, commit `91bd022` (weights unchanged since the benchmarks) |
| Quantization | 4-bit weights, 16-bit activations: AutoRound, group 128, symmetric, 1000 tuning iterations, from the official weights | 4-bit weights, 16-bit activations: AWQ smoothing then GPTQ (llm-compressor, `recipe.yaml`), group 128, symmetric |
| Size | 18.2 GiB; 16.59 GiB in VRAM (`--language-model-only` skips the vision tower) | 18.1 GiB |
| Kept in 16 bit | vision tower, MTP head, norms, conv1d, some `in_proj_a/b` | vision tower, `lm_head`, embeddings, `in_proj_a/b`, MTP head |
| vLLM kernel | Marlin INT4 (loads AutoRound as `inc`) | Marlin INT4 (loads it as `compressed-tensors`) |
| Served as | `qwen3.8-27b-heretic` | `qwen3.8-27b` |
| Measured | this page (2026-09-28) | [benchmarks/REPORT.md](benchmarks/REPORT.md) (2026-09-23/24, same settings: `vllm-int4-kv4-pin`) |

Both are pinned to a Hugging Face commit and every file is checked against `pod/models/<name>.sha256`.

## Server settings (both models)

| Setting | Value | Why |
|---|---|---|
| KV cache | int4 per token and head, Triton attention, pinned at 4.5 GiB = **246,094 tokens** shared by all requests | The benchmark study's recommended config; pinning avoids a runtime out-of-memory seen with `--gpu-memory-utilization` |
| Per request | 65,536 tokens (prompt + answer) | The pool holds 3.76 full-length requests, many more typical ones |
| Running at once | 16; more wait in vLLM's queue (first come, first served) | |
| Prefix caching | on (`--mamba-cache-mode align`) | Agents resend the same system prompt and history each turn |
| Reasoning and tools | `--reasoning-parser qwen3`, `--tool-call-parser qwen3_coder` | Reasoning in its own field; OpenAI tool calls |
| Sampling defaults | temperature 1.0, top-p 0.95, top-k 20 (the model's `generation_config.json`) | Used when a client sends none; the web app sends none |
| Web answer limit | 8,192 output tokens or 280 s, whichever comes first | Vercel Hobby stops a function at 300 s. Alone on the GPU 8,192 tokens take ~160 s (50 tok/s); with 8 agents busy (~26 tok/s) the time limit comes first. The answer then ends cleanly, keeps what it wrote, and says "Stopped before the end" |
| Not used | MTP speculative decoding | In the study it sped up one user (82 vs 52 tok/s) but slowed agents |

Why vLLM and not Ollama, llama.cpp or SGLang, and why this quant size: [benchmarks/REPORT.md](benchmarks/REPORT.md).
How Heretic and the original compare in answer quality and refusals: [EVAL.md](EVAL.md).

## Performance

Measured 2026-09-28 on the **Heretic** model with `bench/loadgen.py`, zero errors in every cell. The original model
with the same settings, measured on the pod in the benchmark study: 1 agent 0.8 s per turn at 50 tok/s, 8 agents
4.9 s at 30 tok/s, 16 agents 16.5 s at 6 tok/s ([benchmarks/REPORT.md → Capacity](benchmarks/REPORT.md#capacity-of-the-recommended-config)). "On the pod" talks to vLLM directly;
"Public URL" runs from a laptop in the Philippines through the edge, the tunnel and the gateway. Tables generated
by `python3 bench/service_tables.py` from `results/raw/vllm_heretic-*.summary.json`.

Agent sessions (pi's system prompt and tools, 8 turns, 1,500-token tool results, 150-token answers):

| Run | Agents | Requests | Errors | Turn wait p50 (s) | p90 (s) | tok/s per user | Input from cache |
|---|---|---|---|---|---|---|---|
| On the pod, 246k pool | 1 | 8 | 0 | 1.0 | 1.5 | 50.2 | 69% |
| On the pod, 246k pool | 4 | 32 | 0 | 2.8 | 4.0 | 41.7 | 68% |
| On the pod, 246k pool | 8 | 64 | 0 | 4.7 | 7.5 | 27.7 | 70% |
| On the pod, 246k pool | 12 | 96 | 0 | 7.0 | 20.2 | 18.3 | 48% |
| On the pod, 246k pool | 16 | 128 | 0 | 10.3 | 16.6 | 4.4 | 6% |
| Public URL, before TCP tuning | 1 | 8 | 0 | 1.8 | 1.8 | 48.5 | 66% |
| Public URL, before TCP tuning | 4 | 32 | 0 | 3.4 | 4.3 | 39.1 | 68% |
| Public URL, before TCP tuning | 8 | 64 | 0 | 5.4 | 8.7 | 26.6 | 68% |
| Public URL, before TCP tuning | 12 | 96 | 0 | 8.2 | 26.5 | 16.3 | 40% |
| Public URL, before TCP tuning | 16 | 128 | 0 | 10.7 | 47.6 | 4.9 | 5% |
| Public URL, BBR + compression | 1 | 8 | 0 | 1.4 | 1.8 | 50.4 | 66% |
| Public URL, BBR + compression | 4 | 32 | 0 | 3.1 | 4.1 | 40.0 | 68% |
| Public URL, BBR + compression | 8 | 64 | 0 | 5.1 | 8.5 | 26.4 | 68% |

Teams (each user's agents share a 6k-token repo context; ~13-14k-token prompts):

| Run | Shape | Requests | Errors | Turn wait p50 (s) | p90 (s) | Per user p50 (s) |
|---|---|---|---|---|---|---|
| On the pod, 246k pool | 3 + 3 + 3 + 3 agents | 96 | 0 | 15.0 | 47.7 | 3:12.6, 3:19.8, 3:15.2, 3:15.1 |
| On the pod, 246k pool | 8 + 1 + 1 + 1 + 1 agents | 96 | 0 | 14.3 | 40.0 | 8:13.6, 1:13.1, 1:18.6, 1:16.4, 1:20.8 |
| Public URL, before TCP tuning | 3 + 3 + 3 + 3 agents | 96 | 0 | 12.3 | 59.8 | 3:9.9, 3:14.0, 3:14.3, 3:12.4 |
| Public URL, before TCP tuning | 8 + 1 + 1 + 1 + 1 agents | 96 | 0 | 9.8 | 47.0 | 8:9.5, 1:15.1, 1:10.4, 1:8.4, 1:13.0 |

Reading it:

- **About 8 agents working at once is the comfortable limit**: ~5 s to first token per turn, ~26 tok/s each. At 12 the
  slowest turns reach 20-26 s; at 16 each agent gets ~5 tok/s. Nothing fails; it queues.
- Teams with bigger shared contexts (the team rows, ~13-14k-token prompts, 12 agents) fill the KV cache: typical turns
  wait 10-15 s, one in ten 40-60 s, and the single slowest first token took 85.2 s (public URL, 3 + 3 + 3 + 3; on the
  pod: 68.5 s). The edge allows up to 15 minutes for the first response bytes and has no limit once streaming starts, so such turns
  are slow, not failed.
- **The public path adds about 0.3-0.4 s per turn** after the TCP tuning below (0.4-0.8 s before it).
- A bigger KV pool (5.5 GiB, 300,930 tokens; `serve.sh heretic-kv55`) cut the 12-agent slow turns from 20.2 s to
  11.0 s and kept 8 agents the same, but its stress run was stopped before the 16-agent and team cells, with 678 MiB
  of GPU memory to spare at peak. Not adopted; details in `results/evidence/stress_kv55_partial.txt`.

## The network path

Every number below is in `results/evidence/network_path_2026-09-28.txt`.

| Finding | Evidence | What was done |
|---|---|---|
| The pod's host network drops packets: 13% ping loss even to 1.1.1.1; 17% to the edge | `ping` from the pod and a laptop, 2026-09-28 | Nothing on our side can remove it; a pod in a better datacenter (ideally in Asia, near the team) would |
| The edge's TCP to the pod (cubic) retransmitted 2.8% of bytes and sat at a 10-packet window, so a 40 KB prompt took 2-4.6 s to cross | `ss -ti` on the edge; `bench/upload_probe.py` | BBR congestion control and no slow start after idle on the edge (`edge/sysctl-heretic-tunnel.conf`), SSH compression on the tunnel |
| After the tuning the same 40 KB prompt crosses in about 0.6-1.1 s more than on the pod | `bench/upload_probe.py` | |
| Small requests add one round trip (~0.2 s) | `bench/ttft_probe.py` | |
| Caddy does not compress `text/event-stream`, and streams are not buffered | 113 chunks spread over 30 s through the edge | |
| The tunnel reconnects by itself: API back 13 s after the SSH process was killed | `edge_tunnel.sh` loop (now retries every 5 s) | |
