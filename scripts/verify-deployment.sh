#!/bin/bash
# ============================================================
# Script: Verify Kubernetes Deployment Status
# ============================================================
# 
# Tujuan: Verify status deployment TaskFlow di Kubernetes
#         Digunakan untuk testing dan debugging
#
# Usage:
#   ./scripts/verify-deployment.sh
#   ./scripts/verify-deployment.sh prod
#   ./scripts/verify-deployment.sh dev
#
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${1:-taskflow-prod}"
DEPLOYMENT_NAME="taskflow-api"
SERVICE_NAME="taskflow-api"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Kubernetes Deployment Verification${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ============================================================
# Step 1: Verify kubectl installed
# ============================================================
echo -e "${YELLOW}[Step 1]${NC} Checking kubectl..."

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    echo "Install kubectl from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || echo "unknown")
echo -e "${GREEN}✓ kubectl found: $KUBECTL_VERSION${NC}"
echo ""

# ============================================================
# Step 2: Verify cluster connection
# ============================================================
echo -e "${YELLOW}[Step 2]${NC} Testing cluster connection..."

if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo ""
    echo "Possible solutions:"
    echo "  1. Start Minikube:"
    echo "     minikube start"
    echo ""
    echo "  2. Check kubeconfig:"
    echo "     echo \$KUBECONFIG"
    echo ""
    echo "  3. Set kubeconfig:"
    echo "     export KUBECONFIG=~/.kube/config"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"
echo ""

# ============================================================
# Step 3: Verify namespace exists
# ============================================================
echo -e "${YELLOW}[Step 3]${NC} Checking namespace: $NAMESPACE..."

if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}✗ Namespace not found: $NAMESPACE${NC}"
    echo ""
    echo "Available namespaces:"
    kubectl get namespaces
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Namespace found: $NAMESPACE${NC}"
echo ""

# ============================================================
# Step 4: Check deployment status
# ============================================================
echo -e "${YELLOW}[Step 4]${NC} Checking deployment: $DEPLOYMENT_NAME..."
echo ""

if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}✗ Deployment not found: $DEPLOYMENT_NAME${NC}"
    echo ""
    echo "Deployments in namespace '$NAMESPACE':"
    kubectl get deployments -n "$NAMESPACE"
    echo ""
    exit 1
fi

echo -e "${CYAN}Deployment Status:${NC}"
kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE"
echo ""

# ============================================================
# Step 5: Check pod status
# ============================================================
echo -e "${YELLOW}[Step 5]${NC} Checking pods..."
echo ""

POD_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT_NAME" --no-headers | wc -l)

if [ "$POD_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ No pods found for deployment: $DEPLOYMENT_NAME${NC}"
    echo ""
    echo "All pods in namespace '$NAMESPACE':"
    kubectl get pods -n "$NAMESPACE"
    echo ""
    exit 1
fi

echo -e "${CYAN}Pod Status:${NC}"
kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT_NAME" -o wide
echo ""

# Check pod readiness
READY_PODS=$(kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT_NAME" -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c "True" || true)
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT_NAME" --no-headers | wc -l)

echo -e "${CYAN}Pod Readiness: $READY_PODS/$TOTAL_PODS${NC}"
if [ "$READY_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ All pods are ready${NC}"
else
    echo -e "${YELLOW}⚠ Some pods are not ready (waiting for deployment...)${NC}"
fi
echo ""

# ============================================================
# Step 6: Check service status
# ============================================================
echo -e "${YELLOW}[Step 6]${NC} Checking service: $SERVICE_NAME..."
echo ""

if ! kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}✗ Service not found: $SERVICE_NAME${NC}"
    echo ""
    echo "Services in namespace '$NAMESPACE':"
    kubectl get services -n "$NAMESPACE"
    echo ""
    exit 1
fi

echo -e "${CYAN}Service Status:${NC}"
kubectl get service "$SERVICE_NAME" -n "$NAMESPACE"
echo ""

# Get service details
SERVICE_TYPE=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.type}')
NODE_PORT=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
CLUSTER_IP=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
TARGET_PORT=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].targetPort}')

echo -e "${CYAN}Service Details:${NC}"
echo "  Type: $SERVICE_TYPE"
echo "  Cluster IP: $CLUSTER_IP"
echo "  Target Port: $TARGET_PORT"
if [ "$NODE_PORT" != "N/A" ]; then
    echo "  Node Port: $NODE_PORT"
fi
echo ""

# ============================================================
# Step 7: Check endpoints
# ============================================================
echo -e "${YELLOW}[Step 7]${NC} Checking service endpoints..."
echo ""

ENDPOINTS=$(kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null || echo "")

if [ -z "$ENDPOINTS" ]; then
    echo -e "${YELLOW}⚠ No endpoints found (pods may not be ready yet)${NC}"
else
    echo -e "${GREEN}✓ Service endpoints:${NC}"
    kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE"
fi
echo ""

# ============================================================
# Step 8: Deployment info
# ============================================================
echo -e "${YELLOW}[Step 8]${NC} Deployment details..."
echo ""

echo -e "${CYAN}Deployment Info:${NC}"
kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" | head -30
echo ""

# ============================================================
# Step 9: Recent events
# ============================================================
echo -e "${YELLOW}[Step 9]${NC} Recent events..."
echo ""

echo -e "${CYAN}Events (last 10):${NC}"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
echo ""

# ============================================================
# Step 10: Test connectivity (if ready)
# ============================================================
if [ "$READY_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${YELLOW}[Step 10]${NC} Testing service connectivity..."
    echo ""
    
    if [ "$SERVICE_TYPE" = "NodePort" ]; then
        # Get minikube IP for NodePort service
        if command -v minikube &> /dev/null; then
            MINIKUBE_IP=$(minikube ip)
            SERVICE_URL="http://${MINIKUBE_IP}:${NODE_PORT}"
            
            echo -e "${CYAN}Service URL: $SERVICE_URL${NC}"
            
            # Try to connect
            if command -v curl &> /dev/null; then
                echo "Testing connection..."
                if curl -s --connect-timeout 5 "$SERVICE_URL" > /dev/null; then
                    echo -e "${GREEN}✓ Service is accessible${NC}"
                    echo ""
                    echo "Response preview:"
                    curl -s "$SERVICE_URL" | head -c 200
                    echo ""
                    echo ""
                else
                    echo -e "${YELLOW}⚠ Cannot reach service (may need port-forward)${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Minikube not found (cannot test NodePort service)${NC}"
        fi
    else
        echo "Port-forwarding to service..."
        echo "Run this to access the service:"
        echo "  kubectl port-forward service/$SERVICE_NAME 8080:80 -n $NAMESPACE"
        echo ""
        echo "Then access: http://localhost:8080"
    fi
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✓ VERIFICATION COMPLETE${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Overall status
if [ "$READY_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ Deployment is healthy and ready${NC}"
    echo "  - Namespace: $NAMESPACE"
    echo "  - Deployment: $DEPLOYMENT_NAME"
    echo "  - Ready Pods: $READY_PODS/$TOTAL_PODS"
    echo "  - Service: $SERVICE_NAME ($SERVICE_TYPE)"
else
    echo -e "${YELLOW}⚠ Deployment is not fully ready yet${NC}"
    echo "  - Namespace: $NAMESPACE"
    echo "  - Deployment: $DEPLOYMENT_NAME"
    echo "  - Ready Pods: $READY_PODS/$TOTAL_PODS"
    echo "  - Check pod logs for more info:"
    echo "    kubectl logs deployment/$DEPLOYMENT_NAME -n $NAMESPACE"
fi

echo ""
