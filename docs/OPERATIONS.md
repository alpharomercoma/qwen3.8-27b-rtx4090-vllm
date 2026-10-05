# Operations

Day-to-day tasks once everything is deployed ([DEPLOY.md](DEPLOY.md)). Commands run from the repo root on a Mac;
`scripts/pod.sh <<<'...'` runs a command on the pod, `scripts/edge.sh <<<'...'` on the edge server.

## Start, stop, restart

| Task | Command |
|---|---|
| Start everything after the pod was stopped | Start the pod in RunPod. If its address changed: `scripts/pod_connect.sh <pod-id>-<suffix>@ssh.runpod.io`. Then `scripts/push.sh && POD_TIMEOUT=1800 scripts/pod.sh <<<'bash /workspace/4090/pod/start.sh'` (~2 min when installed; serves the model it served last) |
| Restart only vLLM | `scripts/pod.sh <<<'bash /workspace/4090/pod/serve.sh $(cat /workspace/.model)'` (~1 min; the gateway and tunnel stay up) |
| Restart the gateway (after editing keys by hand, `authz.env` or the Caddyfile) | `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/run.sh'` |
| Restart the tunnel | `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/edge_tunnel.sh'` |
| What is running | `scripts/pod.sh <<<'tmux ls'`: `serve` (vLLM), `gateway`, `authz`, `edge` (tunnel) |
| Stop paying | Stop the pod in RunPod. The web app stays up and shows "Offline"; the API answers 502 |

`/workspace` survives a pod stop. The installs, the model, the keys and the tunnel key are all there, so `start.sh`
only restarts processes. A RunPod container start command can run it on boot:
`bash -c "bash /workspace/4090/pod/start.sh; sleep infinity"`.

## Switch model

The pod serves one model at a time (`pod/models.sh`). How they differ in quality and refusals: [EVAL.md](EVAL.md).

| Name | Hugging Face checkpoint | Served as |
|---|---|---|
| `heretic` (default) | `JC1DA/Qwen3.8-27B-heretic-ara-W4A16`: the official Heretic abliteration, AutoRound 4-bit | `qwen3.8-27b-heretic` |
| `original` | `RedHatAI/Qwen3.8-27B-INT4`: Qwen3.8-27B as released, Red Hat's 4-bit build | `qwen3.8-27b` |

| Task | Command |
|---|---|
| Which one is live | `curl -s https://alphaexperiments.com/heretic-inference/v1/models -H "Authorization: Bearer $HERETIC_API_KEY"`, or the web app (header and "Use from the terminal") |
| Serve the original | `POD_TIMEOUT=1800 scripts/pod.sh <<<'bash /workspace/4090/pod/start.sh original'` |
| Serve Heretic again | `POD_TIMEOUT=1800 scripts/pod.sh <<<'bash /workspace/4090/pod/start.sh heretic'` |

What a switch does:

- The first time, it downloads the other model (~18 GB, a few minutes) and checks its SHA-256 while the current model
  keeps answering.
- Then vLLM restarts with the new model: about a minute without answers (the API returns 502, the web app shows
  Offline). The gateway and tunnel restart for a few seconds.
- Once the new model serves, the choice is saved in `/workspace/.model`, so later restarts serve the same model. A
  switch that fails (download, checksum, disk space) leaves the previous choice in place.
- The web app follows on its own: it asks the pod which model is live. A message sent in the first minute may get
  "The GPU server has just switched models. Send the message again."
- pi and opencode configs from [CLIENTS.md](CLIENTS.md) list both models; users pick the live one (pi: `/model`).
  Asking for the other one returns 404.
- Disk: both models together take ~37 GB of `/workspace`, which is tight next to vLLM on a 50 GB volume.
  `fetch_model.sh` checks free space before downloading. To make room, delete the model you are not using
  (`rm -rf /workspace/models/<its directory>`, see `pod/models.sh`); switching back downloads it again.

## Move to a new pod

A new pod has a new address and an empty `/workspace`.

| Step | Command |
|---|---|
| 1. New address and host keys | `scripts/pod_connect.sh <pod-id>-<suffix>@ssh.runpod.io` ([DEPLOY.md step 1](DEPLOY.md#1-point-the-scripts-at-the-pod-mac)) |
| 2. Install and start | `scripts/push.sh && POD_TIMEOUT=1800 scripts/pod.sh <<<'bash /workspace/4090/pod/start.sh'` (add `original` for the original model) |
| 3. Trust its tunnel key on the edge | `POD_PUBKEY="$(scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/edge_tunnel.sh pubkey')" scripts/edge.sh install` (replaces the old pod's key) |
| 4. New team keys | `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh add <name>'` for each person: keys lived on the old volume |

The web app, the edge routes and the client configs do not change.

## Keys and passwords

| Task | Command |
|---|---|
| New API key | `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh add alice'` (printed once) |
| List keys | `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh list'` (labels and fingerprints) |
| Revoke | `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh revoke alice'` (next request fails) |
| Rotate the shared key | `scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh revoke team; bash /workspace/4090/pod/gateway/keys.sh add team'` |
| Change the web password | `cd apps/web`, `vercel env rm APP_PASSWORD production`, `vercel env add APP_PASSWORD production`, `vercel deploy --prod`. Everyone is signed out |
| Let preview deployments reach the model | add `preview` to `VERCEL_ENVIRONMENTS` in `pod/gateway/authz.env`, push, restart the gateway |
| vLLM's own key | `/workspace/.api_key`: only the gateway uses it; nothing to hand out |

## Change things

| Task | How |
|---|---|
| Deploy the web app | `cd apps/web && vercel deploy --prod --scope alpharomercoma-projects` |
| Change the edge routes | edit `edge/heretic-inference.caddy`, then the `scripts/edge.sh install` line above (it validates Caddy before reloading) |
| Change vLLM settings | edit `PROD_FLAGS` in `pod/serve.sh` (both models) or the `heretic)` / `original)` lines, `scripts/push.sh`, restart vLLM |
| Add another model | a new case in `pod/models.sh` (repo, pinned commit, directory, served name), its `pod/models/<name>.sha256`, a line in `serve.sh`, and a name and description in `apps/web/src/lib/config.ts` (`MODELS`) |
| Longer context per request | `--max-model-len 131072` works (1.9 full-length requests fit in the cache). 262,144 does not start: one request would not fit. Also raise `contextWindow` / `limit.context` in the client configs |
| Bigger KV cache | `serve.sh heretic-kv55` (300,930 tokens). Faster at 12 agents, but only partly stress-tested (see [ARCHITECTURE.md](ARCHITECTURE.md#performance)) |

## Logs

| Log | Where |
|---|---|
| vLLM (queue: `grep "Running:"`) | pod `/workspace/logs/serve_heretic.log` or `serve_original.log` |
| Every API request (JSON; `caller` = `key-<label>` or `vercel-production`; keys shown as `REDACTED`) | pod `/workspace/logs/gateway_access.log` |
| Rejected keys and tokens | pod `/workspace/logs/authz.log` |
| Tunnel drops and reconnects | pod `/workspace/logs/edge_tunnel.log` |
| `start.sh` runs | pod `/workspace/logs/start.log` |
| Edge Caddy | `scripts/edge.sh <<<'journalctl -u caddy --since -1h --no-pager'` |
| Web functions | Vercel dashboard → heretic-inference → Logs |

## Troubleshooting

| Symptom | Likely cause | Check or fix |
|---|---|---|
| Web status pill "Offline", API 502 | Pod stopped, vLLM down, or tunnel down | `tmux ls` on the pod; `tail /workspace/logs/edge_tunnel.log`; on the edge `ss -ltn \| grep 18443` |
| Status pill "Rejected" | The web app's OIDC token does not match `authz.env` | `tail /workspace/logs/authz.log` shows the reason (project, environment, expiry) |
| 401 for a CLI | Key missing, mistyped or revoked | `keys.sh list`; the client's `echo $HERETIC_API_KEY` |
| Tunnel log: `remote port forwarding failed` | The edge still holds the previous, dead session | Wait: the edge drops it within ~45 s and the loop retries every 5 s |
| Slow first token | vLLM queue (16 at a time) or a long uncached prompt | `grep "Running:" /workspace/logs/serve_$(cat /workspace/.model).log \| tail -3` shows running and waiting |
| 404 `The model ... does not exist` | The client asks for the model that is not being served | Pick the live one ([Switch model](#switch-model)) |
| vLLM dies on import: `libnvrtc.so.13` | A CUDA 13 `torchcodec` was installed | `bash /workspace/4090/pod/install_vllm.sh` swaps in the CUDA 12.9 build |
| Everything in tmux vanished after a restart | An old script killed the tmux server with `pkill -f` (its command line contains the first session's command) | Fixed: the scripts use `killp` from `pod/env.sh`, which skips tmux. `start.sh` brings everything back |
| Tunnel log: `Connection refused` on port 22 | The edge's firewall rate-limits new SSH connections (6 per 30 s); a pod whose key the edge does not accept yet retries too often | Install the pod's key (`scripts/edge.sh install`, [Move to a new pod](#move-to-a-new-pod)); the tunnel loop backs off to one try a minute while it fails |
| `bootstrap.sh`: `WARNING: /workspace ignores file modes` | The pod's `/workspace` is a RunPod network volume (FUSE), where every file reads as mode 666 | Expected: only root runs in the container. The tunnel uses a mode-600 copy of its key in `/root/.heretic`; the benchmark sandbox (`bench/evals`) refuses to run on such a volume |
| `uv`: `Permission denied` under `/workspace/.cache/uv` | The volume came with a cache written by a user id this container does not map (shown as `nobody`); even root cannot write it | `mv /workspace/.cache/uv /workspace/.cache/uv.old` (or `export UV_CACHE_DIR=/tmp/uv`) and run the command again |
| Empty `200` from the gateway | The gateway's site address had a host, so requests with another `Host` header matched nothing | Fixed in `pod/gateway/Caddyfile`: `http://:8443` + `bind 127.0.0.1` |
