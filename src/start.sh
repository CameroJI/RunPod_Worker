#!/bin/bash
set -e

if [ -z "$MODEL_PATH" ]; then
  echo "[start.sh] ERROR: MODEL_PATH no está definida"
  exit 1
fi

SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3}"
DTYPE="${DTYPE:-auto}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-32768}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.92}"
MAX_IMAGES="${MAX_IMAGES:-5}"
TOOL_CALL_PARSER="${TOOL_CALL_PARSER:-hermes}"
PORT="${PORT:-8000}"

python -m vllm.entrypoints.openai.api_server \
  --model "$MODEL_PATH" \
  --dtype "$DTYPE" \
  --max-model-len "$MAX_MODEL_LEN" \
  --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
  --limit-mm-per-prompt image="$MAX_IMAGES" \
  --served-model-name "$SERVED_MODEL_NAME" \
  --port "$PORT" \
  --enable-auto-tool-choice \
  --tool-call-parser "$TOOL_CALL_PARSER" &

VLLM_PID=$!

TIMEOUT=600
ELAPSED=0
until curl -sf http://127.0.0.1:${PORT}/health > /dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "[start.sh] ERROR: vLLM no arrancó en ${TIMEOUT}s"
    kill $VLLM_PID 2>/dev/null
    exit 1
  fi
  sleep 3
  ELAPSED=$((ELAPSED + 3))
done

echo "[start.sh] vLLM listo"
python /handler.py
kill $VLLM_PID 2>/dev/null