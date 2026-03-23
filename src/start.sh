#!/bin/bash
set -e

# Ruta del modelo — por defecto apunta al network volume
# Sobreescribe con la variable de entorno MODEL_PATH en RunPod
MODEL="${MODEL_PATH:-/runpod-volume/models/cyankiwi/Qwen3-VL-30B-A3B-Instruct-AWQ-4bit}"

echo "[start.sh] Iniciando vLLM con modelo: $MODEL"

python -m vllm.entrypoints.openai.api_server \
  --model "$MODEL" \
  --dtype auto \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.92 \
  --limit-mm-per-prompt image=5 \
  --served-model-name qwen3 \
  --port 8000 \
  --enable-auto-tool-choice \
  --tool-call-parser hermes &

VLLM_PID=$!

# Espera hasta que vLLM responda — timeout de 10 minutos
echo "[start.sh] Esperando a que vLLM esté listo..."
TIMEOUT=600
ELAPSED=0
until curl -sf http://127.0.0.1:8000/health > /dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "[start.sh] ERROR: vLLM no arrancó en ${TIMEOUT}s"
    kill $VLLM_PID 2>/dev/null
    exit 1
  fi
  sleep 3
  ELAPSED=$((ELAPSED + 3))
done

echo "[start.sh] vLLM listo. Iniciando handler de RunPod..."
python /handler.py

# Si handler termina, apaga vLLM también
kill $VLLM_PID 2>/dev/null
