#!/bin/bash
# MAC. Hook a RunPod GPU pod up as the backend of alphaexperiments.com/heretic-inference, from nothing to a public
# answer, in one command (docs/DEPLOY.md → "One command"). Safe to rerun: every step skips what is already done.
# usage: scripts/new_pod.sh <pod-id>-<suffix>@ssh.runpod.io [heretic|original]
#   1. keep the previous pod's .pod_env / .pod_known_hosts (as .prev-<pod-id>)
#   2. pod_connect.sh: the pod's address and pinned host keys; adds ~/.ssh/id_ed25519.pub to the pod if needed
#   3. team API keys: the local .team_api_keys (gitignored) goes to the pod, so every user's key keeps working
#   4. push the code and run pod/start.sh on the pod in the background (install, model download, vLLM, gateway,
#      tunnel; 20-30 min the first time, a few minutes on a volume that has it all), following its log
#   5. trust the pod's tunnel key on the edge (scripts/edge.sh install; replaces the previous pod's key)
#   6. check the public API: 401 without a key, the model list and a short answer with the team key
#   7. copy the pod's team keys back to .team_api_keys; with E2E_PASSWORD set, run the web app's Playwright tests
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"
PROXY=${1:?usage: scripts/new_pod.sh <pod-id>-<suffix>@ssh.runpod.io [heretic|original]}
MODEL=${2:-heretic}
case $MODEL in heretic) ID=qwen3.8-27b-heretic ;; original) ID=qwen3.8-27b ;; *) echo "model: heretic or original"; exit 2 ;; esac
URL=https://alphaexperiments.com/heretic-inference/v1
step() { printf '\n== %s %s\n' "$(date +%H:%M:%S)" "$*"; }
pod() { POD_TIMEOUT=${POD_TIMEOUT:-120} scripts/pod.sh; }

step "1/7 previous pod's connection files"
if [ -f .pod_env ]; then
  old=$(sed -n 's/^POD_SSH_PROXY=\([a-z0-9]*\)-.*/\1/p' .pod_env)
  if [ -n "$old" ] && [ "$old" != "${PROXY%%-*}" ]; then
    cp .pod_env ".pod_env.prev-$old"; cp .pod_known_hosts ".pod_known_hosts.prev-$old"; echo "kept as .pod_env.prev-$old"
  else echo "none to keep"; fi
fi

step "2/7 connect"
scripts/pod_connect.sh "$PROXY"
pod <<<'nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader; df -h /workspace | tail -1'

step "3/7 team API keys"
if [ -s .team_api_keys ]; then
  # "<label> <key>" lines; the pod's gateway re-reads the file when it changes
  grep -qvE '^[A-Za-z0-9._-]+ [A-Za-z0-9_-]{20,}$' .team_api_keys && { echo ".team_api_keys: expected '<label> <key>' lines"; exit 1; }
  pod <<<"umask 077; cat > /workspace/.team_api_keys <<'KEYS'
$(cat .team_api_keys)
KEYS
echo \"\$(wc -l < /workspace/.team_api_keys) key(s) on the pod\""
else
  echo "no local .team_api_keys: the pod keeps its own (start.sh creates a 'team' key if it has none); saved here at step 7"
fi

step "4/7 push code, run pod/start.sh $MODEL (log: /workspace/logs/start.log)"
scripts/push.sh >/dev/null
pod <<<"mkdir -p /workspace/logs; rm -f /workspace/logs/start.exit
nohup bash -c 'bash /workspace/4090/pod/start.sh $MODEL > /workspace/logs/start_console.log 2>&1; echo \$? > /workspace/logs/start.exit' >/dev/null 2>&1 < /dev/null &
echo started"
seen=""
for _ in $(seq 240); do   # up to 2 h: a first install on a slow volume can take long
  sleep 30
  out=$(pod <<<'cat /workspace/logs/start.exit 2>/dev/null; echo "@@"; tail -n 3 /workspace/logs/start_console.log' 2>/dev/null) || continue
  rc=${out%%@@*}; rc=$(printf '%s' "$rc" | tr -dc 0-9)
  last=$(printf '%s' "${out#*@@}" | tr -d '\r' | grep -v '^\s*$' | tail -1 | cut -c1-150)
  [ "$last" != "$seen" ] && { echo "   $last"; seen=$last; }
  [ -n "$rc" ] && break
done
[ -n "${rc:-}" ] || { echo "start.sh has not finished after 2 h: scripts/pod.sh <<<'tail -30 /workspace/logs/start.log'"; exit 1; }
case $rc in
  0) echo "start.sh: up (the edge already trusts this pod's tunnel key)" ;;
  3) echo "start.sh: vLLM and the gateway run; the edge does not trust this pod's tunnel key yet" ;;
  *) echo "start.sh failed (exit $rc):"; pod <<<'tail -25 /workspace/logs/start.log'; exit 1 ;;
esac

step "5/7 edge: trust this pod's tunnel key"
if [ "$rc" = 3 ]; then
  POD_PUBKEY=$(pod <<<'bash /workspace/4090/pod/gateway/edge_tunnel.sh pubkey' | tr -d '\r' | tail -1) scripts/edge.sh install | tail -2
else
  echo "not needed"
fi

step "6/7 public API"
code=000
for _ in $(seq 36); do   # the tunnel retries at most once a minute while it was refused
  code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$URL/models") && [ "$code" = 401 ] && break
  sleep 5
done
[ "$code" = 401 ] || { echo "$URL/models answers $code, not 401: scripts/pod.sh <<<'tail /workspace/logs/edge_tunnel.log'"; exit 1; }
echo "without a key: 401 (the gateway answers through the tunnel)"
KEY=$(pod <<<'awk "NR==1{print \$2}" /workspace/.team_api_keys' | tr -d '\r' | tail -1)
models=$(curl -s -m 30 "$URL/models" -H "Authorization: Bearer $KEY" | python3 -c 'import json,sys; print(" ".join(m["id"] for m in json.load(sys.stdin)["data"]))')
[ "$models" = "$ID" ] || { echo "the API serves '$models', expected $ID"; exit 1; }
answer=$(curl -s -m 120 "$URL/chat/completions" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d "{\"model\":\"$ID\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: pong\"}],\"max_tokens\":16,\"chat_template_kwargs\":{\"enable_thinking\":false}}" |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"].strip())')
unset KEY
echo "with a team key: serves $models, answered '$answer'"

step "7/7 team keys back to .team_api_keys; web app"
(umask 077; pod <<<'cat /workspace/.team_api_keys' | tr -d '\r' | grep -E '^[A-Za-z0-9._-]+ [A-Za-z0-9_-]{20,}$' > .team_api_keys.new)
[ -s .team_api_keys.new ] && mv .team_api_keys.new .team_api_keys && chmod 600 .team_api_keys
echo "$(wc -l < .team_api_keys | tr -d ' ') key(s) in .team_api_keys (mode 600, gitignored): labels $(cut -d' ' -f1 .team_api_keys | xargs)"
if [ -n "${E2E_PASSWORD:-}" ]; then
  (cd apps/web && npx playwright test --reporter=line 2>&1 | tail -3)
else
  echo "web app not tested: E2E_PASSWORD=<the web password> scripts/new_pod.sh ... also runs its Playwright tests"
fi
step "done: https://alphaexperiments.com/heretic-inference serves $ID from $(sed -n 's/^POD_SSH_HOST=root@//p' .pod_env)"
