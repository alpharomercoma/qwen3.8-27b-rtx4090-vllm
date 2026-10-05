# Deploy from scratch

Seven steps, in order. Each says what it does, where to run it, and how to check it worked.
What the pieces are: [ARCHITECTURE.md](ARCHITECTURE.md). Day-to-day tasks afterwards: [OPERATIONS.md](OPERATIONS.md).

## One command: a new pod for the running service

Once the edge (step 4) and the web app (steps 5-6) are set up, which is a one-time job, a new or restarted GPU pod is
hooked up with one command from the repo root on the Mac:

```bash
scripts/new_pod.sh <pod-id>-<suffix>@ssh.runpod.io            # add "original" to serve the original model
E2E_PASSWORD=<web password> scripts/new_pod.sh <...>@ssh.runpod.io   # same, and also run the web app's tests
```

`<pod-id>-<suffix>@ssh.runpod.io` is the address in the SSH command RunPod shows for the pod. The pod needs an
RTX 4090 (driver 570 or newer), "SSH over exposed TCP" on, and a `/workspace` volume of at least 50 GB (a network
volume works; one that already holds the model and installs makes the next pod start in minutes).

| Step | What happens |
|---|---|
| 1 | The previous pod's `.pod_env` and `.pod_known_hosts` are kept as `.prev-<pod-id>` |
| 2 | `pod_connect.sh`: the pod's address and SSH host keys, read through RunPod's proxy and pinned; if the pod does not accept `~/.ssh/id_ed25519` yet, its public key is added through the proxy |
| 3 | Team API keys: `.team_api_keys` on the Mac (gitignored, mode 600) is copied to the pod, so everyone's key keeps working on the new pod |
| 4 | The code is pushed and `pod/start.sh` runs on the pod in the background (tools, vLLM, model download and check, server, gateway, tunnel): 20-30 min the first time. Its progress is printed; a dropped SSH connection does not stop it |
| 5 | The edge trusts the pod's tunnel key (`scripts/edge.sh install`, replacing the previous pod's) |
| 6 | Checks through `alphaexperiments.com`: 401 without a key, the model list and a short answer with a team key |
| 7 | The pod's team keys are copied back to `.team_api_keys`; with `E2E_PASSWORD` set, the Playwright tests run against the live site |

It can be rerun at any time: finished steps are skipped, and a rerun on the live pod restarts the gateway and tunnel
for a few seconds. The first time, without a `.team_api_keys` on the Mac, the pod creates a key labelled `team` and
it is saved there. The steps below do the same by hand, and set up the parts `new_pod.sh` relies on.

## 0. What you need

| Item | Details |
|---|---|
| A RunPod GPU pod | RTX 4090 (24 GB), driver 570 or newer (CUDA 12.8+), a volume at `/workspace` of at least 50 GB, public IP with SSH over TCP |
| The edge server | Root SSH to the server that serves `alphaexperiments.com` with Caddy (today it also hosts PengePassportPH, which owns its Caddyfile) |
| Vercel | Team `alpharomercoma-projects` (Hobby works) and the Vercel CLI, logged in |
| Your Mac | `ssh` with `~/.ssh/id_ed25519` authorized on the pod and the edge, `jq`, Node 22+, `uv` (only for benchmarks) |

## 1. Point the scripts at the pod (Mac)

RunPod shows an SSH command for the pod like `ssh <pod-id>-<suffix>@ssh.runpod.io -i ~/.ssh/id_ed25519`. That
connection is interactive only, so the scripts use the pod's direct TCP address instead. This reads the address and
the pod's SSH host keys through RunPod's proxy and saves them:

```bash
scripts/pod_connect.sh <pod-id>-<suffix>@ssh.runpod.io
```

It writes `.pod_env` (address) and `.pod_known_hosts` (host keys), both gitignored. Every script that talks to the pod
then checks the pod's host key strictly, so it will not talk to anything else that answers at that address.
The pod needs "SSH over exposed TCP" enabled.

Check: `scripts/pod.sh <<<'nvidia-smi --query-gpu=name --format=csv,noheader'` prints the GPU name.

## 2. Copy the code and start the server (Mac → pod)

```bash
scripts/push.sh                                               # copies pod/, bench/ and edge/ to /workspace/4090
POD_TIMEOUT=1800 scripts/pod.sh <<<'bash /workspace/4090/pod/start.sh'           # first run ~15-25 min (downloads, compile), later ~2 min
```

This serves the Heretic model. For Qwen3.8-27B as released, end the second line with `start.sh original'` instead;
[OPERATIONS.md → Switch model](OPERATIONS.md#switch-model) explains both and how to change later.

`POD_TIMEOUT=1800` gives the SSH call 30 minutes (`scripts/pod.sh` stops a call after 10 minutes by default). If it does
time out, run the same line again: `start.sh` picks up where it stopped. `pod/start.sh` skips whatever is already done:

| Step | Script | What it does |
|---|---|---|
| Tools | `pod/bootstrap.sh` | apt: tmux, jq, CUDA 12.8 compiler (FlashInfer compiles kernels on first use); uv 0.12.19 (checksum-verified); the `hf` CLI; creates vLLM's own key in `/workspace/.api_key` |
| vLLM | `pod/install_vllm.sh` | the vLLM 0.30.0 wheel built for CUDA 12.9 (checksum-verified) in `/workspace/venvs/vllm`, and swaps `torchcodec` for its CUDA 12.9 build (the default one needs CUDA 13 and crashes vLLM on import) |
| Model | `pod/fetch_model.sh <model>` | downloads the chosen model (`pod/models.sh`: Heretic `JC1DA/Qwen3.8-27B-heretic-ara-W4A16`, or original `RedHatAI/Qwen3.8-27B-INT4`) at its pinned commit, ~18 GiB, to `/workspace/models/`, and checks every file against `pod/models/<model>.sha256` |
| Server | `pod/serve.sh <model>` | starts vLLM in tmux session `serve` on `127.0.0.1:8000`; `start.sh` then waits until it serves that model (first boot compiles for ~4 min) |
| Gateway | `pod/gateway/run.sh` | starts `authz.py` (tmux `authz`, `127.0.0.1:8444`) and Caddy (tmux `gateway`, `127.0.0.1:8443`); creates the first team key, labelled `team`, if there is none |
| Tunnel | `pod/gateway/edge_tunnel.sh` | creates the pod's tunnel key (`/workspace/.secrets/edge_tunnel_ed25519`) and keeps `ssh -R 127.0.0.1:18443:127.0.0.1:8443 heretic-tunnel@alphaexperiments.com` open (tmux `edge`), retrying every 5 s |
| Public check | `pod/start.sh` | calls `https://alphaexperiments.com/heretic-inference/v1/models` without a key: `401` from the gateway means the whole path works and it prints `up`. On a brand-new pod this fails with "is this pod's tunnel key installed on the edge": expected until step 4 |

Check: `scripts/pod.sh <<<'tmux ls'` lists `authz`, `edge`, `gateway`, `serve`. After step 4 the tunnel connects by
itself; rerun `start.sh` to see `up`.

## 3. Hand out API keys (pod)

```bash
scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh add alice'     # prints the key once
scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/keys.sh list'          # labels + fingerprints, never keys
```

Keys live in `/workspace/.team_api_keys` (mode 600) and take effect immediately. For your own tests, put one in
`.env` at the repo root as `HERETIC_API_KEY=...` (gitignored).

## 4. Connect the edge (Mac → edge server)

```bash
POD_PUBKEY="$(scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/edge_tunnel.sh pubkey')" scripts/edge.sh install
```

`scripts/edge.sh install` copies `edge/` to the server and runs `edge/install.sh` as root. It is safe to rerun:

| Change on the edge server | Why |
|---|---|
| System user `heretic-tunnel` (no shell) whose only key is the pod's, marked `restrict,port-forwarding,permitlisten="127.0.0.1:18443"` | The pod can open exactly one port on the edge's loopback, and nothing else |
| `/etc/ssh/sshd_config.d/20-heretic-tunnel.conf` | The same limits in sshd (no TTY, no other forwarding), and dead tunnels dropped within ~45 s |
| `/etc/sysctl.d/60-heretic-tunnel.conf` | BBR congestion control and no slow start after idle: the path to the pod is long and lossy |
| `/etc/caddy/apps.d/heretic-inference.caddy` + an `import /etc/caddy/apps.d/*.caddy` line in the site block | The two `/heretic-inference` routes. The Caddyfile belongs to the server's other project; if it is regenerated and loses the line, rerun `scripts/edge.sh install` |

`edge/known_hosts` pins the edge server's SSH host keys, for both `scripts/edge.sh` and the pod's tunnel. If the
server is replaced, refresh it over a connection you trust.

Check (the model list proves the whole chain works):

```bash
curl -s https://alphaexperiments.com/heretic-inference/v1/models -H "Authorization: Bearer $HERETIC_API_KEY"
```

## 5. Deploy the web app (Mac → Vercel)

```bash
cd apps/web
npm install
vercel link --yes --project heretic-inference --scope alpharomercoma-projects
printf 'Web password: ' >&2; IFS= read -rs PW; printf '\n' >&2; printf '%s' "$PW" | vercel env add APP_PASSWORD production --scope alpharomercoma-projects; unset PW
openssl rand -base64 48 | tr -d '\n' | vercel env add SESSION_SECRET production --sensitive --scope alpharomercoma-projects
vercel deploy --prod --scope alpharomercoma-projects
```

| Setting | Why |
|---|---|
| `APP_PASSWORD` | The shared password on the web page |
| `SESSION_SECRET` | Signs the session cookie; changing it (or the password) signs everyone out |
| No inference key | The server uses the OIDC token Vercel gives every function; OIDC is on by default for new projects (team issuer) |
| `vercel.json` `regions: ["sin1"]` | Functions run in Singapore, next to the Manila edge |

## 6. Let the web app through the gateway (pod)

The gateway only accepts OIDC tokens for one project. Put its id (`apps/web/.vercel/project.json`, `projectId`) in
`pod/gateway/authz.env` as `VERCEL_PROJECT_ID`, then:

```bash
scripts/push.sh && scripts/pod.sh <<<'bash /workspace/4090/pod/gateway/run.sh'
```

The other lines in `authz.env` are the team's issuer and audience, and the allowed environments (`production`).
None of it is secret: they are claims inside a token that Vercel signs.

## 7. Check everything (Mac)

| Check | Command | Pass |
|---|---|---|
| API and keys | `curl` from step 4 | JSON with the served model: `qwen3.8-27b-heretic`, or `qwen3.8-27b` for the original |
| pi and opencode | `HERETIC_API_KEY=... scripts/verify_clients.sh` | both `PASS` |
| Web app | `cd apps/web && E2E_PASSWORD=... npm run e2e` (Playwright drives your installed Google Chrome) | all tests pass |
| By hand | open https://alphaexperiments.com/heretic-inference | status pill says Online, answers stream |

Then set up your own clients: [CLIENTS.md](CLIENTS.md).
