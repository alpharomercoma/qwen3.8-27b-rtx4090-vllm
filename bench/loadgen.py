#!/usr/bin/env python3
"""Load generator for OpenAI-compatible and Ollama-native chat servers. One client for every engine.

Scenarios
  prefill  : one request at a time, input lengths swept, 1 output token -> prefill tok/s = prompt_tokens / TTFT
  decode   : fixed input/output, concurrency swept -> TTFT, per-user decode tok/s (1/TPOT), aggregate output tok/s
  agent    : N concurrent multi-turn sessions shaped like a coding agent (system+tools prefix, tool results appended
             every turn, prefix reused) -> per-turn TTFT, decode tok/s, session wall time, cached-token share
  team     : several users, each running several agents that share that user's repo context before their tasks
             diverge -> per-user turn TTFT (fairness), cached share on the first turn (cross-agent prefix reuse)
  retention: build a session, stay idle for D seconds (optionally under background agent load), send the next turn
             -> share of the context still cached and time to first token after each idle gap

Prompts are real source code (this interpreter's stdlib) cut at random offsets, each behind a unique salt line so
requests never share a prefix unless the scenario wants them to. Token counts come from the server's usage block.

usage: uv run --with aiohttp bench/loadgen.py --base-url http://127.0.0.1:8000/v1 --model qwen3.8-27b \
          --engine sglang --tag awq-int4 --out results/raw prefill|decode|agent [scenario options]
"""
import argparse, asyncio, json, os, random, statistics, sys, sysconfig, time, uuid, pathlib, platform

import aiohttp

# ---------------------------------------------------------------- corpus

def load_corpus(max_chars=6_000_000):
    root = pathlib.Path(sysconfig.get_paths()["stdlib"])
    parts, n = [], 0
    for p in sorted(root.rglob("*.py")):
        if {"test", "tests", "idlelib", "encodings", "pydoc_data", "lib2to3"} & set(p.parts):
            continue
        try:
            t = p.read_text(errors="ignore")
        except OSError:
            continue
        # skip data tables (charmaps, unicode tables): their token density is far from ordinary code
        if sum(ord(ch) > 127 for ch in t) > 0.002 * len(t) or t.count("\\u") + t.count("\\x") > 0.002 * len(t):
            continue
        parts.append(f"# file: {p.relative_to(root)}\n{t}\n")
        n += len(t)
        if n > max_chars:
            break
    return "".join(parts)


CORPUS = None


def code_slice(rng, n_chars):
    start = rng.randrange(0, len(CORPUS) - n_chars - 1)
    return CORPUS[start:start + n_chars]


# ---------------------------------------------------------------- one request

class Result(dict):
    pass


async def chat(session, args, messages, max_tokens, *, ignore_eos, tools=None):
    """Stream one chat completion. Returns timing + usage. Never raises: errors go in the row."""
    r = Result(ok=False, t_start=time.time())
    t0 = time.perf_counter()
    first = last = None
    n_chunks = 0
    usage = {}
    text_len = 0
    finish = None
    try:
        if args.api == "ollama":
            url = args.base_url.rstrip("/") + "/api/chat"
            body = {"model": args.model, "messages": messages, "stream": True, "think": args.think,
                    "options": {"num_predict": max_tokens, "temperature": args.temperature}}
            if args.num_ctx:
                body["options"]["num_ctx"] = args.num_ctx
            if tools:
                body["tools"] = tools
        else:
            url = args.base_url.rstrip("/") + "/chat/completions"
            body = {"model": args.model, "messages": messages, "max_tokens": max_tokens, "stream": True,
                    "temperature": args.temperature, "stream_options": {"include_usage": True}}
            if ignore_eos and not args.no_ignore_eos:
                body["ignore_eos"] = True
            if not args.think:
                body["chat_template_kwargs"] = {"enable_thinking": False}
            if tools:
                body["tools"] = tools
        headers = {"Authorization": f"Bearer {args.api_key}"} if args.api_key else {}
        async with session.post(url, json=body, headers=headers) as resp:
            if resp.status != 200:
                r["error"] = f"HTTP {resp.status}: {(await resp.text())[:300]}"
                return r
            buf = b""
            async for chunk in resp.content.iter_any():
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    if args.api == "ollama":
                        j = json.loads(line)
                        m = j.get("message") or {}
                        piece = (m.get("content") or "") + (m.get("thinking") or "")
                        if piece or m.get("tool_calls"):
                            now = time.perf_counter()
                            first = first or now
                            last = now
                            n_chunks += 1
                            text_len += len(piece)
                        if j.get("done"):
                            finish = j.get("done_reason")
                            usage = {"prompt_tokens": j.get("prompt_eval_count", 0),
                                     "completion_tokens": j.get("eval_count", 0),
                                     "server_prefill_s": j.get("prompt_eval_duration", 0) / 1e9,
                                     "server_decode_s": j.get("eval_duration", 0) / 1e9}
                        continue
                    if not line.startswith(b"data:"):
                        continue
                    data = line[5:].strip()
                    if data == b"[DONE]":
                        continue
                    j = json.loads(data)
                    if j.get("error"):  # an error chunk mid-stream: the request failed even though tokens arrived
                        r["error"] = f"stream error: {json.dumps(j['error'])[:250]}"
                        return r
                    if j.get("usage"):
                        usage = j["usage"]
                    if j.get("timings"):  # llama.cpp extension
                        usage["timings"] = j["timings"]
                    for ch in j.get("choices") or []:
                        d = ch.get("delta") or {}
                        piece = (d.get("content") or "") + (d.get("reasoning_content") or "") + (d.get("reasoning") or "")
                        if piece or d.get("tool_calls"):
                            now = time.perf_counter()
                            first = first or now
                            last = now
                            n_chunks += 1
                            text_len += len(piece)
                        if ch.get("finish_reason"):
                            finish = ch["finish_reason"]
    except Exception as e:  # noqa: BLE001  keep the run going, record the failure
        r["error"] = f"{type(e).__name__}: {e}"[:300]
        return r
    t_end = time.perf_counter()
    if first is None:
        r["error"] = "no tokens streamed"
        return r
    n_out = usage.get("completion_tokens") or n_chunks
    n_in = usage.get("prompt_tokens")
    details = usage.get("prompt_tokens_details") or {}
    cached = details.get("cached_tokens")
    if cached is None and "timings" in usage:
        cached = usage["timings"].get("cache_n")
    r.update(ok=True, ttft_s=first - t0, e2e_s=t_end - t0, n_in=n_in, n_out=n_out, n_chunks=n_chunks,
             cached=cached, finish=finish,
             tpot_s=((last - first) / (n_out - 1)) if n_out and n_out > 1 else None)
    for k in ("server_prefill_s", "server_decode_s"):
        if k in usage:
            r[k] = usage[k]
    return r


# ---------------------------------------------------------------- helpers

def pct(xs, p):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return None
    k = (len(xs) - 1) * p / 100
    lo, hi = int(k), min(int(k) + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def summarize(rows, wall_s):
    ok = [r for r in rows if r["ok"]]
    s = {"n": len(rows), "errors": len(rows) - len(ok), "wall_s": round(wall_s, 3)}
    if not ok:
        return s
    tt = [r["ttft_s"] for r in ok]
    tp = [r["tpot_s"] for r in ok if r.get("tpot_s")]
    s.update(
        in_tokens_mean=round(statistics.mean(r["n_in"] or 0 for r in ok), 1),
        out_tokens_mean=round(statistics.mean(r["n_out"] or 0 for r in ok), 1),
        ttft_p50_s=round(pct(tt, 50), 3), ttft_p90_s=round(pct(tt, 90), 3), ttft_max_s=round(max(tt), 3),
        agg_out_tok_s=round(sum(r["n_out"] or 0 for r in ok) / wall_s, 1),
        agg_in_tok_s=round(sum(r["n_in"] or 0 for r in ok) / wall_s, 1),
    )
    if tp:
        s.update(tpot_p50_ms=round(pct(tp, 50) * 1e3, 2), tpot_p90_ms=round(pct(tp, 90) * 1e3, 2),
                 user_decode_tok_s_p50=round(1 / pct(tp, 50), 1), user_decode_tok_s_p10=round(1 / pct(tp, 90), 1))
    pre = [r["n_in"] / r["ttft_s"] for r in ok if r.get("n_in")]
    if pre:
        s["prefill_tok_s_p50"] = round(pct(pre, 50), 1)
    cached = [r["cached"] for r in ok if r.get("cached") is not None]
    if cached:
        s["cached_share"] = round(sum(cached) / max(1, sum(r["n_in"] or 0 for r in ok if r.get("cached") is not None)), 3)
    return s


def redact(argv):
    """argv with the value after --api-key masked: summaries get shared, keys must not be."""
    out = list(argv)
    for i, a in enumerate(out[:-1]):
        if a == "--api-key":
            out[i + 1] = "***"
    return [("--api-key=***" if a.startswith("--api-key=") else a) for a in out]


class Recorder:
    def __init__(self, args, scenario):
        self.dir = pathlib.Path(args.out)
        self.dir.mkdir(parents=True, exist_ok=True)
        stamp = time.strftime("%Y%m%d-%H%M%S")
        self.stem = f"{args.engine}_{args.tag}_{scenario}_{stamp}"
        self.raw = open(self.dir / f"{self.stem}.jsonl", "w")
        self.cells = []
        self.meta = {"engine": args.engine, "tag": args.tag, "model": args.model, "scenario": scenario,
                     "base_url": args.base_url, "api": args.api, "think": args.think, "client_host": platform.node(),
                     "started": stamp, "argv": redact(sys.argv[1:])}

    def row(self, cell, r):
        self.raw.write(json.dumps({"cell": cell, **r}) + "\n")
        self.raw.flush()

    def cell(self, cell, summary):
        self.cells.append({"cell": cell, **summary})
        print(json.dumps({"cell": cell, **summary}), flush=True)

    def close(self):
        self.raw.close()
        (self.dir / f"{self.stem}.summary.json").write_text(json.dumps({"meta": self.meta, "cells": self.cells}, indent=1))
        print(f"wrote {self.dir / self.stem}.summary.json", file=sys.stderr)


def salt():
    return f"[request {uuid.uuid4().hex[:12]}]\n"


async def calibrate(session, args):
    """chars per prompt token for the corpus, plus the chat-template overhead, from the server's own usage."""
    rng = random.Random(7)
    small = await chat(session, args, [{"role": "user", "content": salt() + "hi"}], args.probe_max_tokens, ignore_eos=False)
    chars = toks = 0
    for _ in range(4):  # several slices: density varies from file to file
        big_text = code_slice(rng, 12_000)
        big = await chat(session, args, [{"role": "user", "content": salt() + big_text}], args.probe_max_tokens,
                         ignore_eos=False)
        if not (small["ok"] and big["ok"] and big["n_in"]):
            raise SystemExit(f"calibration failed: {small.get('error')} {big.get('error')}")
        chars += len(big_text)
        toks += big["n_in"] - small["n_in"]
    cpt = chars / toks
    print(f"calibration: {cpt:.3f} chars/token, template overhead {small['n_in']} tokens", file=sys.stderr)
    return cpt, small["n_in"]


def prompt_of(rng, tokens, cpt, overhead, instruction):
    body = code_slice(rng, max(1, int((tokens - overhead - 40) * cpt)))
    return salt() + body + "\n\n" + instruction


EXPLAIN = "Explain in detail, line by line, what the code above does. Be thorough."


# ---------------------------------------------------------------- scenarios

async def run_prefill(session, args, rec):
    cpt, ovh = await calibrate(session, args)
    rng = random.Random(args.seed)
    for L in args.lengths:
        rows = []
        for _ in range(args.reps):
            r = await chat(session, args, [{"role": "user", "content": prompt_of(rng, L, cpt, ovh, EXPLAIN)}],
                           args.probe_max_tokens, ignore_eos=False)
            rec.row(f"prefill_{L}", r)
            rows.append(r)
        rec.cell(f"prefill_{L}", summarize(rows, sum(r.get("e2e_s", 0) for r in rows)))


async def run_decode(session, args, rec):
    cpt, ovh = await calibrate(session, args)
    rng = random.Random(args.seed)
    for C in args.concurrency:
        n_total = max(args.min_requests, C * args.rounds)
        prompts = [prompt_of(rng, args.input_len, cpt, ovh, EXPLAIN) for _ in range(n_total)]
        q = asyncio.Queue()
        for p in prompts:
            q.put_nowait(p)
        rows = []

        async def worker():
            while not q.empty():
                p = q.get_nowait()
                r = await chat(session, args, [{"role": "user", "content": p}], args.output_len, ignore_eos=True)
                rec.row(f"decode_c{C}", r)
                rows.append(r)

        t0 = time.perf_counter()
        await asyncio.gather(*(worker() for _ in range(C)))
        rec.cell(f"decode_c{C}", {"concurrency": C, **summarize(rows, time.perf_counter() - t0)})


def load_agent_prefix(path):
    """A captured opening request (system prompt + tools) from a real harness, or None."""
    if not path:
        return None, None
    j = json.loads(pathlib.Path(path).read_text())
    msgs = [m for m in j["messages"] if m["role"] in ("system", "developer")]
    for m in msgs:
        m["role"] = "system"
    return msgs, j.get("tools")


async def agent_session(session, args, rec, uid, cpt, ovh, sys_msgs, tools, rows, sess_rows):
    rng = random.Random(args.seed * 1000 + uid)
    messages = list(sys_msgs) if sys_msgs else [
        {"role": "system", "content": "You are a coding agent working in a large Python repository.\n\n"
                                      + code_slice(rng, int(args.system_tokens * cpt))}]
    messages.append({"role": "user", "content": salt() + "Find and fix the bug that makes the config loader ignore "
                     "environment overrides. Read the relevant files first, then explain the fix."})
    t0 = time.perf_counter()
    for turn in range(args.turns):
        r = await chat(session, args, messages, args.output_len, ignore_eos=True, tools=tools)
        r.update(user=uid, turn=turn)
        rec.row(f"agent_u{args._users}", r)
        rows.append(r)
        if not r["ok"]:
            break
        # The engine sees exactly what a harness would send back: prior assistant turn + a new tool result.
        messages.append({"role": "assistant", "content": f"Reading more files (step {turn})."})
        await asyncio.sleep(rng.uniform(*args.tool_latency))
        messages.append({"role": "user", "content": "Tool result (read_file):\n```python\n"
                         + code_slice(rng, int(args.tool_tokens * cpt)) + "\n```"})
    sess_rows.append({"user": uid, "session_s": time.perf_counter() - t0, "turns": turn + 1})


async def run_agent(session, args, rec):
    cpt, ovh = await calibrate(session, args)
    sys_msgs, tools = load_agent_prefix(args.prefix_request)
    for U in args.users:
        args._users = U
        rows, sess_rows = [], []
        t0 = time.perf_counter()
        await asyncio.gather(*(agent_session(session, args, rec, u, cpt, ovh, sys_msgs, tools, rows, sess_rows)
                               for u in range(U)))
        wall = time.perf_counter() - t0
        s = summarize(rows, wall)
        later = [r for r in rows if r["ok"] and r["turn"] > 0]
        if later:
            s["turn_ttft_p50_s"] = round(pct([r["ttft_s"] for r in later], 50), 3)
            s["turn_ttft_p90_s"] = round(pct([r["ttft_s"] for r in later], 90), 3)
        s["final_ctx_tokens_max"] = max((r.get("n_in") or 0) for r in rows) if rows else None
        s["session_s_p50"] = round(pct([x["session_s"] for x in sess_rows], 50), 2) if sess_rows else None
        s["session_s_max"] = round(max(x["session_s"] for x in sess_rows), 2) if sess_rows else None
        rec.cell(f"agent_u{U}", {"users": U, **s})


TEAM_TASK = ("Find and fix the bug that makes the config loader ignore environment overrides. "
             "Read the relevant files first, then explain the fix.")


async def team_session(session, args, rec, cell, gid, aid, cpt, sys_msgs, tools, shared_ctx, rows, sess_rows):
    """One agent of user `gid`. Its first message starts with that user's shared repo context, then diverges."""
    rng = random.Random(args.seed * 100000 + gid * 100 + aid)
    await asyncio.sleep(rng.uniform(0, args.start_jitter))
    messages = list(sys_msgs) + [{"role": "user", "content": "Repository context:\n```python\n" + shared_ctx
                                  + "\n```\n\n" + salt() + TEAM_TASK}]
    t0 = time.perf_counter()
    turn = 0
    for turn in range(args.turns):
        r = await chat(session, args, messages, args.output_len, ignore_eos=True, tools=tools)
        r.update(group=gid, agent=aid, turn=turn)
        rec.row(cell, r)
        rows.append(r)
        if not r["ok"]:
            break
        messages.append({"role": "assistant", "content": f"Reading more files (step {turn})."})
        await asyncio.sleep(rng.uniform(*args.tool_latency))
        messages.append({"role": "user", "content": "Tool result (read_file):\n```python\n"
                         + code_slice(rng, int(args.tool_tokens * cpt)) + "\n```"})
    sess_rows.append({"group": gid, "agent": aid, "session_s": time.perf_counter() - t0, "turns": turn + 1})


def share(rows):
    c = [r for r in rows if r.get("ok") and r.get("cached") is not None and r.get("n_in")]
    return round(sum(r["cached"] for r in c) / sum(r["n_in"] for r in c), 3) if c else None


async def run_team(session, args, rec):
    cpt, ovh = await calibrate(session, args)
    sys_msgs, tools = load_agent_prefix(args.prefix_request)
    sys_msgs = sys_msgs or [{"role": "system", "content": "You are a coding agent."}]
    for spec in args.groups:
        sizes = [int(x) for x in spec.split(",")]
        cell = "team_" + "+".join(map(str, sizes))
        rows, sess_rows = [], []
        ctx = [code_slice(random.Random(args.seed * 7 + g + 1), int(args.shared_tokens * cpt)) for g in range(len(sizes))]
        t0 = time.perf_counter()
        await asyncio.gather(*(team_session(session, args, rec, cell, g, a, cpt, sys_msgs, tools, ctx[g], rows, sess_rows)
                               for g, n in enumerate(sizes) for a in range(n)))
        wall = time.perf_counter() - t0
        s = summarize(rows, wall)
        per_user = []
        for g, n in enumerate(sizes):
            gr = [r for r in rows if r.get("group") == g]
            ok = [r for r in gr if r["ok"]]
            first = [r for r in ok if r["turn"] == 0]
            per_user.append({
                "user": g, "agents": n, "requests": len(gr), "errors": len(gr) - len(ok),
                "turn_ttft_p50_s": round(pct([r["ttft_s"] for r in ok], 50), 3) if ok else None,
                "turn_ttft_p90_s": round(pct([r["ttft_s"] for r in ok], 90), 3) if ok else None,
                "first_turn_cached_share": share(first),
                "first_turn_ttft_p50_s": round(pct([r["ttft_s"] for r in first], 50), 3) if first else None,
                "session_s_p50": round(pct([x["session_s"] for x in sess_rows if x["group"] == g], 50), 1),
            })
        s.update(users=len(sizes), agents=sum(sizes), per_user=per_user,
                 turn_ttft_p50_s=round(pct([r["ttft_s"] for r in rows if r["ok"]], 50), 3),
                 turn_ttft_p90_s=round(pct([r["ttft_s"] for r in rows if r["ok"]], 90), 3),
                 first_turn_cached_share=share([r for r in rows if r.get("turn") == 0]))
        rec.cell(cell, s)


async def run_retention(session, args, rec):
    """How long does a session's processed context stay cached on the server between turns?"""
    cpt, ovh = await calibrate(session, args)
    sys_msgs, tools = load_agent_prefix(args.prefix_request)
    sys_msgs = sys_msgs or [{"role": "system", "content": "You are a coding agent."}]
    stop = asyncio.Event()
    bg_rows, bg_sess = [], []
    args._users = f"bg{args.background}"

    async def background(i):
        k = 0
        while not stop.is_set():
            await agent_session(session, args, rec, 10000 + i * 1000 + k, cpt, ovh, sys_msgs, tools, bg_rows, bg_sess)
            k += 1

    bg = [asyncio.create_task(background(i)) for i in range(args.background)]
    if args.background:
        await asyncio.sleep(args.warmup)
    probes = []

    async def probe(i, d):
        rng = random.Random(args.seed * 31 + i)
        await asyncio.sleep(i * 2.0)
        msgs = list(sys_msgs) + [{"role": "user", "content": salt() + "Repository context:\n```python\n"
                                  + code_slice(rng, int(args.probe_tokens * cpt)) + "\n```\nSummarise the module layout."}]
        r1 = await chat(session, args, msgs, args.probe_max_tokens, ignore_eos=False, tools=tools)
        await asyncio.sleep(d)
        msgs = msgs + [{"role": "assistant", "content": "Summary noted."},
                       {"role": "user", "content": "Now list the three most complex functions."}]
        r2 = await chat(session, args, msgs, 16, ignore_eos=True, tools=tools)
        r2.update(delay_s=d, build_ttft_s=r1.get("ttft_s"), build_n_in=r1.get("n_in"), build_ok=r1.get("ok"),
                  build_error=r1.get("error"))
        rec.row(f"retention_bg{args.background}", r2)
        probes.append(r2)

    await asyncio.gather(*(probe(i, d) for i, d in enumerate(args.delays)))
    stop.set()
    for t in bg:
        t.cancel()
    await asyncio.gather(*bg, return_exceptions=True)
    for r in sorted(probes, key=lambda r: r["delay_s"]):
        rec.cell(f"retention_bg{args.background}_d{r['delay_s']}", {
            "background_agents": args.background, "idle_s": r["delay_s"], "ok": r["ok"],
            "context_tokens": r.get("n_in"), "cached_tokens": r.get("cached"),
            "cached_share": round(r["cached"] / r["n_in"], 3) if r.get("ok") and r.get("cached") is not None else None,
            "ttft_s": round(r["ttft_s"], 3) if r.get("ok") else None,
            "cold_build_ttft_s": round(r["build_ttft_s"], 3) if r.get("build_ttft_s") else None,
            "error": r.get("error"), "build_ok": r.get("build_ok"), "build_error": r.get("build_error")})
    if bg_rows:
        rec.cell(f"retention_bg{args.background}_background", summarize(bg_rows, 1.0) | {"note": "background agents"})


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base-url", required=True, help="…/v1 for openai, server root for ollama")
    ap.add_argument("--api", choices=["openai", "ollama"], default="openai")
    ap.add_argument("--api-key", default=os.environ.get("BENCH_API_KEY", ""))
    ap.add_argument("--model", required=True)
    ap.add_argument("--engine", required=True)
    ap.add_argument("--tag", required=True, help="quant/config label, used in file names")
    ap.add_argument("--out", default="results/raw")
    ap.add_argument("--think", action="store_true", help="leave thinking on (default: off)")
    ap.add_argument("--temperature", type=float, default=0.7)
    ap.add_argument("--num-ctx", type=int, default=0, help="ollama only")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--timeout", type=float, default=1800)
    ap.add_argument("--probe-max-tokens", type=int, default=1,
                    help="output tokens for prefill/calibration probes; gpt-oss on SGLang needs more than 1 because its "
                         "first tokens are format markers the parser swallows (TTFT is unaffected)")
    ap.add_argument("--no-ignore-eos", action="store_true",
                    help="let the model stop on its own (gpt-oss: forcing length past its end-of-call marker breaks "
                         "vLLM's harmony parser); outputs then vary in length")
    sub = ap.add_subparsers(dest="scenario", required=True)
    p = sub.add_parser("prefill")
    p.add_argument("--lengths", type=int, nargs="+", default=[1024, 4096, 8192, 16384, 32768])
    p.add_argument("--reps", type=int, default=3)
    d = sub.add_parser("decode")
    d.add_argument("--concurrency", type=int, nargs="+", default=[1, 2, 4, 8, 16])
    d.add_argument("--input-len", type=int, default=1024)
    d.add_argument("--output-len", type=int, default=256)
    d.add_argument("--rounds", type=int, default=3)
    d.add_argument("--min-requests", type=int, default=6)
    a = sub.add_parser("agent")
    a.add_argument("--users", type=int, nargs="+", default=[1, 2, 4, 8])
    a.add_argument("--turns", type=int, default=8)
    a.add_argument("--system-tokens", type=int, default=4000)
    a.add_argument("--tool-tokens", type=int, default=1500)
    a.add_argument("--output-len", type=int, default=150)
    a.add_argument("--tool-latency", type=float, nargs=2, default=[0.3, 1.5])
    a.add_argument("--prefix-request", help="captured harness request JSON: reuse its system prompt")
    t = sub.add_parser("team")
    t.add_argument("--groups", nargs="+", default=["3,3,3,3", "8,1,1,1,1"],
                   help="agents per user, comma-separated; one run per spec")
    t.add_argument("--shared-tokens", type=int, default=6000, help="repo context shared by one user's agents")
    t.add_argument("--start-jitter", type=float, default=3.0, help="agents of a run start within this many seconds")
    t.add_argument("--turns", type=int, default=8)
    t.add_argument("--tool-tokens", type=int, default=1500)
    t.add_argument("--output-len", type=int, default=150)
    t.add_argument("--tool-latency", type=float, nargs=2, default=[0.3, 1.5])
    t.add_argument("--prefix-request")
    rt = sub.add_parser("retention")
    rt.add_argument("--delays", type=int, nargs="+", default=[5, 60, 300, 900], help="idle gaps to test, seconds")
    rt.add_argument("--background", type=int, default=0, help="agents running continuously meanwhile")
    rt.add_argument("--warmup", type=float, default=60, help="seconds of background load before the probes start")
    rt.add_argument("--probe-tokens", type=int, default=12000)
    rt.add_argument("--turns", type=int, default=8)
    rt.add_argument("--system-tokens", type=int, default=4000)
    rt.add_argument("--tool-tokens", type=int, default=1500)
    rt.add_argument("--output-len", type=int, default=150)
    rt.add_argument("--tool-latency", type=float, nargs=2, default=[0.3, 1.5])
    rt.add_argument("--prefix-request")
    args = ap.parse_args()

    global CORPUS
    CORPUS = load_corpus()

    async def go():
        rec = Recorder(args, args.scenario)
        # force_close: llama-server drops keep-alive sockets after a streamed reply; reusing one fails mid-write.
        conn = aiohttp.TCPConnector(limit=0, force_close=True)
        timeout = aiohttp.ClientTimeout(total=args.timeout)
        async with aiohttp.ClientSession(connector=conn, timeout=timeout) as session:
            try:
                await {"prefill": run_prefill, "decode": run_decode, "agent": run_agent, "team": run_team,
                        "retention": run_retention}[args.scenario](session, args, rec)
            finally:
                rec.close()

    asyncio.run(go())


if __name__ == "__main__":
    main()
