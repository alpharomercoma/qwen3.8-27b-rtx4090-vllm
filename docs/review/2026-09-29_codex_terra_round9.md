# Codex QA, round 9: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Earlier finding (round-#) | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| round-1 #1–#9 | FIXED | Key transfer/pinning, readiness gating, ignore rules, Pi wording, commands, evidence, and review link all verify. |
| round-2 #1–#5 | FIXED | zsh password prompt, failure gates, atomic key writes, verifier usage error, and performance scoping verify. |
| round-3 #1–#5 | FIXED | Config merge commands, completion marker, public-401 readiness check, and Operations commands verify. |
| round-4 #1 | PARTLY | Direct uv, vLLM, and Caddy artifacts are hash-checked; Python dependency resolution remains TLS-only as documented. |
| round-4 #2 | NOT FIXED | No durable password-attempt limiter; marked Accepted and documented, therefore out of scope. |
| round-4 #3 | FIXED | RSA, Ed25519, ECDSA, and DSA private-key-name ignores work. |
| round-5 #1–#2, locator | FIXED | Bootstrap prerequisites/directories, 280-second answer limit, incomplete-answer UI, and exact E2E composer locator are present. |
| round-6 #1–#2 | FIXED | Model revision is pinned with a structurally valid 22-file manifest; network evidence is committed. |
| round-7 #1 | FIXED | The edge’s 15-minute response-header limit is configured and documented. |
| round-8 #1–#2 | FIXED | `Match all` terminates the SSH block; fresh-start calls use `POD_TIMEOUT=1800` and 15–25 minute guidance. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | LOW | `docs/review/2026-09-29_codex_terra_round8.md:23` | A personal home path is still in the commit set, while the sentence asserts none exists. | Exact-candidate scan finds the literal `a personal home path` at this line. | Replace it with neutral wording such as “personal home path,” without the literal path. |

Checked and fine:

- Audited the exact current commit set: 292 non-ignored files.
- Protected env/Vercel paths, `.secrets`, `keys/`, PEM/key extensions, and common SSH private-key names are ignored.
- Broad credential scans found no actual API key, JWT, GitHub/Hugging Face token, or private-key block. The only `sk-` matches are documented paste placeholders.
- `authz.env` was checked structurally only: four expected nonempty OIDC assignments; no values displayed.
- Pi 0.87.1 supports the documented compatible-provider shape, environment interpolation, and Qwen chat-template compatibility. OpenCode 1.18.23 supports the documented model/run configuration.
- `bash -n` passed for shell scripts; web typecheck and ESLint passed.
- `bench/service_tables.py` exactly reproduces the Heretic tables in `ARCHITECTURE.md`; raw summaries and committed evidence support the cited performance, client-verifier, KV, and network figures.
- Benchmark documentation treats Cloudflare Tunnel as superseded and directs readers to reverse SSH.
- No production request, client verifier, or Playwright suite was run.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| Finding | Verdict | What changed |
|---|---|---|
| #1 (home path in a review record) | Fixed | The literal came from Codex's own round-8 text. `scripts/strip_review_paths.py` now also replaces bare home paths; all review files were rescrubbed and the affected sentences reworded. A scan of every file to be committed finds no `/Users/<name>` or `/home/<name>` path |
