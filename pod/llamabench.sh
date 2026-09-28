#!/bin/bash
# POD. Raw llama.cpp numbers for one GGUF: single-stream prefill/decode (llama-bench) and decode throughput with
# 1..16 parallel sequences (llama-batched-bench). usage: llamabench.sh <file under /workspace/models/qwen38-gguf>
. /workspace/env.sh
M=/workspace/models/qwen38-gguf/$1; T=$(basename "$1" .gguf); O=/workspace/results/llamabench; mkdir -p $O
nvidia-smi --query-gpu=name,driver_version,clocks.max.sm,power.limit --format=csv > $O/${T}_gpu.csv
llama-bench -m $M -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -p 512,4096,16384 -n 128 -ub 512 -r 3 -o jsonl > $O/${T}_bench.jsonl 2> $O/${T}_bench.log
llama-bench -m $M -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -p 4096 -n 0 -ub 1024,2048 -r 3 -o jsonl >> $O/${T}_bench.jsonl 2>> $O/${T}_bench.log
llama-bench -m $M -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -p 0 -n 128 -d 16384,32768 -ub 512 -r 3 -o jsonl >> $O/${T}_bench.jsonl 2>> $O/${T}_bench.log
llama-batched-bench -m $M -ngl 99 -fa on -ctk q8_0 -ctv q8_0 -c 32768 -b 2048 -ub 512 -npp 1024 -ntg 128 -npl 1,2,4,8,16 \
  --output-format jsonl > $O/${T}_batched.jsonl 2> $O/${T}_batched.log
echo BENCH_EXIT=$? >> $O/${T}_bench.log
