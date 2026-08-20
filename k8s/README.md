# Kubernetes Fundamentals Lab

Hands-on labs using the **Fleetman Fleet Management** demo application on a local [kind](https://kind.sigs.k8s.io/) cluster.

---

## Prerequisites

### 1. Install kind
```bash
# macOS
brew install kind

# Linux (AMD64)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
```

### 2. Install kubectl
```bash
# macOS
brew install kubectl

# Linux
sudo apt-get update && sudo apt-get install -y kubectl
```

### 3. Install k9s (optional — terminal UI)
```bash
brew install derailed/k9s/k9s
```

---

## Cluster Setup

Create the cluster once before starting any chapter:

```bash
kind create cluster --config=cluster/kind-config.yaml
```

Verify the cluster is ready:
```bash
kubectl cluster-info
kubectl get nodes
# Expected: 1 control-plane + 2 worker nodes with status Ready
```

> **Note:** With kind, NodePort services are not directly accessible via `localhost:<nodePort>`.  
> Use `kubectl port-forward` to access them locally (shown in each chapter).

---

## Chapter 5 — Pods

**Concepts:** Pod lifecycle, `kubectl` basics, exec into containers.

```bash
cd "Chapter 5 Pods"
```

### Apply
```bash
kubectl apply -f first-pod.yaml
```

### Explore
```bash
# Check pod status
kubectl get pods

# Detailed info and events
kubectl describe pod webapp

# View logs
kubectl logs webapp

# Execute a shell inside the pod
kubectl exec -it webapp -- sh
```

### Access the app
```bash
kubectl port-forward pod/webapp 8080:80
# Open http://localhost:8080
```

> At this stage the pod has no labels — it cannot be targeted by a Service yet.

### Cleanup
```bash
kubectl delete -f first-pod.yaml
```

---

## Chapter 6 — Services

**Concepts:** Labels, selectors, NodePort, zero-downtime release switching.

```bash
cd "Chapter 6 Services"
```

### Apply
```bash
kubectl apply -f first-pod.yaml     # creates webapp (release 0) and webapp-release-0-5
kubectl apply -f webapp-service.yaml  # NodePort service selecting release: "0-5"
```

### Explore
```bash
kubectl get pods --show-labels
kubectl get services
kubectl describe service fleetman-webapp
```

### Access the app
```bash
kubectl port-forward service/fleetman-webapp 8080:80
# Open http://localhost:8080 — you are hitting release 0-5
```

### Demo: zero-downtime release switch

The service selector currently points to `release: "0-5"`. Edit `webapp-service.yaml` and change the selector to `release: "0"`, then re-apply:

```bash
kubectl apply -f webapp-service.yaml
# Refresh http://localhost:8080 — now hitting release 0, no restart needed
```

### Cleanup
```bash
kubectl delete -f first-pod.yaml
kubectl delete -f webapp-service.yaml
```

---

## Chapter 7 — Exercise

**Concepts:** Combine multiple pods (webapp + queue) with multiple services.

```bash
cd "Chapter 7 Exercise"
```

### Apply
```bash
kubectl apply -f pods.yaml
kubectl apply -f services.yaml
```

### Explore
```bash
kubectl get pods
kubectl get services
kubectl get endpoints
```

### Access
```bash
# Webapp (port 30080)
kubectl port-forward service/fleetman-webapp 8080:80
# Open http://localhost:8080

# ActiveMQ Queue admin UI (port 30010)
kubectl port-forward service/fleetman-queue 8161:8161
# Open http://localhost:8161  (user: admin / password: admin)
```

### Cleanup
```bash
kubectl delete -f pods.yaml
kubectl delete -f services.yaml
```

---

## Chapter 8 — ReplicaSets

**Concepts:** Self-healing, scaling, pod template.

```bash
cd "Chapter 8 ReplicaSets"
```

### Apply
```bash
kubectl apply -f pods.yaml      # ReplicaSet (2 replicas) + queue pod
kubectl apply -f services.yaml
```

### Explore
```bash
kubectl get replicasets
kubectl get pods -l app=webapp

# Describe the ReplicaSet
kubectl describe replicaset webkubeapp
```

### Demo: self-healing

Delete one of the webapp pods manually — the ReplicaSet recreates it automatically:

```bash
# Get a pod name
kubectl get pods -l app=webapp

# Delete it
kubectl delete pod <pod-name>

# Watch it come back
kubectl get pods -l app=webapp -w
```

### Demo: scale
```bash
kubectl scale replicaset webapp --replicas=4
kubectl get pods -l app=webapp
kubectl scale replicaset webapp --replicas=2
```

### Access
```bash
kubectl port-forward service/fleetman-webapp 8080:80
```

### Cleanup
```bash
kubectl delete -f pods.yaml
kubectl delete -f services.yaml
```

---

## Chapter 9 — Deployments

**Concepts:** Rolling updates, rollback, revision history.

```bash
cd "Chapter 9 Deployments"
```

### Apply
```bash
kubectl apply -f pods.yaml      # Deployment (2 replicas) + queue pod
kubectl apply -f services.yaml
```

### Explore
```bash
kubectl get deployments
kubectl describe deployment webapp
kubectl rollout status deployment/webapp
```

### Demo: rolling update

Edit `pods.yaml` and change the webapp image tag from `release0-5-arm64` to `release0-arm64`, then re-apply:

```bash
kubectl apply -f pods.yaml
kubectl rollout status deployment/webapp
```

Or update the image directly:
```bash
kubectl set image deployment/webapp webapp=richardchesterwood/k8s-fleetman-webapp-angular:release0-arm64
kubectl rollout status deployment/webapp
```

### Demo: rollback
```bash
# View history
kubectl rollout history deployment/webapp

# Roll back to previous version
kubectl rollout undo deployment/webapp
kubectl rollout status deployment/webapp
```

> **Tip:** Uncomment `minReadySeconds: 30` in `pods.yaml` and re-apply to slow down the rollout and watch pods transition one by one.

### Access
```bash
kubectl port-forward service/fleetman-webapp 8080:80
```

### Cleanup
```bash
kubectl delete -f pods.yaml
kubectl delete -f services.yaml
```

---

## Chapter 10 — Networking

**Concepts:** ClusterIP vs NodePort, internal DNS, service discovery, connecting to a database.

```bash
cd "Chapter 10 Networking"
```

### Apply
```bash
kubectl apply -f pods.yaml           # webapp Deployment + queue pod
kubectl apply -f services.yaml       # NodePort services
kubectl apply -f networking-tests.yaml  # MySQL pod + ClusterIP service
```

### Explore services
```bash
kubectl get services
# fleetman-webapp  → NodePort  (external access)
# fleetman-queue   → NodePort  (external access)
# database         → ClusterIP (internal only)
```

### Demo: internal DNS resolution

Exec into a running pod and resolve service names:

```bash
# Get any webapp pod name
kubectl get pods -l app=webapp

kubectl exec -it <webapp-pod-name> -- sh

# Inside the pod — test DNS resolution:
nslookup database
nslookup fleetman-queue
nslookup fleetman-webapp

# Try connecting to MySQL (ClusterIP — reachable from inside the cluster only):
nc -zv database 3306

exit
```

### Demo: ClusterIP is not reachable from your laptop

```bash
# Get the ClusterIP of the database service
kubectl get service database

# This will time out — ClusterIP only routes inside the cluster:
curl http://<cluster-ip>:3306
```

### Access webapp
```bash
kubectl port-forward service/fleetman-webapp 8080:80
# Open http://localhost:8080
```

### Cleanup
```bash
kubectl delete -f networking-tests.yaml
kubectl delete -f pods.yaml
kubectl delete -f services.yaml
```

---

## Chapter 11 — Microservices

**Concepts:** Full microservices architecture, inter-service communication, service mesh overview.

```bash
cd "Chapter 11 Microservices"
```

### Architecture

```
Browser
  └─► fleetman-webapp (NodePort 30080)
         └─► fleetman-api-gateway (NodePort 30020)
                ├─► fleetman-position-tracker (ClusterIP)
                │       └─► fleetman-queue (NodePort 30010)
                │               └─► position-simulator
                └─► [future services]
```

### Apply
```bash
kubectl apply -f services.yaml    # apply services first so DNS is ready
kubectl apply -f workloads.yaml   # 5 deployments: queue, position-simulator, position-tracker, api-gateway, webapp
```

### Watch all pods come up
```bash
kubectl get pods -w
# Wait until all pods show Running (may take 1-2 min on first pull)
```

### Explore
```bash
kubectl get deployments
kubectl get services

# Check logs for each service
kubectl logs deployment/position-simulator
kubectl logs deployment/position-tracker
kubectl logs deployment/api-gateway
kubectl logs deployment/webapp
```

### Access
```bash
# Main webapp
kubectl port-forward service/fleetman-webapp 8080:80
# Open http://localhost:8080 — vehicles should appear on the map

# ActiveMQ admin console
kubectl port-forward service/fleetman-queue 8161:8161
# Open http://localhost:8161 (admin / admin) — see messages flowing

# API gateway directly
kubectl port-forward service/fleetman-api-gateway 8020:8080
# Open http://localhost:8020/api/vehicles
```

### Demo: kill and recover a microservice
```bash
# Delete the api-gateway pod — Deployment recreates it automatically
kubectl delete pod -l app=api-gateway
kubectl get pods -w
```

### Cleanup
```bash
kubectl delete -f workloads.yaml
kubectl delete -f services.yaml
```

---

## Tear Down the Cluster

When the lab is fully done:

```bash
kind delete cluster --name devops-cluster
```

---

## Quick Reference

| Command | Description |
|---|---|
| `kubectl get pods` | List all pods |
| `kubectl get pods -w` | Watch pods in real-time |
| `kubectl describe pod <name>` | Events + detailed status |
| `kubectl logs <name>` | Container logs |
| `kubectl exec -it <name> -- sh` | Shell into a pod |
| `kubectl port-forward service/<name> <local>:<remote>` | Forward a service port locally |
| `kubectl rollout status deployment/<name>` | Watch a rollout |
| `kubectl rollout undo deployment/<name>` | Roll back one revision |
| `kubectl scale deployment <name> --replicas=N` | Scale a deployment |
| `kubectl delete -f <file>` | Delete resources from a manifest |

---

## Folder Structure

```
k8s/
├── cluster/
│   └── kind-config.yaml          # kind cluster: 1 control-plane + 2 workers
├── Chapter 5 Pods/
│   └── first-pod.yaml
├── Chapter 6 Services/
│   ├── first-pod.yaml
│   └── webapp-service.yaml
├── Chapter 7 Exercise/
│   ├── pods.yaml
│   └── services.yaml
├── Chapter 8 ReplicaSets/
│   ├── pods.yaml
│   └── services.yaml
├── Chapter 9 Deployments/
│   ├── pods.yaml
│   └── services.yaml
├── Chapter 10 Networking/
│   ├── pods.yaml
│   ├── services.yaml
│   └── networking-tests.yaml
└── Chapter 11 Microservices/
    ├── workloads.yaml
    └── services.yaml
```
