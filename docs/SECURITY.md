# Security: how the pieces talk

How the browser, Vercel, the edge server and the GPU pod authenticate and encrypt traffic, what else was
considered, and what is still weak. Decided 2026-09-28.

## Request paths

| Caller | Path | Proves itself with |
|---|---|---|
| Browser | `https://alphaexperiments.com/heretic-inference` → edge Caddy → Vercel (Next.js) | Shared password → signed session cookie |
| Web app server (Vercel function) | Vercel `sin1` → `https://alphaexperiments.com/heretic-inference/v1` → edge Caddy → SSH tunnel → pod gateway → vLLM | Vercel OIDC token (JWT, signed by Vercel, 2 h life) |
| pi, opencode, curl | laptop → same `/v1` URL → edge Caddy → SSH tunnel → pod gateway → vLLM | Team API key (`sk-heretic-…`) |

## Every hop

| Hop | Encryption | Authentication | Exposure |
|---|---|---|---|
| Browser → edge | TLS 1.2/1.3 (Let's Encrypt, HSTS 1 year) | none at this hop | public, port 443 |
| Edge → Vercel | TLS to `heretic-inference.vercel.app` | Vercel serves the public production alias | public |
| Browser → app pages and `/api/*` | inside the TLS above | session cookie: HMAC-SHA256, `HttpOnly`, `Secure`, `SameSite=Lax`, path `/heretic-inference`, 30 days | password page only without it |
| Vercel → edge `/v1` | TLS | OIDC bearer token | public URL, useless without a token or key |
| Pod → edge (tunnel) | SSH (ed25519 key; the edge's host key pinned in `edge/known_hosts`) | pod's tunnel key, restricted on the edge | **no inbound port on the pod**: the pod dials out |
| Mac → pod, Mac → edge (admin) | SSH, host keys pinned (`.pod_known_hosts` from `scripts/pod_connect.sh`, `edge/known_hosts`) | your SSH key | pod: SSH port only |
| Tunnel → gateway → vLLM | loopback only | `authz.py` checks key or token; vLLM gets the gateway's own key | `127.0.0.1` only |

## Controls, and where they live

| Control | Where | Detail |
|---|---|---|
| Path allowlist | `pod/gateway/Caddyfile` | Only `/v1/*` and `/healthz` answer. vLLM's `/metrics`, `/tokenize`, `/invocations` return 404 |
| Team keys | `/workspace/.team_api_keys` (mode 600), `pod/gateway/keys.sh` | One `<label> <key>` per line; `add`, `list`, `revoke`; re-read on change; constant-time compare |
| OIDC check | `pod/gateway/authz.py`, `pod/gateway/authz.env` | RS256 only. Issuer `oidc.vercel.com/alpharomercoma-projects`, audience `vercel.com/alpharomercoma-projects`, `project_id` `prj_r4Pl…`, `environment` `production` |
| Caller in logs | `/workspace/logs/gateway_access.log` | `caller` field: `key-<label>` or `vercel-production`. Authorization headers are logged as `REDACTED` |
| Tunnel account | `edge/install.sh`, `edge/sshd-heretic-tunnel.conf` | `heretic-tunnel`: no shell (`nologin`), no TTY, no agent, X11 or local forwarding; may only listen on `127.0.0.1:18443`. Enforced in both `authorized_keys` (`restrict,port-forwarding,permitlisten=…`) and `sshd` `Match` |
| Fail closed | gateway | authz down → 502; tunnel down → edge 502; no key → 401 |
| Browser side | `apps/web/next.config.ts` | `frame-ancestors 'none'`, `nosniff`, `no-referrer`, `noindex`; server-action origin pinned to `alphaexperiments.com` |
| Secrets on Vercel | project env | `APP_PASSWORD`, `SESSION_SECRET` (sensitive). **No inference key**: the function gets its OIDC token per request |
| Chats | browser `localStorage` | The server keeps no conversation. Clearing site data deletes them |
| Downloads on the pod | `pod/bootstrap.sh`, `pod/install_vllm.sh`, `pod/gateway/run.sh` | uv 0.12.19, the vLLM 0.30.0 wheel and Caddy 2.10.2 are pinned and checked against published SHA-256 / SHA-512 before use. The model is pinned to one Hugging Face commit and every file is checked against `pod/qwen38-heretic-ara-w4a16.sha256`. vLLM's Python dependencies come from PyPI and PyTorch's index over TLS, not hash-pinned |

## Where the secrets live

None of these are in git. `.gitignore` covers `.env`, `.pod_env`, `.vercel/`, `.secrets/` and `*.pem`.

| Secret | Where | Who needs it |
|---|---|---|
| Team API keys | pod `/workspace/.team_api_keys` (mode 600); each user's shell profile | pi, opencode, scripts |
| vLLM's own key | pod `/workspace/.api_key` (mode 600) | only the gateway |
| Tunnel private key | pod `/workspace/.secrets/edge_tunnel_ed25519` (mode 600) | only the tunnel |
| `APP_PASSWORD`, `SESSION_SECRET` | Vercel project env, production, `SESSION_SECRET` marked sensitive | the web app |
| A key for local tests | repo `.env` as `HERETIC_API_KEY` (gitignored) | `verify_clients.sh`, `bench_public.sh` |
| Pod SSH address | repo `.pod_env` (gitignored) | `scripts/*.sh` |

In git on purpose (not secret): `edge/known_hosts` (public host keys) and `pod/gateway/authz.env` (the Vercel team,
project id and environment that a token must name).

## Options considered for Vercel ↔ RunPod

Researched 2026-09-28 against current docs.

| Option | Verdict | Why |
|---|---|---|
| **Reverse SSH tunnel to our edge + OIDC/API key at the gateway** | **Chosen** | No inbound port on the pod. Works on Vercel Hobby. No 100-125 s CDN timeout (the edge waits up to 15 min for first bytes). Reuses the edge's existing TLS. Clean URL on our domain |
| RunPod HTTPS proxy (`{pod}-{port}.proxy.runpod.net`) | Rejected | Public by design; per-pod URL changes on every move; 100 s Cloudflare timeout; measured +1.2 s per call on a past pod |
| Cloudflare Tunnel (named) + Access service token | Not possible now | Needs the hostname in a Cloudflare zone. `alphaexperiments.com` DNS is on Vercel. CNAME setup needs Business, subdomain delegation needs Enterprise. Proxy read timeout 125 s |
| Cloudflare Quick Tunnel | Rejected | No Server-Sent Events, so no streaming; 200 in-flight requests max; random URL |
| Vercel static IPs / Secure Compute (IP allowlist) | Not available | Static IPs: Pro/Enterprise add-on, shared pool. Secure Compute: Enterprise only. Team is on Hobby |
| Tailscale from Vercel functions | Not viable | No supported way to join a tailnet from a Vercel function |
| Tailscale Funnel on the pod | Possible, not chosen | Public endpoint on `*.ts.net`; another account to manage; still needs our own auth |
| mTLS from the function | Possible later | Node's undici can present a client cert; no official Vercel doc; OIDC gives workload identity without a stored cert |
| Static shared key in Vercel env | Rejected | A long-lived secret on Vercel. OIDC tokens are minted per deployment and expire in 2 h |

Sources: Vercel OIDC reference (`vercel.com/docs/oidc/reference`), static IPs (`vercel.com/docs/networking/static-ips`),
RunPod expose ports (`docs.runpod.io/pods/configuration/expose-ports`), Cloudflare tunnel and partial setup
(`developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/`, `/dns/zone-setups/partial-setup/`),
Quick Tunnels (`…/do-more-with-tunnels/trycloudflare/`), Tailscale serverless (`tailscale.com/kb/1364/serverless`),
OpenSSH `permitlisten` (`man.openbsd.org/sshd.8`).

## Verified

| Check | Result |
|---|---|
| No key, wrong key, malformed JWT at `/v1/models` | 401 with an OpenAI-style error |
| vLLM's own key sent to the gateway | 401 (it is not a team key) |
| Team key | 200 |
| `/metrics`, `/tokenize` through the gateway | 404 |
| Web app → model with no key on Vercel | 200, logged as `vercel-production` (OIDC) |
| New browser context, no cookie | password page; `/api/status` and `/api/chat` 401 |
| Wrong password | "That password is not right." after a 0.6 s delay |
| `sshd -T` for `heretic-tunnel` | `permitlisten 127.0.0.1:18443`, `allowtcpforwarding remote`, `permittty no`, `forcecommand /usr/sbin/nologin` |
| PengePassportPH on the same edge | same status codes before and after the change |

## Known weaknesses

| Weakness | Impact | Fix when needed |
|---|---|---|
| Web password is short and shared | Anyone who guesses it can chat (and spend GPU time) | Per-user sign-in (e.g. Vercel's auth options or an IdP) |
| No limit on password attempts (only a 0.6 s delay per wrong try) | Online guessing is only slowed, not stopped | Not added: every request reaches Vercel from the edge server's one IP, so the app cannot tell clients apart, and a global limiter would let one person lock the whole team out. Per-user sign-in fixes both |
| One team API key | Cannot tell teammates apart; revoking it locks everyone out | `keys.sh add <name>` per person (already supported) |
| Uncensored model | Answers requests a stock model refuses | Keep the URL and password inside the team |
| No rate limit per caller | One agent swarm can fill the 16-request batch | vLLM queues fairly (FCFS); add per-key limits if it becomes a problem |
| Edge is a single small VPS (1 GB) shared with PengePassportPH | Edge outage takes both down | Move the tunnel end to its own box |
| Tunnel key lives on the pod volume | Whoever has root on the pod can open the tunnel | It can only reach `127.0.0.1:18443` on the edge; revoke by editing `authorized_keys` |
