"""How long a big prompt takes to reach the server: the same ~45 KB payload sent twice; the second hits vLLM's prefix
cache, so its time to first token is mostly transfer. usage: python3 upload_probe.py URL KEY [gap_s]"""
import asyncio, random, string, sys, time
import aiohttp

URL, KEY = sys.argv[1].rstrip("/") + "/chat/completions", sys.argv[2]
GAP = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0
rng = random.Random()
text = " ".join("".join(rng.choices(string.ascii_lowercase, k=rng.randint(3, 7))) for _ in range(7000))


async def once(s):
    body = {"model": "qwen3.8-27b-heretic", "stream": True, "max_tokens": 1,
            "messages": [{"role": "user", "content": text}], "chat_template_kwargs": {"enable_thinking": False}}
    t0 = time.perf_counter()
    async with s.post(URL, json=body, headers={"Authorization": f"Bearer {KEY}"}) as r:
        async for line in r.content:
            if b'"content"' in line:
                return time.perf_counter() - t0


async def main():
    async with aiohttp.ClientSession() as s:
        cold = await once(s)
        warm = []
        for _ in range(4):
            await asyncio.sleep(GAP)
            warm.append(round(await once(s), 3))
        print(f"payload {len(text)//1024} KB: first (prefill) {cold:.2f} s; repeats (cached) {warm}")

asyncio.run(main())
