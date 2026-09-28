#!/bin/bash
# MAC. Print each new result cell of a running pod suite as it lands; exit when the suite ends or the server dies.
# usage: scripts/watch_suite.sh <config>
cd "$(dirname "$0")/.." || exit 1; CFG=$1; seen=0
while true; do
  out=$(POD_TIMEOUT=30 scripts/pod.sh <<<"grep -E '^\{\"cell|SUITE_DONE|EXTRA_DONE|server exited|not ready|Traceback|calibration failed' /workspace/logs/suite_$CFG.log | cut -c1-460" 2>/dev/null)
  n=$(printf "%s\n" "$out" | grep -c .)
  if [ "$n" -gt "$seen" ]; then printf "%s\n" "$out" | tail -n $((n - seen)); seen=$n; fi
  printf "%s" "$out" | grep -qE "SUITE_DONE|EXTRA_DONE|server exited|not ready" && break
  sleep 30
done
