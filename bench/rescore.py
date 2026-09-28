#!/usr/bin/env python3
"""Recompute a run's cell summaries from its raw rows with the current failure rule, keeping the original summary
as *.summary.orig.json. Rule added 2026-09-24: a streamed request that ended without usage counts and without a
finish reason was cut off mid-stream (llama.cpp sent an error chunk), so it counts as failed even if tokens arrived.
usage: python3 bench/rescore.py results/raw/<run>.jsonl"""
import json, pathlib, shutil, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from loadgen import summarize, pct  # noqa: E402

raw = pathlib.Path(sys.argv[1])
summ = raw.with_suffix(".summary.json")
orig = raw.with_suffix(".summary.orig.json")
if not orig.exists():
    shutil.copy(summ, orig)
j = json.loads(orig.read_text())
rows = [json.loads(l) for l in raw.read_text().splitlines()]
changed = 0
for r in rows:
    if r.get("ok") and r.get("n_in") in (None, 0) and r.get("finish") is None:
        r["ok"], r["error"] = False, "cut off mid-stream (no usage, no finish reason)"
        changed += 1
cells = []
for c in j["cells"]:
    rs = [r for r in rows if r["cell"] == c["cell"]]
    new = summarize(rs, c["wall_s"])
    keep = {k: c[k] for k in ("concurrency", "users", "final_ctx_tokens_max", "session_s_p50", "session_s_max") if k in c}
    later = [r for r in rs if r["ok"] and r.get("turn", 0) > 0]
    if "users" in c and later:
        new["turn_ttft_p50_s"] = round(pct([r["ttft_s"] for r in later], 50), 3)
        new["turn_ttft_p90_s"] = round(pct([r["ttft_s"] for r in later], 90), 3)
    cells.append({"cell": c["cell"], **keep, **new})
j["cells"] = cells
j["meta"]["rescored"] = f"bench/rescore.py: {changed} rows re-marked as failed (cut off mid-stream)"
summ.write_text(json.dumps(j, indent=1))
print(f"{raw.name}: {changed} rows re-marked; wrote {summ.name} (original kept as {orig.name})")
