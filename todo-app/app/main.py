# app/main.py
from fastapi import FastAPI, Request, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

# Métricas
REQUEST_COUNT = Counter(
    "todo_request_count", 
    "Número de peticiones recibidas", 
    ["method", "endpoint"]
)
REQUEST_LATENCY = Histogram(
    "todo_request_latency_seconds", 
    "Latencia de las peticiones", 
    ["endpoint"]
)

app = FastAPI()

# Middleware para medir cada petición
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    elapsed = time.time() - start_time

    # Actualiza métricas
    REQUEST_COUNT.labels(request.method, request.url.path).inc()
    REQUEST_LATENCY.labels(request.url.path).observe(elapsed)
    return response

@app.get("/health")
def health():
    return {"status": "OK"}

@app.get("/metrics")
def metrics():
    data = generate_latest()
    return Response(data, media_type=CONTENT_TYPE_LATEST)
