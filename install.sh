#!/bin/bash

minikube status >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "   Minikube is offline. Starting it up now..."
    minikube start
else
    echo "   Minikube is already running!"
fi

echo "-> Enabling Minikube Ingress addon..."
minikube addons enable ingress

echo "-> Determining the correct routing IP..."
RAW_IP=$(minikube ip)
OS_TYPE=$(uname -s)
PROFILE=$(minikube profile)
minikube profile list | grep -w "minikube" | tr -d '│|' | awk '{print $2}'

MINIKUBE_DRIVER=$(minikube profile list --output json | python3 -c "import sys, json; print(json.load(sys.stdin)['valid'][0]['Config']['Driver'])")
PROFILE=$(minikube profile)

echo "   Detected OS: $OS_TYPE"
echo "   Detected Driver: $MINIKUBE_DRIVER"


if [[ "$MINIKUBE_DRIVER" == "docker" ]] || [[ "$MINIKUBE_DRIVER" == "podman" ]]; then
    if [[ "$OS_TYPE" == "Darwin"* ]] || [[ "$OS_TYPE" == "MINGW"* ]] || [[ "$OS_TYPE" == "CYGWIN"* ]]; then
        echo "   [!] Container driver isolated on Mac/Windows."
        echo "   [!] The tunnel will bind to localhost."
        export CURRENT_IP="127.0.0.1"
    else
        echo "   [!] Container driver on Linux detected."
        echo "   [!] Using raw Minikube IP."
        export CURRENT_IP=$RAW_IP
    fi

else
    echo "   [!] Native VM driver detected."
    echo "   [!] Using raw Minikube IP."
    export CURRENT_IP=$RAW_IP
fi

echo "   Final Routing IP: $CURRENT_IP"

echo "-> Generating dynamic routing rules..."
cat <<EOF > temp-ip-routing.yaml
frontend:
  env:
    API_BASE_URL: "http://api.${CURRENT_IP}.nip.io"
ingress:
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

echo "-> Fixing Service types to prevent Mac tunnel collisions..."
kubectl patch svc todo1-frontend -p '{"spec": {"type": "ClusterIP"}}'
kubectl patch svc todo1-adapter -p '{"spec": {"type": "ClusterIP"}}'

echo "-> Force-injecting CORS security bypass directly into Ingress..."
kubectl annotate ingress todo1-ingress \
  nginx.ingress.kubernetes.io/enable-cors="true" \
  nginx.ingress.kubernetes.io/cors-allow-origin="http://app.${CURRENT_IP}.nip.io" \
  nginx.ingress.kubernetes.io/cors-allow-credentials="true" \
  nginx.ingress.kubernetes.io/cors-allow-methods="GET, PUT, POST, DELETE, PATCH, OPTIONS" \
  nginx.ingress.kubernetes.io/cors-allow-headers="DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization" \
  --overwrite

echo "-> Cleaning up temporary files..."
rm temp-ip-routing.yaml

echo "======================================================"
echo " Installation complete!"

echo "======================================================"
echo "-> Opening Minikube Tunnel in a new window... please enter password if needed\nAnd keep open!"
osascript -e 'tell app "Terminal"
    do script "echo \"--- MINIKUBE TUNNEL --- (Do not close)\"; minikube tunnel"
end tell'
echo -e "\n\n\nFRONTEND vue is accessible at: http://app.${CURRENT_IP}.nip.io \nBACKEND Api accessible at: http://api.${CURRENT_IP}.nip.io \nSAVED IN accessible-ip-addresses.txt"> accessible-ip-addresses.txt
