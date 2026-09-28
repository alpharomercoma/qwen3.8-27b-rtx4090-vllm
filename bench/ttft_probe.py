"""Time to first token for small and large prompts, one request at a time with an idle gap between them (as in an
agent loop: the model answers, a tool runs, the next turn goes out). Each prompt is fresh random text, so no prefix
cache hit hides prefill. Run it on the pod against the gateway and on a laptop against the public URL; the
difference is what the network path costs.
usage: python3 ttft_probe.py --base-url URL --api-key KEY [--reps 5] [--gap 3]"""
import argparse, asyncio, json, random, statistics, string, time

import aiohttp


def words(n_tokens, rng):
    # ~1 token per short random word
    return " ".join("".join(rng.choices(string.ascii_lowercase, k=rng.randint(3, 7))) for _ in range(n_tokens))


async def ttft(session, url, key, model, prompt):
    body = {"model": model, "stream": True, "max_tokens": 1, "messages": [{"role": "user", "content": prompt}],
            "chat_template_kwargs": {"enable_thinking": False}}
    t0 = time.perf_counter()
    async with session.post(url, json=body, headers={"Authorization": f"Bearer {key}"}) as r:
        r.raise_for_status()
        async for line in r.content:
            if line.startswith(b"data:") and b'"content"' in line:
                return time.perf_counter() - t0
    return time.perf_counter() - t0


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", required=True)
    ap.add_argument("--api-key", required=True)
    ap.add_argument("--model", default="qwen3.8-27b-heretic")
    ap.add_argument("--reps", type=int, default=5)
    ap.add_argument("--gap", type=float, default=3.0)
    ap.add_argument("--sizes", type=int, nargs="+", default=[100, 7000])
    a = ap.parse_args()
    rng = random.Random()
    url = a.base_url.rstrip("/") + "/chat/completions"
    out = {}
    async with aiohttp.ClientSession() as s:  # keep-alive, like a real client
        await ttft(s, url, a.api_key, a.model, "hi")  # open the connection
        for n in a.sizes:
            times = []
            for _ in range(a.reps):
                await asyncio.sleep(a.gap)
                times.append(await ttft(s, url, a.api_key, a.model, words(n, rng)))
            out[n] = times
    for n, t in out.items():
        print(json.dumps({"prompt_tokens_approx": n, "ttft_median_s": round(statistics.median(t), 3),
                          "ttft_all_s": [round(x, 3) for x in t]}))


asyncio.run(main())
