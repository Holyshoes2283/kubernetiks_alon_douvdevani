#!/bin/bash

# Minimal setup script
minikube status >/dev/null 2>&1 || minikube start
minikube addons enable ingress >/dev/null 2>&1

RAW_IP=$(minikube ip)
OS_TYPE=$(uname -s)
MINIKUBE_DRIVER=$(minikube profile list --output json | python3 -c "import sys, json; print(json.load(sys.stdin)['valid'][0]['Config']['Driver'])")

if [[ "$MINIKUBE_DRIVER" == "docker" ]] || [[ "$MINIKUBE_DRIVER" == "podman" ]]; then
    if [[ "$OS_TYPE" == "Darwin"* ]] || [[ "$OS_TYPE" == "MINGW"* ]]; then
        export CURRENT_IP="127.0.0.1"
    else
        export CURRENT_IP=$RAW_IP
    fi
else
    export CURRENT_IP=$RAW_IP
fi

echo "IP: $CURRENT_IP"

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

helm install todo1 oci://ghcr.io/holyshoes2283/todolist/todolist \
  --version 0.3.1 \
  -f temp-ip-routing.yaml \
  --set secret.rootPassword=Test123456 >/dev/null 2>&1

kubectl patch svc todo1-frontend -p '{"spec": {"type": "ClusterIP"}}' >/dev/null
kubectl patch svc todo1-adapter -p '{"spec": {"type": "ClusterIP"}}' >/dev/null

kubectl annotate ingress todo1-ingress \
  nginx.ingress.kubernetes.io/enable-cors="true" \
  nginx.ingress.kubernetes.io/cors-allow-origin="http://app.${CURRENT_IP}.nip.io" \
  nginx.ingress.kubernetes.io/cors-allow-credentials="true" \
  nginx.ingress.kubernetes.io/cors-allow-methods="GET PUT POST DELETE PATCH OPTIONS" \
  nginx.ingress.kubernetes.io/cors-allow-headers="DNT User-Agent X-Requested-With If-Modified-Since Cache-Control Content-Type Range Authorization" \
  --overwrite >/dev/null

rm temp-ip-routing.yaml

echo "Done"
echo "Run: minikube tunnel"
echo "URL: http://app.${CURRENT_IP}.nip.io"