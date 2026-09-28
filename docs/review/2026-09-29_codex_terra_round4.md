# Codex QA, round 4: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Earlier finding (round-#) | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| round-1 #1 | FIXED | Pod public key is validated and base64-transferred. |
| round-1 #2 | FIXED | Proxy/direct pod SSH use pinned known-host files and strict checking. |
| round-1 #3 | FIXED | Final vLLM health check gates gateway startup. |
| round-1 #4 | FIXED | Pi docs correctly describe thinking as off versus enabled. |
| round-1 #5 | FIXED | Operations uses the full pod-wrapper command. |
| round-1 #6 | FIXED | Requested env, secret, key-directory, and SSH-key ignore rules exist. |
| round-1 #7 | FIXED | Captured prompt now uses `/path/to/project`. |
| round-1 #8 | FIXED | Committed verifier evidence supports 13 s / 22 s. |
| round-1 #9 | FIXED | `docs/review/` is committed and README links to it. |
| round-2 #1 | FIXED | Password prompt works in zsh and bash. |
| round-2 #2 | FIXED | `start.sh` stops on gateway/tunnel startup failure. |
| round-2 #3 | FIXED | Key updates use same-filesystem temporary files and rename. |
| round-2 #4 | FIXED | Unknown verifier selectors exit 2. |
| round-2 #5 | FIXED | 85.2 s public and 68.5 s pod maxima are accurately scoped. |
| round-3 #1 | FIXED | zsh-safe password command is present. |
| round-3 #2 | FIXED | Terminal dialog uses provider-merge commands. |
| round-3 #3 | FIXED | Model download completion marker is required. |
| round-3 #4 | FIXED | Public 401 check gates the “up” message. |
| round-3 #5 | FIXED | All key-management commands are fully copyable. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | MED | `pod/bootstrap.sh:12`; `pod/gateway/run.sh:11`; `pod/install_vllm.sh:9-17` | Fresh deployment executes downloaded installers/binaries without checksum or signature verification. | `curl \| sh`, `curl \| tar`, and URL/index package installs run as root on the pod. | Pin artifact versions plus SHA-256/signatures; download, verify, then install. |
| 2 | MED | `apps/web/src/app/actions.ts:8-16` | The password gate has no application/edge rate limit. | The only wrong-password control is a fixed 600 ms delay; supplied Caddy/Next code has no per-IP/session throttle. Distributed guessing can also consume GPU capacity. | Add durable rate limiting for unlock attempts and per-key/request limits at the gateway. |
| 3 | LOW | `.gitignore:19-20` | ECDSA and DSA SSH private-key defaults are not ignored. | `git check-ignore --no-index id_ecdsa` and `id_dsa` both report not ignored. | Add `id_ecdsa*` and `id_dsa*` (or a carefully scoped broader SSH-key rule). |

Checked and fine:

- The stated 285-file commit set contains no actual API key, JWT, GitHub/Hugging Face token, private-key block, web password, or personal home path. The `eyJ` hit is inside an npm integrity hash; `sk-heretic` hits are placeholders.
- Required ignore coverage works for `.env`, `.pod_env`, app `.env.local`, `.vercel`, `.secrets`, `keys/`, `*.key`, `*.pem`, and RSA/Ed25519 private-key names.
- Installed Pi 0.87.1 supports the documented schema and environment interpolation; Pi/OpenCode fields match across `CLIENTS.md`, the dialog, and `verify_clients.sh`.
- Deployment paths, model flags, client commands, and gateway/tunnel wiring agree. The documented benchmark generator exactly reproduces the Heretic architecture tables.
- `bash -n`, Python AST parsing, TypeScript `--noEmit`, and ESLint passed. No production request, client verifier, or Playwright test was run.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| Finding | Verdict | What changed |
|---|---|---|
| #1 (unverified downloads) | Fixed for direct downloads | uv 0.12.19 (SHA-256 from GitHub's release digest), the vLLM 0.30.0 cu129 wheel (SHA-256 from GitHub's release digest) and Caddy 2.10.2 (SHA-512 from Caddy's checksums file) are downloaded to a file, verified, and only then installed; a mismatch stops the script. The uv and Caddy hashes were cross-checked by downloading both on 2026-09-29. The pod was stopped, so the fresh-pod install path is checked statically (`shellcheck`, URLs resolve) but not run. PyPI / PyTorch-index dependencies stay TLS-only, stated in `docs/SECURITY.md` |
| #2 (no password rate limit) | Accepted, documented | The user chose a short shared password; a limiter would not make it strong, and anyone with it can use the GPU either way. `docs/SECURITY.md` → Known weaknesses lists it with the real fix (per-user sign-in) |
| #3 (`id_ecdsa`, `id_dsa`) | Fixed | Added to `.gitignore` |
