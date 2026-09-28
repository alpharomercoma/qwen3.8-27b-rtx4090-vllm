# Codex QA, round 5: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Earlier finding (round-#) | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| round-1 #1 | FIXED | Pod key is validated locally/remotely and base64-transferred. |
| round-1 #2 | FIXED | Proxy and direct pod SSH enforce pinned host keys. |
| round-1 #3 | FIXED | Final vLLM health check gates gateway startup. |
| round-1 #4 | FIXED | Pi docs correctly describe off versus enabled thinking. |
| round-1 #5 | FIXED | Operations uses complete pod-wrapper commands. |
| round-1 #6 | FIXED | Requested secret/key ignore rules exist. |
| round-1 #7 | FIXED | Captured prompt uses a neutral path. |
| round-1 #8 | FIXED | Committed verifier evidence supports 13 s / 22 s. |
| round-1 #9 | FIXED | Review link resolves to committed files. |
| round-2 #1 | FIXED | zsh-safe password prompt is present. |
| round-2 #2 | FIXED | Gateway/tunnel failures stop `start.sh`. |
| round-2 #3 | FIXED | Key-file updates use same-filesystem atomic rename. |
| round-2 #4 | FIXED | Unknown verifier selectors exit 2. |
| round-2 #5 | FIXED | 85.2 s public and 68.5 s pod maxima are accurately scoped. |
| round-3 #1 | FIXED | Password command works in zsh syntax. |
| round-3 #2 | FIXED | Web dialog uses merge commands, not replacement roots. |
| round-3 #3 | FIXED | Download-completion marker gates model reuse. |
| round-3 #4 | FIXED | Public 401 check gates the “up” message. |
| round-3 #5 | FIXED | All key-management commands are copyable. |
| round-4 #1 | PARTLY | Direct uv, vLLM, and Caddy downloads are hash-verified; PyPI/PyTorch-index dependencies remain TLS-only and unpinned, as `SECURITY.md` acknowledges. |
| round-4 #2 | NOT FIXED | `actions.ts` still has only a 600 ms delay. The Accepted rationale is factually wrong: durable throttling materially reduces online password guessing, even if it does not solve the shared-password design. |
| round-4 #3 | FIXED | ECDSA and DSA private-key filename patterns are ignored. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | MED | `pod/start.sh:14` | Fresh startup can skip bootstrap while required bootstrap products are absent. | The gate checks only `tmux` and `nvcc`; `install_vllm.sh` requires `uv`, `fetch_model.sh` requires `hf`, and bootstrap creates `/workspace/.api_key`. A fresh image with tmux/nvcc but an empty workspace fails later. | Gate bootstrap on all required commands and `/workspace/.api_key`, not only two tools. |
| 2 | MED | `apps/web/src/lib/config.ts:11`; `apps/web/src/app/api/chat/route.ts:14` | The 8,192-token cap does not keep answers within the 300 s function limit under documented load. | The tuned public 8-agent result is 26.4 tok/s and 5.1 s TTFT: an allowed 8,192-token answer takes about 315 s at p50. | Set an output cap for the supported concurrency target, or use an execution model that can outlast 300 s; do not claim the present cap guarantees this. |

Checked and fine:

- Reviewed exactly 286 non-ignored commit candidates. No actual API key, JWT, private-key block, web password, or personal home path was found. `authz.env` contains only valid, nonempty public OIDC-identity fields.
- Requested ignore coverage works for `.env`, `.pod_env`, `.vercel`, app `.env.local`, `.secrets`, `keys/`, PEM/key files, and RSA/Ed25519/ECDSA/DSA private-key names.
- Pi 0.87.1 accepts the documented provider schema; installed OpenCode 1.18.23 supports the documented model/run flags and configuration shape.
- Gateway routing, SSH restrictions, model flags, client snippets, and generated Architecture performance tables agree with code and raw Heretic summaries.
- Benchmark references to Cloudflare are historical or explicitly superseded; they direct readers to reverse SSH.
- `bash -n`, ShellCheck, Python AST parsing, TypeScript `--noEmit`, and ESLint passed. No production request, client verifier, or Playwright test was run.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| Finding | Verdict | What changed |
|---|---|---|
| Round-4 #1 (PyPI deps) | Accepted, documented | Direct downloads are verified; the dependency tree from PyPI / PyTorch's index stays TLS-only, stated in `docs/SECURITY.md` |
| Round-4 #2 (password limiter) | Not added; rationale corrected | Codex is right that a limiter slows online guessing. The reason not to add one here: Vercel overwrites `X-Forwarded-For` with the connecting IP, which for every user is the edge server, so the app cannot tell clients apart; a global limiter would let one person lock the whole team out. `docs/SECURITY.md` says this; the fix for both is per-user sign-in |
| New #1 (bootstrap gate) | Fixed | `start.sh` runs `bootstrap.sh` unless `tmux`, `jq`, `uv`, `hf`, CUDA 12.8's `nvcc` and a non-empty `/workspace/.api_key` are all present |
| New #2 (8,192 tokens can outlast 300 s) | Fixed | The chat route ends an answer at 280 s (`AbortSignal.any` with the request's signal); the UI marks any answer without a finish reason "Stopped before the end. Ask it to continue." Tested with a mock streaming server and a 3 s limit: the fast answer finished normally without the note, the slow one stopped at 3.3 s with its text kept, no error, and the note survived a reload. `docs/ARCHITECTURE.md` states "8,192 tokens or 280 s, whichever comes first". Redeployed |
| Found while testing | Fixed | `e2e/chat.spec.ts` located the composer with `getByLabel("Message")`, which also matches every "Edit message" button, so the multi-message tests would fail in strict mode. It now uses `getByRole("textbox", { name: "Message", exact: true })` |
