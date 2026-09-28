#!/usr/bin/env python3
"""Run N real pi agents at once against one endpoint and score them: does the 4090 hold up for a team?

Each agent gets a fresh copy of a small Python repo with a failing unittest suite and one instruction. When pi exits,
the suite runs again; pass = exit 0. Wall time, pass rate and pi's exit status are recorded per agent.

usage: python3 bench/pi_team.py --base-url http://127.0.0.1:18080/v1 --engine llamacpp --tag q4kxl \
          --agents 1 4 8 [--thinking off] [--timeout 900]
Needs: pi on PATH, BENCH_API_KEY in the environment (the server's bearer key).
"""
import argparse, concurrent.futures as cf, json, os, pathlib, shutil, subprocess, sys, tempfile, textwrap, time

TASKS = {
    "stats": {
        "files": {
            "stats.py": '''\
                def mean(xs):
                    return sum(xs) / len(xs)


                def median(xs):
                    s = sorted(xs)
                    n = len(s)
                    return s[n // 2]


                def mode(xs):
                    counts = {}
                    for x in xs:
                        counts[x] = counts.get(x, 0) + 1
                    return max(counts, key=counts.get)
                ''',
            "test_stats.py": '''\
                import unittest
                from stats import mean, median, mode


                class T(unittest.TestCase):
                    def test_mean(self):
                        self.assertEqual(mean([1, 2, 3, 4]), 2.5)

                    def test_median_odd(self):
                        self.assertEqual(median([3, 1, 2]), 2)

                    def test_median_even(self):
                        self.assertEqual(median([4, 1, 3, 2]), 2.5)

                    def test_mean_empty(self):
                        with self.assertRaises(ValueError):
                            mean([])

                    def test_mode_tie_smallest(self):
                        self.assertEqual(mode([3, 3, 1, 1, 2]), 1)


                if __name__ == "__main__":
                    unittest.main()
                ''',
        },
        "prompt": "The unit tests in this repo fail. Run `python3 -m unittest -q`, fix stats.py (not the tests) until "
                  "every test passes, then stop.",
    },
    "slug": {
        "files": {
            "slug.py": '''\
                def slugify(text, max_len=None):
                    """Lowercase ASCII slug: words joined by single hyphens, no leading/trailing hyphen.
                    Non-alphanumeric characters separate words. Accented Latin letters lose their accents (é -> e).
                    If max_len is given, cut at a word boundary so the result is at most max_len characters."""
                    raise NotImplementedError
                ''',
            "test_slug.py": '''\
                import unittest
                from slug import slugify


                class T(unittest.TestCase):
                    def test_basic(self):
                        self.assertEqual(slugify("Hello, World!"), "hello-world")

                    def test_accents(self):
                        self.assertEqual(slugify("Crème Brûlée à la carte"), "creme-brulee-a-la-carte")

                    def test_collapse(self):
                        self.assertEqual(slugify("  a -- b__c  "), "a-b-c")

                    def test_max_len(self):
                        self.assertEqual(slugify("the quick brown fox", max_len=12), "the-quick")

                    def test_empty(self):
                        self.assertEqual(slugify("!!!"), "")


                if __name__ == "__main__":
                    unittest.main()
                ''',
        },
        "prompt": "Implement slugify in slug.py so that `python3 -m unittest -q` passes. Do not edit the tests.",
    },
    "lru": {
        "files": {
            "lru.py": '''\
                class LRUCache:
                    """Fixed-capacity cache. get(key) returns the value or None and marks the key most recently used.
                    put(key, value) inserts or updates and marks it most recently used; when over capacity, evict the
                    least recently used key. len(cache) is the number of keys held."""

                    def __init__(self, capacity):
                        self.capacity = capacity
                        self.data = {}

                    def get(self, key):
                        return self.data.get(key)

                    def put(self, key, value):
                        self.data[key] = value
                        if len(self.data) > self.capacity:
                            self.data.pop(next(iter(self.data)))

                    def __len__(self):
                        return len(self.data)
                ''',
            "test_lru.py": '''\
                import unittest
                from lru import LRUCache


                class T(unittest.TestCase):
                    def test_evicts_lru_not_oldest(self):
                        c = LRUCache(2)
                        c.put("a", 1); c.put("b", 2)
                        c.get("a")
                        c.put("c", 3)
                        self.assertIsNone(c.get("b"))
                        self.assertEqual(c.get("a"), 1)

                    def test_update_refreshes(self):
                        c = LRUCache(2)
                        c.put("a", 1); c.put("b", 2); c.put("a", 10); c.put("c", 3)
                        self.assertEqual(c.get("a"), 10)
                        self.assertIsNone(c.get("b"))

                    def test_capacity_zero(self):
                        c = LRUCache(0)
                        c.put("a", 1)
                        self.assertEqual(len(c), 0)


                if __name__ == "__main__":
                    unittest.main()
                ''',
        },
        "prompt": "test_lru.py fails. Fix lru.py so `python3 -m unittest -q` passes; keep the public API. Don't touch tests.",
    },
}
CHECK = [sys.executable, "-m", "unittest", "-q"]


def make_repo(root, name):
    d = pathlib.Path(root) / name
    d.mkdir(parents=True)
    for rel, body in TASKS[name.split("-")[0]]["files"].items():
        (d / rel).write_text(textwrap.dedent(body))
    subprocess.run(["git", "init", "-q"], cwd=d)
    subprocess.run(["git", "add", "."], cwd=d)
    subprocess.run(["git", "-c", "user.email=b@b", "-c", "user.name=b", "commit", "-qm", "task"], cwd=d)
    return d


def pi_home(root, args):
    home = pathlib.Path(root) / "pihome"
    home.mkdir()
    (home / "models.json").write_text(json.dumps({"providers": {"rtx4090": {
        "baseUrl": args.base_url, "api": "openai-completions", "apiKey": os.environ["BENCH_API_KEY"],
        "compat": {"supportsDeveloperRole": False, "supportsReasoningEffort": False,
                   "thinkingFormat": "qwen-chat-template", "maxTokensField": "max_tokens"},
        "models": [{"id": args.model, "name": f"{args.model} on 4090", "reasoning": True, "input": ["text"],
                    "contextWindow": args.context, "maxTokens": 16384,
                    "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0}}]}}}, indent=1))
    (home / "settings.json").write_text(json.dumps({"defaultProvider": "rtx4090", "defaultModel": args.model,
                                                     "defaultThinkingLevel": args.thinking}))
    return home


def run_one(repo, home, args):
    task = TASKS[repo.name.split("-")[0]]
    env = dict(os.environ, PI_CODING_AGENT_DIR=str(home), PI_OFFLINE="1")
    t0 = time.time()
    try:
        p = subprocess.run(["pi", "-p", "--no-session", "--mode", "json", "--model", f"rtx4090/{args.model}",
                            "--thinking", args.thinking, "--no-context-files", task["prompt"]],
                           cwd=repo, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                           timeout=args.timeout)
        rc, out, err = p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired as e:
        rc, out, err = "timeout", (e.stdout or b"").decode(errors="ignore") if isinstance(e.stdout, bytes) else (e.stdout or ""), ""
    wall = time.time() - t0
    (repo / "pi_events.jsonl").write_text(out or "")
    (repo / "pi_stderr.txt").write_text(err or "")
    tools = sum(1 for line in (out or "").splitlines() if '"tool_execution_start"' in line)
    turns = sum(1 for line in (out or "").splitlines() if '"turn_end"' in line)
    test_files = [f for f in task["files"] if f.startswith("test_")]
    tampered = subprocess.run(["git", "diff", "--quiet", "HEAD", "--", *test_files], cwd=repo).returncode != 0
    chk = subprocess.run(CHECK, cwd=repo, capture_output=True, text=True, timeout=60)
    return {"agent": repo.name, "pi_rc": rc, "wall_s": round(wall, 1), "tool_calls": tools, "turns": turns,
            "tests_pass": chk.returncode == 0 and not tampered, "tests_tampered": tampered}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base-url", required=True)
    ap.add_argument("--model", default="qwen3.8-27b")
    ap.add_argument("--engine", required=True)
    ap.add_argument("--tag", required=True)
    ap.add_argument("--agents", type=int, nargs="+", default=[1, 4, 8])
    ap.add_argument("--thinking", default="off", help="pi thinking level: off, low, medium, high")
    ap.add_argument("--context", type=int, default=65536)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--out", default="results/raw")
    ap.add_argument("--keep", action="store_true", help="keep the work dirs (printed)")
    args = ap.parse_args()
    if not os.environ.get("BENCH_API_KEY"):
        sys.exit("set BENCH_API_KEY")
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    cells = []
    names = list(TASKS)
    for n in args.agents:
        root = tempfile.mkdtemp(prefix=f"piteam-{n}-")
        home = pi_home(root, args)
        repos = [make_repo(root, f"{names[i % len(names)]}-{i}") for i in range(n)]
        t0 = time.time()
        with cf.ThreadPoolExecutor(n) as ex:
            rows = list(ex.map(lambda r: run_one(r, home, args), repos))
        wall = time.time() - t0
        cell = {"cell": f"pi_team_{n}", "agents": n, "wall_s": round(wall, 1),
                "pass": sum(r["tests_pass"] for r in rows), "timeouts": sum(r["pi_rc"] == "timeout" for r in rows),
                "agent_wall_p50_s": sorted(r["wall_s"] for r in rows)[len(rows) // 2],
                "agent_wall_max_s": max(r["wall_s"] for r in rows), "rows": rows}
        print(json.dumps({k: v for k, v in cell.items() if k != "rows"}), flush=True)
        cells.append(cell)
        if args.keep:
            print("kept", root, file=sys.stderr)
        else:
            shutil.rmtree(root, ignore_errors=True)
    meta = {"engine": args.engine, "tag": args.tag, "model": args.model, "scenario": "pi_team",
            "base_url": args.base_url, "thinking": args.thinking, "started": stamp, "argv": sys.argv[1:]}
    f = out / f"{args.engine}_{args.tag}_pi_team_{stamp}.summary.json"
    f.write_text(json.dumps({"meta": meta, "cells": cells}, indent=1))
    print("wrote", f, file=sys.stderr)


if __name__ == "__main__":
    main()
