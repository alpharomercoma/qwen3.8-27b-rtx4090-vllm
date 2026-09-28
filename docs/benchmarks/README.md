# Benchmarks: one RTX 4090 as a team inference box

Proof of concept: can a single rented RTX 4090 (24 GB) serve Qwen3.8-27B to a small team using the
[pi](https://github.com/earendil-works/pi) coding agent from their Macs, and which engine and quant should it run?
The same scripts size and benchmark any other model we want to try.

All paths below are relative to the repository root. The production service that grew out of this study is
described in the [root README](../../README.md).

Status (2026-09-23): measured end to end. Ollama, llama.cpp, SGLang and vLLM were benchmarked on the same 4090,
and 26 of 26 real pi agent runs passed against the recommended server. **Recommendation: vLLM 0.30 +
`RedHatAI/Qwen3.8-27B-INT4` + int4 KV with the KV memory pinned (`pod/serve.sh vllm-int4-kv4-pin`); Ollama serialises
this model and cannot serve a team; SGLang (0.5.19 and 0.5.20) caps at 4 running requests on 24 GB.** Re-measured
on a second host (driver 580) on 2026-09-24. Details, caveats and the empty cells are in [FINDINGS.md](FINDINGS.md) (summary: [REPORT.md](REPORT.md)). Every number there comes from
`results/raw/*.summary.json` (`python3 bench/compare.py` regenerates the comparison tables,
`python3 bench/summarize.py` the full dump in `results/SUMMARY.md`).

## Layout

| Path | Runs on | What |
|---|---|---|
| `bench/fit.py` | anywhere | Right-sizing from a HF `config.json`: KV bytes/token, per-sequence linear-attention state, sequences x context that fit |
| `bench/loadgen.py` | pod (or Mac) | One load generator for every engine: prefill sweep, decode concurrency sweep, multi-turn agent sessions with pi's real system prompt + tools |
| `bench/pi_team.py` | Mac | N real `pi -p` agents at once on small repos with failing tests; scores pass/fail and wall time |
| `bench/summarize.py` | anywhere | `results/raw/*.summary.json` -> `results/SUMMARY.md` |
| `bench/compare.py` | anywhere | engine-comparison tables spliced into `docs/benchmarks/FINDINGS.md` |
| `pod/serve.sh` | pod | Named serving configs for llama.cpp, vLLM, SGLang, Ollama (one at a time on the GPU) |
| `pod/run_suite.sh` | pod | serve + wait + the loadgen suite, results to `/workspace/results/raw` |
| `pod/llamabench.sh` | pod | llama-bench / llama-batched-bench quant ladder |
| `pod/bootstrap.sh` | pod | make a fresh container on the volume ready (apt, CUDA 12.8 nvcc, uv, hf) |
| `pod/install_sglang.sh`, `pod/fix_sglang_cu129.sh` | pod | SGLang 0.5.19 on a CUDA 12.8 driver (see FINDINGS) |
| `pod/install_sglang_cu13.sh` | pod | SGLang 0.5.20 on a driver >= 580 host |
| `scripts/pod.sh` | Mac | run a heredoc on the pod over direct SSH |
| `scripts/push.sh` | Mac | copy `pod/` + `bench/` to `/workspace/4090` |
| `scripts/tunnel.sh` | Mac | forward pod ports: 18080 llama.cpp, 18000 vLLM/SGLang, 21434 Ollama |
| `scripts/watch_suite.sh` | Mac | stream result cells of a running suite |
| `scripts/pull.sh` | Mac | copy `/workspace/results` into `results/` and regenerate `SUMMARY.md` |

`.pod_env` and `.pod_known_hosts` (gitignored, written by `scripts/pod_connect.sh`) hold the pod address and its pinned host keys. The pod's bearer key is `/workspace/.api_key`.

## Pod prerequisites

A fresh container on this volume: `bash /workspace/4090/pod/bootstrap.sh` (apt tools + CUDA 12.8 nvcc for the
FlashInfer JIT, uv, hf CLI). Host 1 had driver 570 (CUDA 12.8); host 2 has driver 580 (CUDA 13.0), where SGLang
installs with `pod/install_sglang_cu13.sh`. Details for the CUDA 12.8 host:

- vLLM: `vllm-0.30.0+cu129` wheel with `--torch-backend=cu129` in `/workspace/venvs/vllm`; FlashInfer JIT needs
  `apt-get install cuda-nvcc-12-8 cuda-cudart-dev-12-8 cuda-cccl-12-8 cuda-nvrtc-dev-12-8 libcublas-dev-12-8 libcurand-dev-12-8`.
- SGLang 0.5.19 (last CUDA 12 release): `pod/install_sglang.sh` then `pod/fix_sglang_cu129.sh`, on the container disk.
- llama.cpp b11118 built with `-DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89`; Ollama 0.34.3 via its install script
  (needs `zstd`).
- `/workspace/env.sh` puts HF, uv, Ollama and JIT caches on the volume (the 20 GB root disk fills up otherwise).
- A host with driver >= 580 would take the default CUDA 13 wheels and skip most of the above.

## Reproduce

```bash
# Mac
scripts/push.sh
scripts/pod.sh <<'EOF'
bash /workspace/4090/pod/run_suite.sh lcpp-q4kxl            # or vllm-int4, sglang-int4, ollama-p4 ...
EOF
scripts/tunnel.sh -f
BENCH_API_KEY=... python3 bench/pi_team.py --base-url http://127.0.0.1:18080/v1 --engine llamacpp --tag q4kxl --agents 1 4 8
```

## Trying another model

1. `python3 bench/fit.py --hf <org/model> --weights-gib <checkpoint GiB> --kv-bytes 1` tells you whether it fits and
   how many sequences of what length.
2. Add a config line to `pod/serve.sh`, then `run_suite.sh <config>`.
