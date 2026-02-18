#!/bin/bash

echo "======================================================"
echo "🚀 Starting automated setup for To-Do List project..."
echo "======================================================"

echo "-> Checking Minikube status..."
minikube status >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "   Minikube is offline. Starting it up now..."
    minikube start
else
    echo "   Minikube is already running!"
fi

echo "-> Enabling Minikube Ingress addon..."
minikube addons enable ingress

echo "-> Pulling the adapter Docker image..."
docker pull ghcr.io/holyshoes2283/todolist-adapter:v1

# ---------------------------------------------------------
# THE UNIVERSAL IP DETECTOR
# ---------------------------------------------------------
echo "-> Determining the correct routing IP..."
RAW_IP=$(minikube ip)
OS_TYPE=$(uname -s)

if [[ "$OS_TYPE" == "Darwin"* ]] || [[ "$OS_TYPE" == "MINGW"* ]] || [[ "$OS_TYPE" == "CYGWIN"* ]]; then
    echo "   [!] Mac/Windows environment detected."
    echo "   [!] The tunnel will bind to localhost."
    export CURRENT_IP="127.0.0.1"
else
    echo "   [!] Linux environment detected."
    echo "   [!] Using raw Minikube IP."
    export CURRENT_IP=$RAW_IP
fi

echo "   Final Routing IP: $CURRENT_IP"
# ---------------------------------------------------------

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

echo "-> Installing Helm chart..."
helm install todo1 oci://ghcr.io/holyshoes2283/todolist/todolist \
  --version 0.3.1 \
  -f temp-ip-routing.yaml \
  --set secret.rootPassword=Test123456

echo "-> Cleaning up temporary files..."
rm temp-ip-routing.yaml

echo "======================================================"
echo "🎉 Installation complete!"
echo "⚠️ IMPORTANT: Please run 'minikube tunnel' in a separate terminal."
echo "🟢 Then access the app at: http://app.${CURRENT_IP}.nip.io"
echo "======================================================"