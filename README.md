# Heretic inference

The team's self-hosted chat and API for Qwen3.8-27B, served by vLLM on one rented RTX 4090. The GPU runs one of two
builds at a time, chosen on the pod:

| Model | Served as | What it is |
|---|---|---|
| **Heretic** (default) | `qwen3.8-27b-heretic` | The official Heretic (ARA) abliteration ([`heretic-org/Qwen3.8-27B-heretic-ara`](https://huggingface.co/heretic-org/Qwen3.8-27B-heretic-ara)), 4-bit: answers requests the original refuses |
| **Original** | `qwen3.8-27b` | Qwen3.8-27B as released ([`RedHatAI/Qwen3.8-27B-INT4`](https://huggingface.co/RedHatAI/Qwen3.8-27B-INT4)), the build the engine benchmarks used |

- **Chat:** https://alphaexperiments.com/heretic-inference (a ChatGPT-style app; ask the team for the password). It
  shows which model is live.
- **API:** `https://alphaexperiments.com/heretic-inference/v1`, OpenAI-compatible, with a team API key. Works with pi,
  opencode, curl and the OpenAI or AI SDKs.

## Use it

| I want to | Go to |
|---|---|
| Chat in the browser | open the link above, enter the password |
| Use it from **pi** | [docs/CLIENTS.md → pi](docs/CLIENTS.md#2-pi): five copy-paste commands |
| Use it from opencode, curl, Python or TypeScript | [docs/CLIENTS.md](docs/CLIENTS.md) |
| Get an API key | ask whoever runs the pod; they run `keys.sh add <your name>` ([docs/CLIENTS.md → step 1](docs/CLIENTS.md#1-get-an-api-key)) |
| Switch between Heretic and the original | `start.sh heretic` or `start.sh original` on the pod ([docs/OPERATIONS.md → Switch model](docs/OPERATIONS.md#switch-model)) |

Capacity: about 8 agents working at once at ~5 s per turn; up to 16 run at once and more wait their turn. 65,536
tokens per request. Details: [docs/ARCHITECTURE.md → Performance](docs/ARCHITECTURE.md#performance).

## How it works

```
 browser ──HTTPS──▶ alphaexperiments.com (Caddy, Manila) ──HTTPS──▶ Vercel: Next.js + AI SDK chat app (apps/web)
                          │                                            │ OIDC token (no stored secret)
 pi / opencode ──HTTPS────┤ /heretic-inference/v1/*  ◀────HTTPS────────┘
   (team key)             │
                          └── reverse SSH tunnel (the pod dials out) ──▶ RunPod RTX 4090:
                                                                         gateway (checks key/token) ──▶ vLLM
```

| Piece | What it does |
|---|---|
| **Web app** (`apps/web`, on Vercel) | Chat UI: password page, streaming answers with the model's reasoning, chats saved in your browser, speed stats under each answer |
| **Edge** (`edge/`, on the alphaexperiments.com server) | TLS for the domain; routes `/heretic-inference/v1/*` into the tunnel and the rest to Vercel |
| **Tunnel** | An SSH connection the pod opens to the edge, so the pod exposes no port to the internet |
| **Gateway** (`pod/gateway`, on the pod) | Only lets `/v1/*` through, and only with a team API key or the web app's Vercel-signed token |
| **vLLM** (`pod/serve.sh`, on the pod) | Serves the chosen 4-bit model (`pod/models.sh`) with a 246k-token shared cache, 16 requests at once |

Why vLLM, why this quant, and how it compares with Ollama, llama.cpp and SGLang on the same card:
[docs/benchmarks/REPORT.md](docs/benchmarks/REPORT.md).

## Repository

| Path | Runs on | What |
|---|---|---|
| [`apps/web/`](apps/web/README.md) | Vercel | Next.js 16 + AI SDK 7 chat app, Playwright tests in `e2e/` |
| [`pod/`](pod/README.md) | GPU pod | `start.sh` (everything), `models.sh` (the two models), install, model download, `serve.sh` configs, `gateway/` (Caddy, `authz.py`, `keys.sh`, tunnel) |
| [`edge/`](edge/README.md) | alphaexperiments.com | Caddy routes, the tunnel account's SSH rules, TCP tuning, `install.sh` |
| `scripts/` | Mac | `pod_connect.sh` (find a pod, pin its host key), `pod.sh` / `push.sh` / `pull.sh` (pod over SSH), `edge.sh` (edge server), `verify_clients.sh` (pi + opencode test), `bench_public.sh` |
| `bench/` | Mac or pod | Load generator, latency probes, pi team runs, right-sizing calculator, table generators |
| `docs/` | | [ARCHITECTURE](docs/ARCHITECTURE.md), [DEPLOY](docs/DEPLOY.md) (step by step from scratch), [OPERATIONS](docs/OPERATIONS.md) (runbook), [SECURITY](docs/SECURITY.md), [CLIENTS](docs/CLIENTS.md), [benchmarks/](docs/benchmarks/README.md), [review/](docs/review/) |
| `results/` | | Raw measurements behind every number in the docs (`raw/`, `evidence/`, `llamabench/`) |
| `models/configs/` | | `config.json` copies for `bench/fit.py` |

## Common tasks

| Task | Command (from the repo root) |
|---|---|
| Start the service after the pod was stopped | start the pod in RunPod, then `scripts/push.sh && POD_TIMEOUT=1800 scripts/pod.sh <<<'bash /workspace/4090/pod/start.sh'` (new address? first `scripts/pod_connect.sh <pod>@ssh.runpod.io`) |
| Serve the original model (or `heretic` to go back) | `POD_TIMEOUT=1800 scripts/pod.sh <<<'bash /workspace/4090/pod/start.sh original'` |
| New API key | `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh add <name>'` |
| Deploy the web app | `cd apps/web && vercel deploy --prod --scope alpharomercoma-projects` |
| Test pi and opencode end to end | `HERETIC_API_KEY=... scripts/verify_clients.sh` |
| Test the web app end to end | `cd apps/web && E2E_PASSWORD=... npm run e2e` |

More in [docs/OPERATIONS.md](docs/OPERATIONS.md). No secret is stored in this repository; where each one lives is in
[docs/SECURITY.md](docs/SECURITY.md#where-the-secrets-live).
