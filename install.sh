#!/bin/bash

echo "======================================================"
echo "🚀 Starting automated setup for To-Do List project..."
echo "======================================================"

# 1. Enable the Ingress addon
echo "-> Enabling Minikube Ingress addon..."
minikube addons enable ingress

# 2. Pull the Docker image
echo "-> Pulling the adapter Docker image..."
docker pull ghcr.io/holyshoes2283/todolist-adapter:v1

# 3. Grab the Minikube IP dynamically
echo "-> Fetching current Minikube IP..."
CLUSTER_IP=$(minikube ip)
echo "   Detected IP: $CLUSTER_IP"

# 4. Install the Helm chart using the dynamic IP
echo "-> Installing Helm chart..."
helm install todo1 oci://ghcr.io/holyshoes2283/todolist/todolist \
  --version 0.3.0 \
  --set clusterIP=$CLUSTER_IP \
  --set secret.rootPassword=Test123456

echo "======================================================"
echo "🎉 Installation complete!"
echo "⚠️ IMPORTANT: Please run 'minikube tunnel' in a separate terminal."
echo "🟢 Then access the app at: http://app.${CLUSTER_IP}.nip.io"
echo "======================================================"
