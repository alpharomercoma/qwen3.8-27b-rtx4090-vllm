#!/bin/bash
# POD. Download one of the models in models.sh at its pinned commit and check every file against
# models/<model>.sha256, so the served weights cannot change underneath us.
# usage: bash fetch_model.sh heretic|original
set -euo pipefail
. /workspace/env.sh
. /workspace/4090/pod/models.sh
model_preset "${1:?usage: fetch_model.sh heretic|original}"
# ~19 GB per model. Stop early with advice instead of filling the volume halfway through.
have=0   # GB already downloaded (a resumed download needs less)
if [ -d "$MODEL_DIR" ]; then have=$(du -s --block-size=1G "$MODEL_DIR" | cut -f1); fi
free=$(df --output=avail --block-size=1G /workspace | tail -1 | tr -dc 0-9)
if [ $((free + have)) -lt 21 ]; then
  echo "not enough space on /workspace: ${free} GB free, a model needs ~20 GB. Free some first, e.g. the model you are"
  echo "not using (rm -rf /workspace/models/<dir>) or uv's cache (uv cache clean). ls /workspace/models; df -h /workspace"
  exit 1
fi
rm -f "$MODEL_DIR/.download-complete"
hf download "$MODEL_REPO" --revision "$MODEL_REV" --local-dir "$MODEL_DIR" --max-workers 8
echo "checking SHA-256 of every file (about a minute)"
( cd "$MODEL_DIR" && grep -v '^#' "$MODEL_MANIFEST" | sha256sum -c --quiet - ) ||
  { echo "checksum mismatch: not marking the download complete"; exit 1; }
touch "$MODEL_DIR/.download-complete"   # start.sh skips the download only when this exists
( cd "$MODEL_DIR" && du -sh . && ls )
echo FETCH_DONE
