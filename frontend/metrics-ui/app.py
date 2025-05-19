from flask import Flask, request, render_template, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
import re

app = Flask(__name__)

# 🔢 Métricas
requests_total = Counter('metrics_ui_requests_total', 'Acciones completadas', ['outcome'])
page_views = Counter('metrics_ui_page_views_total', 'Vistas de página', ['page'])
tasks_total = Counter('metrics_ui_tasks_total', 'Tareas realizadas por tipo', ['task', 'outcome'])
errors_total = Counter('metrics_ui_errors_total', 'Errores de la aplicación', ['type'])
action_duration = Histogram(
    'metrics_ui_action_duration_seconds',
    'Duración de acciones',
    ['task'],
    buckets=[0.05, 0.1, 0.2, 0.5, 1.0, 2.0]
)
form_submissions = Counter('metrics_ui_form_submissions_total', 'Form submissions', ['status'])
validation_errors = Counter('metrics_ui_validation_errors_total', 'Errores de validación', ['field', 'error'])

# 🏠 Página principal
@app.route("/")
def index():
    page_views.labels(page="index").inc()
    return render_template("index.html")

# 📊 Endpoint de métricas Prometheus
@app.route("/metrics", methods=["GET", "POST"])
def metrics():
    if request.method == "POST":
        try:
            data = request.get_json()
            task = data.get("action", "unknown")
            status = data.get("status", "unknown")

            start_time = time.time()
            time.sleep(0.1)  # Simula proceso
            duration = time.time() - start_time

            requests_total.labels(outcome=status).inc()
            tasks_total.labels(task=task, outcome=status).inc()
            action_duration.labels(task=task).observe(duration)

            return jsonify({"message": "Métrica recibida"}), 200
        except Exception as e:
            errors_total.labels(type="server").inc()
            return jsonify({"error": str(e)}), 500
    else:
        return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

# 📝 Validación de formulario
@app.route("/formulario", methods=["POST"])
def formulario():
    nombre = request.form.get("nombre", "").strip()
    edad = request.form.get("edad", "").strip()
    email = request.form.get("email", "").strip()
    errores = []

    if not nombre:
        validation_errors.labels(field="nombre", error="empty").inc()
        errores.append("El nombre es obligatorio.")
    if not edad.isdigit():
        validation_errors.labels(field="edad", error="not_number").inc()
        errores.append("La edad debe ser un número.")
    if not re.match(r"[^@]+@[^@]+\.[^@]+", email):
        validation_errors.labels(field="email", error="invalid_format").inc()
        errores.append("El email no es válido.")

    if errores:
        form_submissions.labels(status="fail").inc()
        return jsonify({"error": " | ".join(errores)})
    else:
        form_submissions.labels(status="ok").inc()
        return jsonify({"mensaje": "¡Formulario enviado correctamente!"})

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=80)
