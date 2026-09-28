# Codex QA, round 10: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Earlier finding (round-#) | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| round-1 #1–#9 | FIXED | Key transfer is validated/encoded; SSH is pinned; readiness gates, Pi wording, commands, ignores, evidence, and review link all verify. |
| round-2 #1–#5 | FIXED | zsh-safe password setup, failure gates, atomic key updates, verifier usage error, and performance scoping verify. |
| round-3 #1–#5 | FIXED | Provider merge commands, model completion marker, public-401 readiness check, and Operations commands verify. |
| round-4 #1 | PARTLY | Direct uv, vLLM, and Caddy downloads are hash-verified; TLS-only Python dependency resolution remains the documented Accepted limitation. |
| round-4 #3 | FIXED | RSA, Ed25519, ECDSA, and DSA private-key filename patterns are ignored. |
| round-5 #1–#2 and E2E locator | FIXED | Bootstrap prerequisite gate, 280-second answer limit/incomplete UI, and exact composer selector are present. |
| round-6 #1–#2 | FIXED | Model revision is pinned with a valid 22-file manifest; network evidence is committed. |
| round-7 #1 | FIXED | The edge’s 15-minute response-header timeout is configured and documented. |
| round-8 #1–#2; round-9 #1 | FIXED | `Match all`, 30-minute fresh-start calls, and review-path scrubbing verify. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | MED | `pod/gateway/authz.py:55,100,145,160` | Unauthenticated JWT-shaped requests can cause repeated JWKS work in an unbounded-thread server. | Any bearer token containing two dots reaches `PyJWKClient.get_signing_key_from_jwt`; an unknown `kid` can refresh JWKS, with a 10-second timeout. `ThreadingHTTPServer` has no concurrency bound or request rate limit. This can starve gateway authentication and make valid requests fail. | Reject oversized tokens, negative-cache unknown `kid`s, serialize refreshes, bound authz concurrency, and rate-limit `/v1/*` at the edge. |
| 2 | LOW | `.gitignore:4-5` | Root `.envrc` is not ignored. | `git check-ignore --no-index .envrc` reports it is not ignored; `.env.*` requires the literal dot after `env`. An `.envrc` commonly holds exported credentials. | Add `.envrc` (or a carefully scoped equivalent) to root `.gitignore`. |
| 3 | LOW | `pod/bootstrap.sh:4,8-11,23-27` | Bootstrap can report success after a prerequisite-install failure. | It has `set -x`, not `set -euo pipefail`; failed `apt-get` or `uv tool install` can be followed by later commands and `BOOTSTRAP_DONE`, so `start.sh` proceeds and fails less clearly later. | Enable strict shell options and explicitly verify required tools/CUDA before printing completion. |

Checked and fine:

- Reviewed the exact current pending set: 293 non-ignored files. No actual credential, private-key block, JWT, GitHub/Hugging Face token, web password, or personal home path was found; `sk-heretic` hits are placeholders or generation code.
- Required protected paths are ignored, including `.env`, `.pod_env`, app `.env.local`, `.vercel`, `.secrets`, and files under `keys/`.
- Pi 0.87.1 documentation supports the configured compatible-provider fields and Qwen thinking behavior; the dialog matches `CLIENTS.md`. OpenCode 1.18.23 exposes the documented `run -m` usage, and committed verifier evidence supports the config.
- Deploy/Operations/README/pod/edge instructions agree with the scripts; Cloudflare is historical or explicitly superseded in benchmark docs.
- Generated service tables exactly match the Heretic raw summaries; evidence supports the cited verifier, cache, network, and maximum-wait figures.
- Shell parsing, Python AST parsing, TypeScript `--noEmit`, and ESLint passed. No production request, client verifier, or Playwright run was made. No files were modified.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| Finding | Verdict | What changed |
|---|---|---|
| #1 (JWKS work from forged tokens, unbounded threads) | Fixed | `authz.py` no longer uses `PyJWKClient`. Tokens over 4 KB, non-RS256, without a `kid`, or with a different unverified issuer are refused before any network or signature work. Its own key cache refreshes hourly and, for an unknown `kid`, at most once a minute (also after a failed fetch). At most 64 checks run at once; more get 503. Tested locally: 50 forged tokens with made-up `kid`s refused in 0.53 s total with no extra fetches; a real Vercel OIDC token passed signature verification against Vercel's live keys and was refused only for its `development` environment; 400 parallel team-key checks all 200. The stopped production pod gets the new file on its next `push.sh` + `start.sh` |
| #2 (`.envrc`) | Fixed | Added to `.gitignore` |
| #3 (`bootstrap.sh` not strict) | Fixed | `set -euxo pipefail`, and it ends by checking `tmux`, `jq`, `uv`, `hf`, CUDA 12.8's `nvcc` and `/workspace/.api_key`, failing loudly otherwise |
