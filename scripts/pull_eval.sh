#!/bin/bash
# MAC. Copy the benchmark results (/workspace/eval/results: answers, scores, timings) and the dataset manifest into
# results/eval/. Never /workspace/eval/private, which holds the answers to harmful requests. The copy is unpacked
# into a staging directory and checked first, so a failed transfer leaves the previous results/eval/ in place.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
mkdir -p "$HERE/results"
stage=$(mktemp -d "$HERE/results/.eval-pull.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ssh "${POD_SSH_OPTS[@]}" "$POD_SSH_HOST" 'tar -C /workspace/eval/results -czf - . -C /workspace/eval/data manifest.json' |
  tar -C "$stage" -xzf -
for f in manifest.json summary.json summary.md run_metadata.json; do [ -s "$stage/$f" ] || { echo "missing $f in the pulled results" >&2; exit 1; }; done
python3 - "$stage" "$HERE/bench/evals/evalsuite.py" <<'PY'
import hashlib, json, pathlib, sys
d = pathlib.Path(sys.argv[1])
for p in d.rglob("jbb_harmful*.jsonl"):  # never an answer to a harmful request, at any depth
    for line in open(p):
        if "response" in json.loads(line):
            sys.exit(f"{p.relative_to(d)} contains answer text: not copying")
S = json.loads((d / "summary.json").read_text())
man = json.loads((d / "manifest.json").read_text())
meta = json.loads((d / "run_metadata.json").read_text())
gaps = []
if meta.get("evalsuite_sha256") != hashlib.sha256(pathlib.Path(sys.argv[2]).read_bytes()).hexdigest():
    gaps.append("run_metadata.json was written by another evalsuite.py than this checkout's: push, re-score, rerun metadata")
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
for f, h in meta.get("summary_sha256", {}).items():  # the summaries are the ones the metadata saw
    if not (d / f).exists() or sha(d / f) != h:
        gaps.append(f"{f} differs from the one run_metadata.json recorded")
if len(meta.get("summary_sha256", {})) != 2:
    gaps.append("run_metadata.json has no summary hashes")
inputs = S.get("inputs_sha256", {})  # every raw file the summary was computed from, unchanged
for rel, h in inputs.items():
    if rel.startswith("data/"):  # the prompts and gold answers stay on the pod; manifest.json pins their source
        if rel == "data/manifest.json" and sha(d / "manifest.json") != h:
            gaps.append("manifest.json differs from the one scored")
        continue
    if not (d / rel).exists() or sha(d / rel) != h:
        gaps.append(f"{rel} differs from the file summary.json was computed from")
if not inputs:
    gaps.append("summary.json lists no inputs")
if S.get("incomplete"):
    gaps.append(f"summary.json was scored from incomplete results: {S['incomplete'][:3]}")
MODELS, JUDGES = ["qwen3.8-27b", "qwen3.8-27b-heretic"], ["qwen3.8-27b", "qwen3.8-27b-heretic"]
ITEMS = {"gsm8k": 1319, "mmlu_pro": 1400, "ifeval": 541, "humaneval": 164, "jbb_harmful": 100, "jbb_benign": 100,
         "harmless": 200}  # what docs/EVAL.md reports: pinned here, not taken from the pod
if {t: v.get("items") for t, v in man.items()} != ITEMS:
    gaps.append(f"manifest.json tasks/items {({t: v.get('items') for t, v in man.items()})} are not {ITEMS}")
# only these files, nothing else, may come from the pod
allowed = {"manifest.json", "summary.json", "summary.md", "run_metadata.json"}
allowed |= {f"judge_canaries_{j}.json" for j in JUDGES}
for m in MODELS:
    allowed |= {f"{m}/{t}.jsonl" for t in ITEMS} | {f"{m}/timing.jsonl"}
    allowed |= {f"{m}/{t}_judge_{j}.jsonl" for t in ("jbb_harmful", "jbb_benign") for j in JUDGES}
    allowed |= {f"judge_prompts/{v}/{m}/{t}_judge_{j}.jsonl" for v in "AB" for t in ("jbb_harmful", "jbb_benign") for j in JUDGES}
allowed |= {f"judge_prompts/{v}/judge_canaries_{j}.json" for v in "AB" for j in JUDGES}
present = {str(p.relative_to(d)) for p in d.rglob("*") if p.is_file()}
if extra := sorted(present - allowed - {"README.md"}):
    gaps.append(f"unexpected files: {extra[:10]}")
HARMFUL_KEYS = {"id", "prompt_sha256", "max_tokens", "latency_s", "finish_reason", "prompt_tokens", "completion_tokens",
                "response_sha256", "response_chars", "refusal_markers"}  # an error row has no place here either
for m in MODELS:  # answers to harmful requests: only these fields, never text
    for r in map(json.loads, open(d / m / "jbb_harmful.jsonl")) if (d / m / "jbb_harmful.jsonl").exists() else []:
        if set(r) - HARMFUL_KEYS:
            sys.exit(f"{m}/jbb_harmful.jsonl has fields {sorted(set(r) - HARMFUL_KEYS)}: not copying")
if S.get("models") != MODELS or S.get("judges") != JUDGES:
    gaps.append(f"summary.json models {S.get('models')} / judges {S.get('judges')}, expected {MODELS} / {JUDGES}")
S["models"], S["judges"] = MODELS, JUDGES
def rows(p):
    return sum(1 for _ in open(p)) if p.exists() else None
for m in S["models"]:  # every task's answers, every judge's verdicts, timing: all items, for both models
    for task, info in ((t, {"items": n}) for t, n in ITEMS.items()):
        rs = [json.loads(l) for l in open(d / m / f"{task}.jsonl")] if (d / m / f"{task}.jsonl").exists() else []
        ids = [r["id"] for r in rs]
        answered = "response_sha256" if task == "jbb_harmful" else "response"
        if any("error" in r or answered not in r for r in rs):
            gaps.append(f"{m}/{task}.jsonl: rows without an answer")
        if len(set(ids)) != info["items"] or len(ids) != len(set(ids)):
            gaps.append(f"{m}/{task}.jsonl: {len(set(ids))} of {info['items']} items, {len(ids) - len(set(ids))} duplicates")
    for t in ("jbb_harmful", "jbb_benign"):
        ids = {json.loads(l)["id"] for l in open(d / m / f"{t}.jsonl")} if (d / m / f"{t}.jsonl").exists() else set()
        for j in S["judges"]:
            f = d / m / f"{t}_judge_{j}.jsonl"
            v = [json.loads(l) for l in open(f)] if f.exists() else []
            if sorted(r["id"] for r in v) != sorted(ids) or len(ids) != man[t]["items"] or any(
                    r.get("judge") != j or not isinstance(r.get("refused"), bool) or r.get("raw") not in ("Yes", "No")
                    or r["refused"] != (r["raw"] == "Yes") for r in v):
                gaps.append(f"{m}/{t}_judge_{j}.jsonl: not one valid Yes/No verdict per answer")
    if not rows(d / m / "timing.jsonl"):
        gaps.append(f"{m}/timing.jsonl missing")
for j in S["judges"]:
    c = d / f"judge_canaries_{j}.json"
    res = json.loads(c.read_text()) if c.exists() else []
    if len(res) != 2 or any(r["expected"] != r["got"] for r in res):
        gaps.append(f"judge_canaries_{j}.json missing or failed")
for v in ("A", "B"):  # the earlier judge prompts behind EVAL.md's sensitivity table: REFUSED / COMPLIED verdicts
    for m in S["models"]:
        for t in ("jbb_harmful", "jbb_benign"):
            ids = {json.loads(l)["id"] for l in open(d / m / f"{t}.jsonl")} if (d / m / f"{t}.jsonl").exists() else set()
            for j in S["judges"]:
                f = d / "judge_prompts" / v / m / f"{t}_judge_{j}.jsonl"
                rs = [json.loads(l) for l in open(f)] if f.exists() else []
                if sorted(r["id"] for r in rs) != sorted(ids) or len(ids) != man[t]["items"] or any(
                        r.get("judge") != j or not isinstance(r.get("refused"), bool)
                        or r.get("raw") not in ("REFUSED", "COMPLIED") or r["refused"] != (r["raw"] == "REFUSED")
                        for r in rs):
                    gaps.append(f"judge_prompts/{v}/{m}/{t}_judge_{j}.jsonl: not one valid verdict per answer")
if gaps:
    sys.exit("incomplete results, not copying:\n  " + "\n  ".join(gaps))
PY
[ -f "$HERE/results/eval/README.md" ] && cp "$HERE/results/eval/README.md" "$stage/"   # written here, not on the pod
chmod 755 "$stage"   # private (mktemp's 700) until the checks above passed
rm -rf "$HERE/results/eval" && mv "$stage" "$HERE/results/eval"
trap - EXIT
ls -la "$HERE/results/eval"
