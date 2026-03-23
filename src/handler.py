import runpod
import requests

VLLM_BASE = "http://127.0.0.1:8000/v1"


def handler(job):
    job_input = job["input"]

    # Detecta el endpoint destino (default: chat/completions)
    endpoint = job_input.pop("endpoint", "chat/completions")
    url = f"{VLLM_BASE}/{endpoint}"

    try:
        response = requests.post(url, json=job_input, timeout=300)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.Timeout:
        return {"error": "vLLM timeout (300s)"}
    except requests.exceptions.HTTPError as e:
        return {"error": f"HTTP {e.response.status_code}", "detail": e.response.text}
    except Exception as e:
        return {"error": str(e)}


runpod.serverless.start({"handler": handler})
