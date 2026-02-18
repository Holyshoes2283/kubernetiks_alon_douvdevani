#!/bin/bash

echo "======================================================"
echo "🚀 Starting automated setup for To-Do List project..."
echo "======================================================"

# 1. NEW: Check if Minikube is actually running
echo "-> Checking Minikube status..."
minikube status >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "   Minikube is offline. Starting it up now..."
    minikube start
else
    echo "   Minikube is already running!"
fi

# 2. Enable the Ingress addon
echo "-> Enabling Minikube Ingress addon..."
minikube addons enable ingress

# 3. Pull the Docker image
echo "-> Pulling the adapter Docker image..."
docker pull ghcr.io/holyshoes2283/todolist-adapter:v1

# 4. Grab the Minikube IP dynamically
echo "-> Fetching current Minikube IP..."
export CURRENT_IP=$(minikube ip)
echo "   Detected IP: $CURRENT_IP"

# 5. Generating dynamic routing rules
echo "-> Generating dynamic routing rules..."
cat <<EOF > temp-ip-routing.yaml
frontend:
  env:
    API_BASE_URL: "http://api.${CURRENT_IP}.nip.io"
ingress:
  annotations:
    nginx.ingress.kubernetes.io/cors-allow-origin: "http://app.${CURRENT_IP}.nip.io"
  rules:
    - host: api.${CURRENT_IP}.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: todo1-adapter
                port:
                  number: 80
    - host: app.${CURRENT_IP}.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: todo1-frontend
                port:
                  number: 80
EOF

# 6. Install the Helm chart
echo "-> Installing Helm chart..."
helm install todo1 oci://ghcr.io/holyshoes2283/todolist/todolist \
  --version 0.3.1 \
  -f temp-ip-routing.yaml \
  --set secret.rootPassword=Test123456

# 7. Clean up the temporary file
echo "-> Cleaning up temporary files..."
rm temp-ip-routing.yaml
minikube tunnel
echo "======================================================"
echo "🎉 Installation complete!"
echo "⚠️ IMPORTANT: Please run 'minikube tunnel' in a separate terminal."
echo "🟢 Then access the app at: http://app.${CURRENT_IP}.nip.io"
echo "======================================================"