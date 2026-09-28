#!/usr/bin/env python3
"""Engine-comparison tables from results/raw/*.summary.json, spliced into docs/benchmarks/FINDINGS.md between
<!-- BEGIN:compare --> and <!-- END:compare --> (nothing inside the markers is typed by hand).
A cell that was not measured prints as "not run". usage: python3 bench/compare.py [docs/benchmarks/FINDINGS.md]"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
rows = {}
for f in (ROOT / "results/raw").glob("*.summary.json"):
    j = json.loads(f.read_text())
    m = j["meta"]
    for c in j["cells"]:
        rows[(m["engine"], m["tag"], c["cell"])] = c

CFGS = [  # (engine, tag, label)
    ("ollama", "p4", "Ollama 0.34.3, `qwen3.8:27b` (Q4_K_M, MTP on by default)"),
    ("llamacpp", "q4kxl", "llama.cpp b11118, UD-Q4_K_XL, 8 slots, 64k shared q8_0 KV"),
    ("sglang", "int4", "SGLang 0.5.19, INT4 W4A16, fp8 KV, 4 running requests"),
    ("vllm", "int4", "vLLM 0.30.0, INT4 W4A16, fp8 KV (85k-token pool)"),
    ("vllm", "int4-kv4", "vLLM 0.30.0, INT4 W4A16, int4 KV (181k-token pool)"),
    ("vllm", "int4-kv4-mtp", "vLLM 0.30.0, INT4 W4A16, int4 KV + MTP 2 (109k-token pool)"),
    # host 2 (2026-09-24): same volume, driver 580 / CUDA 13
    ("vllm", "int4-kv4-h2", "host 2: vLLM 0.30.0 (cu129 wheel), int4 KV, same flags (298k-token pool)"),
    ("vllm", "int4-kv4-pin-h2", "host 2: vLLM 0.30.0, int4 KV, KV memory pinned at 4.5 GiB (recommended)"),
    ("vllm", "int4-097-h2", "host 2: vLLM 0.30.0, fp8 KV at 0.97 of VRAM"),
    ("ollama", "gptoss-h2", "gpt-oss-20b: Ollama 0.34.4, gpt-oss:20b (MXFP4 experts), 4 parallel requested"),
    ("llamacpp", "gptoss-h2", "gpt-oss-20b: llama.cpp b11118, ggml-org MXFP4 GGUF, 8 slots, 128k shared f16 KV"),
    ("sglang", "gptoss-h2", "gpt-oss-20b: SGLang 0.5.20, bf16 KV, 16 running"),
    ("vllm", "gptoss-h2", "gpt-oss-20b: vLLM 0.30.0, bf16 KV, KV memory pinned at 6 GiB"),
    ("sglang", "int4-v0520", "host 2: SGLang 0.5.20 (CUDA 13), same flags as sglang/int4"),
]
NR = "not run"


def g(cfg, cell, key, fmt="{}"):
    c = rows.get(cfg[:2] + (cell,))
    if c is None:
        return NR
    v = c.get(key)
    return "n/a" if v is None else fmt.format(v)


def decode_cell(cfg, c):
    cell = rows.get(cfg[:2] + (f"decode_c{c}",))
    if cell is None:
        return NR
    if cell.get("errors") and cell["errors"] == cell.get("n"):
        return f"server down: {cell['errors']}/{cell['n']} failed"
    return (f"{g(cfg, f'decode_c{c}', 'user_decode_tok_s_p50')} / {g(cfg, f'decode_c{c}', 'agg_out_tok_s', '{:.0f}')} / "
            f"{g(cfg, f'decode_c{c}', 'ttft_p50_s', '{:.1f}')} s")


def table(head, lines):
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    out += ["| " + " | ".join(str(x) for x in r) + " |" for r in lines]
    return "\n".join(out)


def build():
    parts = ["Configs:\n"] + [f"- **{e}/{t}**: {label}" for e, t, label in CFGS]
    parts.append("\n#### Prefill: one request at a time, tokens/s (prompt tokens / time to first token)\n")
    L = [1024, 4096, 8192, 16384, 32768]
    parts.append(table(["config"] + [f"{x // 1024}k" for x in L] + ["mean tokens processed, 32k cell"],
                       [[f"{e}/{t}"] + [g((e, t), f"prefill_{x}", "prefill_tok_s_p50", "{:,.0f}") for x in L]
                        + [g((e, t), "prefill_32768", "in_tokens_mean", "{:,.0f}")] for e, t, _ in CFGS]))
    parts.append("\n#### Decode under concurrency: 1k-token prompts, 256 tokens out. "
                 "Cell = per-user tok/s p50 / total tok/s / time to first token p50\n")
    C = [1, 2, 4, 8, 16]
    parts.append(table(["config"] + [f"{c} at once" for c in C],
                       [[f"{e}/{t}"] + [decode_cell((e, t), c) for c in C] for e, t, _ in CFGS]))
    parts.append("\n#### Agent sessions: pi's system prompt + 4 tools, 8 turns, ~1.5k tokens of tool output per turn, "
                 "150 tokens out, context grows to ~12.6k. Cell = per-turn TTFT p50 / p90, per-user tok/s, "
                 "prefix-cache share, session time p50, failed requests\n")
    U = [1, 2, 4, 8, 12, 16]
    lines = []
    for e, t, _ in CFGS:
        r = [f"{e}/{t}"]
        for u in U:
            k = f"agent_u{u}"
            if (e, t, k) not in rows:
                r.append(NR)
                continue
            r.append(f"{g((e, t), k, 'turn_ttft_p50_s', '{:.1f}')} / {g((e, t), k, 'turn_ttft_p90_s', '{:.1f}')} s, "
                     f"{g((e, t), k, 'user_decode_tok_s_p50')} tok/s, {g((e, t), k, 'cached_share', '{:.0%}')}, "
                     f"{g((e, t), k, 'session_s_p50', '{:.0f}')} s, {g((e, t), k, 'errors')} err")
        lines.append(r)
    parts.append(table(["config"] + [f"{u} agents" for u in U], lines))
    ol = [rows.get(("ollama", "p4", f"agent_u{u}"), {}).get("out_tokens_mean") for u in U]
    go = [c.get("out_tokens_mean") for (e, t, k), c in rows.items() if t == "gptoss-h2" and k.startswith("agent_u")]
    parts.append(f"\nOutput length: Qwen3.8 agent turns were forced to 150 tokens except on Ollama (no `ignore_eos`), "
                 f"whose `ollama/p4` turns averaged {', '.join(str(x) for x in ol if x)} tokens. All gpt-oss agent turns "
                 f"stopped naturally ({min(go):.0f} to {max(go):.0f} tokens), because forcing length broke vLLM's gpt-oss "
                 "parser. Compare turn waits (TTFT) across these rows, not session times. SGLang and Ollama do not report "
                 "cached tokens (n/a).")
    pis = []
    for f in sorted((ROOT / "results/raw").glob("*_pi_team_*.summary.json")):
        j = json.loads(f.read_text())
        for c in j["cells"]:
            pis.append([j["meta"]["engine"] + "/" + j["meta"]["tag"], j["meta"]["thinking"], c["agents"],
                        f"{c['pass']}/{c['agents']}", c["timeouts"], c["wall_s"], c["agent_wall_p50_s"],
                        c["agent_wall_max_s"], sum(r["tool_calls"] for r in c["rows"])])
    if pis:
        parts.append("\n#### Real pi agents from the Mac (SSH tunnel), small repos with failing tests\n")
        parts.append(table(["server", "pi thinking", "agents at once", "tests pass", "timeouts", "wall s",
                            "agent s p50", "agent s max", "tool calls"], pis))
    return "\n".join(parts)


if __name__ == "__main__":
    path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs" / "benchmarks" / "FINDINGS.md"
    text = path.read_text()
    new = re.sub(r"(<!-- BEGIN:compare -->).*?(<!-- END:compare -->)",
                 lambda m: m.group(1) + "\n" + build() + "\n" + m.group(2), text, flags=re.S)
    path.write_text(new)
    print(f"updated {path}")
