#!/bin/bash
# POD. The whole Heretic-vs-original comparison (docs/EVAL.md), about 2.5 h: serve Heretic and run the suite, serve the
# original and run it, judge both models' JailbreakBench answers with the original, serve Heretic again and judge
# both with it, then score and report. vLLM only: no gateway or tunnel needed. Rerunning skips what is done.
# Needs: bootstrap.sh and install_vllm.sh done, the eval venv, and `evalsuite.py prepare` (docs/EVAL.md → Reproduce).
# usage: nohup bash /workspace/4090/bench/evals/compare_pod.sh [--judge-only] > /workspace/logs/eval_compare.log 2>&1 &
#   --judge-only: keep the answers, redo both judges' verdicts, score and report (~15 min)
set -uo pipefail
H=qwen3.8-27b-heretic O=qwen3.8-27b
PY=/workspace/venvs/eval/bin/python E=/workspace/4090/bench/evals/evalsuite.py
export VLLM_KEY=$(cat /workspace/.api_key)
cd /workspace
# The run's start, for run_metadata.json: kept on disk so a resumed run keeps it (delete the file for a new run)
mkdir -p /workspace/eval
[ -s /workspace/eval/.run_since ] || date -u +%FT%TZ > /workspace/eval/.run_since
SINCE=${EVAL_SINCE:-$(cat /workspace/eval/.run_since)}
step() { echo "== $(date -u +%FT%TZ) $*"; "$@" || { echo "!! failed: $*"; exit 1; }; }
serve() {  # $1 preset in pod/models.sh, $2 served id: download if needed, restart vLLM with serve.sh's settings
          # (even if something already serves $2, so the settings are always these), wait until it serves
  ( . /workspace/env.sh; . /workspace/4090/pod/models.sh; model_preset "$1"
    [ -f "$MODEL_DIR/.download-complete" ] || bash /workspace/4090/pod/fetch_model.sh "$1" ) || { echo "!! download"; exit 1; }
  step bash /workspace/4090/pod/serve.sh "$1"
  for _ in $(seq 180); do   # first boot compiles: ~4 min
    curl -sf http://127.0.0.1:8000/v1/models -H "Authorization: Bearer $VLLM_KEY" | grep -qF "\"id\":\"$2\"" &&
      { echo "== serving $2"; return; }
    sleep 5
  done
  echo "!! $2 is not serving after 15 min (tail /workspace/logs/serve_$1.log)"; exit 1
}
RUN=step; [ "${1:-}" = --judge-only ] && RUN=:
[ "$RUN" = : ] || serve heretic $H
$RUN $PY $E run --model $H
serve original $O
$RUN $PY $E run --model $O
for J in $O $H; do   # each judge model judges both models' answers, with the headline prompt and prompts A and B
  if [ $J = $H ]; then serve heretic $H; fi   # the original is already being served
  for P in jbb A B; do for M in $H $O; do step $PY $E judge --model $M --judge-model $J --prompt $P; done; done
done
step $PY $E score --models $O $H --judges $O $H
step $PY $E report
step $PY $E metadata --since "$SINCE"
echo COMPARE_DONE
