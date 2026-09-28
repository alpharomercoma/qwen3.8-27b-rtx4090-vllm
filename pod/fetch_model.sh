#!/bin/bash
# POD. Download the served checkpoint: the official Heretic (ARA) abliteration of Qwen3.8-27B
# (heretic-org/Qwen3.8-27B-heretic-ara, byte-identical to trohrbaugh/Qwen3.8-27B-heretic-ara), quantized to W4A16 with
# AutoRound (1000 iterations, group 128; MTP head, vision tower, norms and conv1d kept in 16 bit). 18.2 GiB.
# The default is pinned to one commit and every file is checked against qwen38-heretic-ara-w4a16.sha256, so the
# served weights cannot change underneath us. usage: bash fetch_model.sh [repo] [dir]   (another repo: REV=<commit>)
set -euo pipefail
. /workspace/env.sh
DEFAULT_REPO=JC1DA/Qwen3.8-27B-heretic-ara-W4A16
REPO=${1:-$DEFAULT_REPO}
DIR=${2:-/workspace/models/qwen38-heretic-ara-w4a16}
if [ "$REPO" = "$DEFAULT_REPO" ]; then REV=${REV:-0a191462511776109c129dda0772d33ae9b85be9}; else REV=${REV:?pin a commit: REV=<sha>}; fi
rm -f "$DIR/.download-complete"
hf download "$REPO" --revision "$REV" --local-dir "$DIR" --max-workers 8
if [ "$REPO" = "$DEFAULT_REPO" ]; then
  echo "checking SHA-256 of every file (about a minute)"
  ( cd "$DIR" && grep -v '^#' "$(dirname "$0")/qwen38-heretic-ara-w4a16.sha256" | sha256sum -c --quiet - ) ||
    { echo "checksum mismatch: not marking the download complete"; exit 1; }
fi
touch "$DIR/.download-complete"   # start.sh skips the download only when this exists
( cd "$DIR" && du -sh . && ls )
echo FETCH_DONE
