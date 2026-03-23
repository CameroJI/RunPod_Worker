# vllm-runpod-worker

Worker serverless para RunPod que levanta vLLM con configuración exacta, sin depender del worker oficial.

## Estructura

```
├── Dockerfile
├── src/
│   ├── start.sh       # Lanza vLLM + handler
│   └── handler.py     # Proxy RunPod → vLLM
├── test_input.json    # Input de prueba local
└── .github/
    └── workflows/
        └── docker-publish.yml  # Build automático a GHCR
```

## Configuración vLLM

El comando que se ejecuta en cada worker:

```bash
python -m vllm.entrypoints.openai.api_server \
  --model "$MODEL_PATH" \
  --dtype auto \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.92 \
  --limit-mm-per-prompt image=5 \
  --served-model-name qwen3 \
  --port 8000 \
  --enable-auto-tool-choice \
  --tool-call-parser hermes
```

## Despliegue en RunPod

### 1. Hacer el repo público (o configurar GHCR como público)

En GitHub → Settings del paquete GHCR → Change visibility → Public.

### 2. Crear el Network Volume

RunPod Console → Storage → Network Volumes → Create.
Sube el modelo ahí una sola vez:
```
/runpod-volume/models/cyankiwi/Qwen3-VL-30B-A3B-Instruct-AWQ-4bit/
```

### 3. Crear el Serverless Endpoint

RunPod Console → Serverless → New Endpoint → Custom Source → Docker Image:

| Campo | Valor |
|-------|-------|
| Container Image | `ghcr.io/TU_USUARIO/vllm-runpod-worker:latest` |
| Container Disk | `10 GB` |
| Network Volume | selecciona el que creaste, mount en `/runpod-volume` |
| Min Workers | `0` |
| Max Workers | `1` (o más si necesitas concurrencia) |

### 4. Variable de entorno en el endpoint

```
MODEL_PATH=/runpod-volume/models/cyankiwi/Qwen3-VL-30B-A3B-Instruct-AWQ-4bit
```

### 5. Tu endpoint queda en

```
https://api.runpod.ai/v2/<ENDPOINT_ID>/runsync
```

## Uso desde tu app

Compatible con el cliente OpenAI estándar:

```python
from openai import OpenAI

client = OpenAI(
    api_key="tu_runpod_api_key",
    base_url="https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1",
)

# Chat normal
response = client.chat.completions.create(
    model="qwen3",
    messages=[{"role": "user", "content": "Hola"}],
)

# Con tools
response = client.chat.completions.create(
    model="qwen3",
    messages=[{"role": "user", "content": "¿Qué clima hace en CDMX?"}],
    tools=[{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Obtiene el clima de una ciudad",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}},
                "required": ["city"]
            }
        }
    }],
    tool_choice="auto",
)

# Con imagen (multimodal)
response = client.chat.completions.create(
    model="qwen3",
    messages=[{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": "https://..."}},
            {"type": "text", "text": "¿Qué hay en esta imagen?"}
        ]
    }],
)
```

## Actualizar la imagen

Cada push a `main` dispara el build automáticamente en GitHub Actions.
Para que RunPod use la nueva imagen, haz redeploy del endpoint o activa
el webhook de auto-deploy en la configuración del endpoint.
