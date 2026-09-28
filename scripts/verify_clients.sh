#!/bin/bash
# MAC. End-to-end check of the API-key route with the real CLI harnesses, through the public URL:
# pi and opencode each get an isolated config (the same snippets the web app's "Use from the terminal" dialog shows)
# and a small bug-fix task; pass = the task's tests pass and the test file is untouched.
# usage: HERETIC_API_KEY=... scripts/verify_clients.sh [pi|opencode|all]
set -uo pipefail
: "${HERETIC_API_KEY:?export HERETIC_API_KEY (team key)}"
BASE=${HERETIC_BASE_URL:-https://alphaexperiments.com/heretic-inference/v1}
MODEL=qwen3.8-27b-heretic
WORK=$(mktemp -d /tmp/heretic-clients.XXXXXX)
PROMPT="calc.py has a bug. Fix calc.py so that 'python3 -m unittest -q' passes. Do not edit test_calc.py. Run the tests to confirm."

make_repo() {  # $1 = dir
  mkdir -p "$1" && cd "$1" || exit 1
  cat > calc.py <<'PY'
def mean(xs):
    """Arithmetic mean of a non-empty list."""
    return sum(xs) / len(xs) - 1


def clamp(x, lo, hi):
    """Limit x to the closed interval [lo, hi]."""
    return max(lo, min(x, lo))
PY
  cat > test_calc.py <<'PY'
import unittest
from calc import clamp, mean


class T(unittest.TestCase):
    def test_mean(self):
        self.assertEqual(mean([1, 2, 3, 4]), 2.5)

    def test_clamp(self):
        self.assertEqual(clamp(5, 0, 10), 5)
        self.assertEqual(clamp(-1, 0, 10), 0)
        self.assertEqual(clamp(11, 0, 10), 10)


if __name__ == "__main__":
    unittest.main()
PY
  git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init
}

check() {  # $1 = name, $2 = seconds
  local ok=FAIL
  if python3 -m unittest -q >/dev/null 2>&1 && git diff --quiet HEAD -- test_calc.py; then ok=PASS; fi
  echo "$1: $ok in $2 s (calc.py changed: $(git diff --stat HEAD -- calc.py | tail -1 | xargs))"
  [ $ok = PASS ]
}

run_pi() {
  local home=$WORK/pihome; mkdir -p "$home"
  cat > "$home/models.json" <<JSON
{"providers": {"heretic": {"baseUrl": "$BASE", "api": "openai-completions", "apiKey": "\$HERETIC_API_KEY",
  "compat": {"supportsDeveloperRole": false, "supportsReasoningEffort": false, "thinkingFormat": "qwen-chat-template",
             "maxTokensField": "max_tokens"},
  "models": [{"id": "$MODEL", "name": "Qwen3.8-27B Heretic", "reasoning": true, "input": ["text"],
              "contextWindow": 65536, "maxTokens": 16384, "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0}}]}}}
JSON
  make_repo "$WORK/pi-repo"
  local t0=$SECONDS
  PI_CODING_AGENT_DIR=$home PI_OFFLINE=1 pi -p --no-session --mode json --model "heretic/$MODEL" --thinking medium \
    --no-context-files "$PROMPT" < /dev/null > "$WORK/pi_events.jsonl" 2> "$WORK/pi_stderr.txt"
  echo "pi tool calls: $(grep -c '"tool_execution_start"' "$WORK/pi_events.jsonl")"
  check pi $((SECONDS - t0))
}

run_opencode() {
  local cfg=$WORK/opencode.json
  cat > "$cfg" <<JSON
{"\$schema": "https://opencode.ai/config.json",
 "provider": {"heretic": {"npm": "@ai-sdk/openai-compatible", "name": "Heretic (team RTX 4090)",
   "options": {"baseURL": "$BASE", "apiKey": "{env:HERETIC_API_KEY}"},
   "models": {"$MODEL": {"name": "Qwen3.8-27B Heretic", "limit": {"context": 65536, "output": 16384}}}}}}
JSON
  make_repo "$WORK/oc-repo"
  local t0=$SECONDS
  OPENCODE_CONFIG=$cfg opencode run --pure --auto --format json -m "heretic/$MODEL" "$PROMPT" < /dev/null \
    > "$WORK/opencode_events.jsonl" 2> "$WORK/opencode_stderr.txt"
  echo "opencode tool uses: $(grep -c '"tool_use"\|"type":"tool"' "$WORK/opencode_events.jsonl")"
  check opencode $((SECONDS - t0))
}

rc=0
case "${1:-all}" in
  pi) run_pi || rc=1 ;;
  opencode) run_opencode || rc=1 ;;
  all) run_pi || rc=1; run_opencode || rc=1 ;;
  *) echo "usage: scripts/verify_clients.sh [pi|opencode|all]" >&2; exit 2 ;;
esac
echo "logs: $WORK"
exit $rc
