# shellcheck shell=bash disable=SC2034  # sets variables for the scripts that source it
# POD. The models this service can serve, one at a time on the 24 GB card. Sourced by fetch_model.sh, serve.sh and
# start.sh. Both use the same vLLM settings (serve.sh) and the same measured KV-cache budget.
#   heretic   the official Heretic (ARA) abliteration of Qwen3.8-27B (heretic-org/Qwen3.8-27B-heretic-ara), quantized
#             to W4A16 with AutoRound by JC1DA. Answers requests the original refuses. The default.
#   original  Qwen3.8-27B as Qwen released it, quantized to W4A16 by Red Hat (compressed-tensors). The checkpoint the
#             engine benchmarks in docs/benchmarks used.
# Each is pinned to one Hugging Face commit, and fetch_model.sh checks every file against models/<name>.sha256.
MODELS="heretic original"
MODEL_CHOICE_FILE=/workspace/.model   # the model start.sh serves after a restart

model_preset() {
  case "${1:-}" in
    heretic)
      MODEL_REPO=JC1DA/Qwen3.8-27B-heretic-ara-W4A16
      MODEL_REV=0a191462511776109c129dda0772d33ae9b85be9
      MODEL_DIR=/workspace/models/qwen38-heretic-ara-w4a16
      MODEL_ID=qwen3.8-27b-heretic ;;
    original)
      MODEL_REPO=RedHatAI/Qwen3.8-27B-INT4
      MODEL_REV=91bd022d5b49442a868bc35008f6c21e1860edfa
      MODEL_DIR=/workspace/models/qwen38-redhat-int4
      MODEL_ID=qwen3.8-27b ;;
    *) echo "unknown model '${1:-}': use one of: $MODELS" >&2; return 1 ;;
  esac
  MODEL_NAME=$1
  MODEL_MANIFEST=/workspace/4090/pod/models/$1.sha256
}
