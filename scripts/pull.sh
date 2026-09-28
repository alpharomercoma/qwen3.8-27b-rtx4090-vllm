#!/bin/bash
# MAC. Copy /workspace/results (raw load-generator rows, summaries, VRAM snapshots, llama-bench files) into results/.
. "$(dirname "$0")/lib.sh"
mkdir -p "$HERE/results"
ssh "${POD_SSH_OPTS[@]}" "$POD_SSH_HOST" 'tar -C /workspace/results -czf - .' | tar -C "$HERE/results" -xzf -
python3 "$HERE/bench/summarize.py" "$HERE/results"
