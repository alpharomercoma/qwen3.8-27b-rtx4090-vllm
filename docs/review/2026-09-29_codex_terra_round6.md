# Codex QA, round 6: gpt-5.6-terra, reasoning xhigh, read-only (2026-09-29)

| Earlier finding (round-#) | Status (FIXED/PARTLY/NOT FIXED) | Note |
|---|---|---|
| round-1 #1 | FIXED | Pod public key is locally/remotely validated and base64-transferred. |
| round-1 #2 | FIXED | Proxy and direct pod SSH use pinned known-host files with strict checking. |
| round-1 #3 | FIXED | Final vLLM health check gates gateway/tunnel startup. |
| round-1 #4 | FIXED | Pi docs accurately describe thinking as off versus enabled. |
| round-1 #5 | FIXED | Operations uses complete pod-wrapper commands. |
| round-1 #6 | FIXED | Requested env, secret, key-directory, and SSH-key ignore rules work. |
| round-1 #7 | FIXED | Captured prompt uses a neutral path. |
| round-1 #8 | FIXED | Committed verifier transcript supports 13 s / 22 s. |
| round-1 #9 | FIXED | README review link resolves. |
| round-2 #1 | FIXED | Password prompt parses and reads correctly in zsh. |
| round-2 #2 | FIXED | Gateway/tunnel startup failures stop `start.sh`. |
| round-2 #3 | FIXED | Key updates use same-filesystem atomic rename. |
| round-2 #4 | FIXED | Unknown verifier selector exits 2. |
| round-2 #5 | FIXED | 85.2 s public and 68.5 s pod maxima are correctly scoped. |
| round-3 #1 | FIXED | zsh-safe deployment command remains present. |
| round-3 #2 | FIXED | Dialog uses provider-merge commands. |
| round-3 #3 | FIXED | Download-complete marker gates model reuse. |
| round-3 #4 | FIXED | Public 401 check gates the “up” message. |
| round-3 #5 | FIXED | All key commands are copyable. |
| round-4 #1 | PARTLY | Direct installer artifacts are hash-verified; PyPI/PyTorch dependencies remain TLS-only as accepted/documented. |
| round-4 #2 | NOT FIXED | Accepted disposition; no durable password limiter was added. |
| round-4 #3 | FIXED | ECDSA and DSA private-key patterns are ignored. |
| round-5 #1 | FIXED | Bootstrap gate checks all required tools plus nonempty vLLM key. |
| round-5 #2 | FIXED | Chat has a 280 s abort and incomplete-answer UI state. |
| round-5 test locator | FIXED | E2E composer selector is exact-role based. |

| # | Severity (HIGH/MED/LOW) | File:line | Problem | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | MED | `pod/fetch_model.sh:8-12` | Fresh deployments download a mutable Hugging Face `main` revision, with no immutable commit or model-file manifest. The served model can silently change. | `REV` defaults to `main`; no checkpoint revision or checksum appears in deployment/security docs. | Pin an immutable HF commit and verify a committed SHA-256 manifest before writing `.download-complete`. |
| 2 | LOW | `docs/ARCHITECTURE.md:111-118` | Network-path measurements are presented as evidence-backed but their raw evidence is not committed. | The evidence inventory contains no ping, `ss -ti`, upload-probe, TTFT-probe, or tunnel-reconnect transcript; the quoted loss/transfer/reconnect values do not occur there. | Commit redacted command outputs, or label these values as unarchived observations. |

Checked and fine:

- Audited all 287 non-ignored commit candidates. No actual credential, private-key block, or personal home path was found; token-looking hits are placeholders/generators, and home-path matches are generic review/scrubber references.
- Ignore rules cover `.env`, `.pod_env`, `.vercel`, app `.env.local`, `.secrets`, `keys/`, PEM/key files, and RSA/Ed25519/ECDSA/DSA names.
- Pi 0.87.1 accepts the documented schema and emits Qwen `chat_template_kwargs`; OpenCode 1.18.23 supports the documented model/run flags.
- Deployment commands parse in zsh; gateway/authz, routing, tunnel restrictions, and model flags agree across code and docs.
- Heretic architecture tables exactly regenerate from committed summaries; key KV, max-wait, and verifier claims match committed evidence.
- Benchmark docs only mark Cloudflare as superseded and direct readers to reverse SSH.
- Shell parsing, Python AST parsing, TypeScript no-emit, and ESLint passed. No production request, E2E, or client verifier was run.

VERDICT: NEEDS FIXES


## Resolution (2026-09-29)

| Finding | Verdict | What changed |
|---|---|---|
| #1 (model revision `main`) | Fixed | `pod/fetch_model.sh` downloads commit `0a191462511776109c129dda0772d33ae9b85be9` (the latest, 2026-08-17) and checks all 22 files with `sha256sum -c` against `pod/qwen38-heretic-ara-w4a16.sha256` before writing `.download-complete`; another repo requires an explicit `REV`. Manifest: Hugging Face's LFS SHA-256 for the 12 large files, and hashes of the 10 small files downloaded at that commit. Tested: four real files pass, a tampered one fails |
| #2 (network numbers unarchived) | Fixed | `results/evidence/network_path_2026-09-28.txt` holds every ping, `ss -ti`, TTFT-probe, upload-probe, streaming and reconnect number (transcribed from the session, labelled as such); linked from `docs/ARCHITECTURE.md` |
