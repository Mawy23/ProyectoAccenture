#!/bin/bash
set -e

echo "🔧 Iniciando entorno..."

# Ruta base del proyecto
BASE_DIR="/mnt/c/Users/frang/Desktop/TFGPSS"
ANSIBLE_DIR="$BASE_DIR/ansible"
TODO_APP_DIR="$BASE_DIR/todo-app"
METRICS_UI_DIR="$BASE_DIR/frontend/metrics-ui"

# Verificar que Docker esté corriendo (en host Windows, asumido como iniciado)
echo "🐳 Verificando estado de Minikube..."
minikube status || minikube start --driver=docker

# Esperar hasta que el API server esté disponible
echo "⏳ Esperando a que el API Server esté disponible..."
for i in {1..20}; do
    if kubectl get nodes &>/dev/null; then
        echo "✅ API Server listo."
        break
    fi
    sleep 5
    if [ "$i" -eq 20 ]; then
        echo "❌ Timeout esperando al API Server. Abortando."
        exit 1
    fi
done

# Activar entorno virtual de Ansible (si existe)
if [ -f "$ANSIBLE_DIR/.venv/bin/activate" ]; then
    echo "🐍 Activando entorno virtual de Ansible..."
    source "$ANSIBLE_DIR/.venv/bin/activate"
fi

# Ejecutar playbook de Ansible
echo "🚀 Desplegando stack con Ansible..."
export ANSIBLE_ROLES_PATH="$ANSIBLE_DIR/roles"
cd "$ANSIBLE_DIR"
ansible-playbook -i localhost, "$ANSIBLE_DIR/playbooks/deploy.yml"

# Construir imagen metrics-ui en Minikube
echo "📦 Construyendo imagen metrics-ui..."
cd "$METRICS_UI_DIR"
minikube image build -t metrics-ui:latest .

# Desplegar Deployment, Service y ServiceMonitor
echo "📡 Desplegando metrics-ui..."
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f metrics-servicemonitor.yaml

# Reiniciar Pod para aplicar cambios en el Service
echo "♻️ Reiniciando Pod de metrics-ui..."
kubectl delete pod -l app=metrics-ui --ignore-not-found

# Esperar a que el Pod esté listo
echo "⏳ Esperando a que el Pod metrics-ui esté listo..."
for i in {1..20}; do
    STATUS=$(kubectl get pod -l app=metrics-ui -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
    if [ "$STATUS" == "true" ]; then
        echo "✅ Pod metrics-ui listo."
        break
    fi
    sleep 3
    if [ "$i" -eq 20 ]; then
        echo "❌ Timeout esperando al Pod metrics-ui. Abortando..."
        exit 1
    fi
done

# Port-forward servicios
echo "🔁 Haciendo port-forward de Prometheus, Grafana y metrics-ui..."
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring >/dev/null 2>&1 &
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring >/dev/null 2>&1 &
kubectl port-forward svc/metrics-ui 8080:80 >/dev/null 2>&1 &

# Esperar a que Grafana esté disponible
echo "⌛ Esperando a que Grafana esté disponible..."
for i in {1..15}; do
    if nc -z localhost 3000; then
        echo "🌐 Abriendo Grafana..."
        powershell.exe start http://localhost:3000
        break
    fi
    sleep 2
done

# Esperar a que Prometheus esté disponible
echo "⌛ Esperando a que Prometheus esté disponible..."
for i in {1..10}; do
    if nc -z localhost 9090; then
        echo "🌐 Abriendo Prometheus..."
        powershell.exe start http://localhost:9090
        break
    fi
    sleep 2
done

# Esperar a que metrics-ui esté disponible
echo "⌛ Esperando a que metrics-ui esté disponible..."
for i in {1..15}; do
    if nc -z localhost 8080; then
        echo "🌐 Abriendo metrics-ui en el navegador..."
        powershell.exe start http://localhost:8080
        break
    fi
    sleep 2
done

# Mensaje final
echo ""
echo "🎉 Stack iniciado correctamente."
echo "📊 Grafana:     http://localhost:3000 (user: admin / pass: prom-operator)"
echo "📈 Prometheus:  http://localhost:9090"
echo "🧪 metrics-ui:  http://localhost:8080"
