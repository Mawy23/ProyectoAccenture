let successCount = 0;
let failCount = 0;

function sendMetric(status, task = "unknown") {
  fetch("/metrics", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      action: task,
      status: status,
      timestamp: new Date().toISOString()
    })
  })
    .then(() => {
      if (status === "success") {
        successCount++;
        document.getElementById("successCount").textContent = successCount;
      } else {
        failCount++;
        document.getElementById("failCount").textContent = failCount;
      }
    })
    .catch(err => console.error("❌ Error al enviar métrica", err));
}

document.getElementById("formulario").addEventListener("submit", async (e) => {
  e.preventDefault();
  const formData = new FormData(e.target);
  const res = await fetch("/formulario", {
    method: "POST",
    body: formData
  });
  const data = await res.json();
  const mensaje = document.getElementById("mensaje");
  mensaje.textContent = data.mensaje || data.error;
  mensaje.style.color = data.mensaje ? "green" : "red";
});
