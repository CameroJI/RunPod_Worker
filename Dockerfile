FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# Instala vLLM y runpod SDK — versiones fijas para reproducibilidad
RUN pip install --no-cache-dir \
    vllm==0.6.5 \
    runpod==1.7.3

COPY src/handler.py /handler.py
COPY src/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
