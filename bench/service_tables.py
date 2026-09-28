"""Markdown tables for docs/ARCHITECTURE.md from results/raw/vllm_heretic-*.summary.json: the production service
(Heretic W4A16 on vLLM) measured on the pod and through the public URL. usage: python3 bench/service_tables.py"""
import glob, json, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
RUNS = {  # tag -> label
    "heretic-pod": "On the pod, 246k pool",
    "heretic-kv55-pod": "On the pod, 301k pool",
    "heretic-public": "Public URL, before TCP tuning",
    "heretic-public-tuned": "Public URL, BBR + compression",
}


def cells():
    out = {}
    for f in sorted(glob.glob(str(ROOT / "results/raw/vllm_heretic-*.summary.json"))):
        tag = pathlib.Path(f).name.split("_")[1]
        if tag not in RUNS:
            continue
        for c in json.load(open(f))["cells"]:
            out[(tag, c["cell"])] = c  # a later file with the same cell wins
    return out


def fmt(c, keys):
    return [("-" if c.get(k) is None else f"{c[k]:.1f}" if isinstance(c[k], float) else str(c[k])) for k in keys]


def main():
    data = cells()
    agent_cells = ["agent_u1", "agent_u4", "agent_u8", "agent_u12", "agent_u16"]
    print("Agent sessions (pi's system prompt and tools, 8 turns, 1,500-token tool results, 150-token answers):\n")
    print("| Run | Agents | Requests | Errors | Turn wait p50 (s) | p90 (s) | tok/s per user | Input from cache |")
    print("|---|---|---|---|---|---|---|---|")
    for tag, label in RUNS.items():
        for cell in agent_cells:
            c = data.get((tag, cell))
            if c:
                share = f"{c['cached_share']:.0%}" if c.get("cached_share") is not None else "-"
                print(f"| {label} | {c['users']} | {c['n']} | {c['errors']} | "
                      + " | ".join(fmt(c, ["turn_ttft_p50_s", "turn_ttft_p90_s", "user_decode_tok_s_p50"])) + f" | {share} |")
    print("\nTeams (each user's agents share a 6k-token repo context; ~13-14k-token prompts):\n")
    print("| Run | Shape | Requests | Errors | Turn wait p50 (s) | p90 (s) | Per user p50 (s) |")
    print("|---|---|---|---|---|---|---|")
    for tag, label in RUNS.items():
        for cell in ["team_3+3+3+3", "team_8+1+1+1+1"]:
            c = data.get((tag, cell))
            if c:
                per = ", ".join(f"{u['agents']}:{u['turn_ttft_p50_s']:.1f}" for u in c["per_user"])
                shape = cell.split("_")[1].replace("+", " + ")
                print(f"| {label} | {shape} agents | {c['n']} | {c['errors']} | "
                      + " | ".join(fmt(c, ["turn_ttft_p50_s", "turn_ttft_p90_s"])) + f" | {per} |")


main()
