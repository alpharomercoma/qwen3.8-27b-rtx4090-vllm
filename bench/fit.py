#!/usr/bin/env python3
"""Right-size a model for one GPU from its Hugging Face config.json.

Reads the architecture numbers (full-attention vs linear/sliding layers, KV heads, Gated DeltaNet state shapes, MLA
ranks), takes the weight size from the actual checkpoint on disk or the HF API, and prints how many tokens of KV cache
and how many concurrent sequences fit after the engine's fixed overheads.

usage:
  python3 bench/fit.py --config config.json --weights-gib 16.2 [--vram-gib 23.99] [--kv-bytes 2] [--overhead-gib 2.5]
  python3 bench/fit.py --hf Qwen/Qwen3.8-27B --weights-gib 16.2
"""
import argparse, json, subprocess, sys


def load(args):
    if args.config:
        return json.load(open(args.config))
    raw = subprocess.run(["curl", "-sL", f"https://huggingface.co/{args.hf}/raw/main/config.json"],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(raw)


def text_cfg(c):
    return c.get("text_config") or c.get("llm_config") or c


def shape(c):
    t = text_cfg(c)
    L = t["num_hidden_layers"]
    types = t.get("layer_types")
    if not types and t.get("full_attention_interval"):
        k = t["full_attention_interval"]
        types = ["full_attention" if (i + 1) % k == 0 else "linear_attention" for i in range(L)]
    types = types or ["full_attention"] * L
    heads = t["num_attention_heads"]
    head_dim = t.get("head_dim") or t["hidden_size"] // heads
    kv_heads = t.get("num_key_value_heads", heads)
    n_full = sum(x == "full_attention" for x in types)
    n_slide = sum(x in ("sliding_attention", "sliding_window") for x in types)
    n_lin = sum(x in ("linear_attention", "mamba", "gated_deltanet") for x in types)
    n_conv = sum(x == "conv" for x in types)  # LFM2-style short convolution: state = channels x kernel window
    s = dict(layers=L, full=n_full, sliding=n_slide, linear=n_lin, conv=n_conv, kv_heads=kv_heads, head_dim=head_dim,
             window=t.get("sliding_window"))
    if n_conv:
        s["conv_state_elems"] = n_conv * t["hidden_size"] * t.get("conv_L_cache", 3)
    if t.get("kv_lora_rank"):  # MLA: one latent + rope key per token per layer
        s["mla_per_layer"] = t["kv_lora_rank"] + t.get("qk_rope_head_dim", 64)
    if n_lin and t.get("linear_num_value_heads"):
        vh, kh = t["linear_num_value_heads"], t["linear_num_key_heads"]
        dk, dv = t["linear_key_head_dim"], t["linear_value_head_dim"]
        conv_dim = 2 * kh * dk + vh * dv
        s["gdn_state_elems"] = n_lin * vh * dk * dv
        s["gdn_conv_elems"] = n_lin * conv_dim * (t.get("linear_conv_kernel_dim", 4) - 1)
    return s


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config")
    ap.add_argument("--hf")
    ap.add_argument("--weights-gib", type=float, default=0, help="checkpoint size actually loaded on the GPU")
    ap.add_argument("--shape-only", action="store_true", help="print only per-token KV and per-sequence state")
    ap.add_argument("--vram-gib", type=float, default=23.99, help="RTX 4090: 24,564 MiB")
    ap.add_argument("--overhead-gib", type=float, default=2.5,
                    help="CUDA context + activations + CUDA graphs + fragmentation (measure; 1.5-3.5 typical)")
    ap.add_argument("--kv-bytes", type=float, default=2, help="2 = bf16/f16, 1 = fp8/q8_0, 0.5625 = q4_0")
    ap.add_argument("--state-bytes", type=float, default=4, help="Gated DeltaNet recurrent state dtype (fp32 = 4)")
    ap.add_argument("--contexts", type=int, nargs="+", default=[8192, 16384, 32768, 65536, 131072])
    args = ap.parse_args()
    if not (args.config or args.hf):
        sys.exit("need --config or --hf")
    s = shape(load(args))
    kv_tok = s["full"] * 2 * s["kv_heads"] * s["head_dim"] * args.kv_bytes
    if "mla_per_layer" in s:
        kv_tok = s["layers"] * s["mla_per_layer"] * args.kv_bytes
    state_seq = (s.get("gdn_state_elems", 0) * args.state_bytes + s.get("gdn_conv_elems", 0) * 2
                 + s.get("conv_state_elems", 0) * 2)
    slide_seq = (s["sliding"] * 2 * s["kv_heads"] * s["head_dim"] * args.kv_bytes * (s["window"] or 0))
    if args.shape_only:
        print(json.dumps({**s, "kv_kib_per_token": round(kv_tok / 1024, 2),
                          "state_mib_per_seq": round(state_seq / 2**20, 2),
                          "slide_mib_per_seq": round(slide_seq / 2**20, 2)}))
        return
    free = (args.vram_gib - args.weights_gib - args.overhead_gib) * 2**30
    print(json.dumps(s))
    print(f"KV per token (full-attn layers): {kv_tok / 1024:.1f} KiB   fixed per sequence: "
          f"linear state {state_seq / 2**20:.1f} MiB, sliding {slide_seq / 2**20:.1f} MiB")
    print(f"VRAM {args.vram_gib} GiB - weights {args.weights_gib} - overhead {args.overhead_gib} = "
          f"{free / 2**30:.2f} GiB for cache")
    if free <= 0:
        print("DOES NOT FIT")
        return
    print(f"total KV tokens if one sequence: {int((free - state_seq - slide_seq) / kv_tok):,}")
    print("\n| context per seq | max concurrent seqs at full context |")
    print("|---|---|")
    for ctx in args.contexts:
        per_seq = ctx * kv_tok + state_seq + slide_seq
        print(f"| {ctx:,} | {int(free // per_seq)} |")


if __name__ == "__main__":
    main()
