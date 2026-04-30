# Week 10 — Orchestration (Kubernetes)

## Overview

This week we move our containerized application to Kubernetes. Kubernetes provides orchestration, allowing us to manage containers at scale with automatic recovery, rolling updates, and resource management.

Our infrastructure is split into a frontend component (Nginx) and backend components (Node.js backend + Postgres database).

## Backend & Database (Persona B)

This section documents the Kubernetes manifests for the Backend and Database services, fulfilling Core, Intermediate, and Advanced requirements.

### 1. Backend Service

The backend is stateless and deployed using a `Deployment`.

- **Deployment (`backend-deployment.yaml`)**:
  - **Replicas**: 2 (Demonstrates basic scaling).
  - **Image**: `greendevcorp/backend:week9`.
  - **Configuration**: Uses a `ConfigMap` (`backend-config`) to inject the `PORT` environment variable. Database credentials are injected securely via a `Secret`.
  - **Resource Limits (Intermediate)**: Requests 128Mi RAM / 250m CPU, limits to 256Mi RAM / 500m CPU.
  - **Probes (Intermediate)**: Both `livenessProbe` and `readinessProbe` are configured using `wget` to ping the `/health` endpoint. This ensures Kubernetes only routes traffic to healthy pods and automatically restarts failing ones.

- **Service (`backend-service.yaml`)**:
  - Creates a `ClusterIP` service to expose the backend pods internally on port `3000`.

- **ConfigMap (`backend-configmap.yaml`)**:
  - Centralizes configuration parameters.

### 2. Postgres Database

The database is stateful and requires persistent storage, so it is deployed using a `StatefulSet`.

- **StatefulSet (`postgres-statefulset.yaml`)**:
  - **Advanced (***)**: Uses `volumeClaimTemplates` to automatically provision a `PersistentVolumeClaim` (PVC) of 1Gi for `/var/lib/postgresql/data`. This guarantees data persists across pod restarts and rescheduling.
  - **Image**: `postgres:16-alpine`.
  - **Probes (Intermediate)**: Uses `pg_isready` to verify the database is ready to accept connections.
  - **Resource Limits (Intermediate)**: Requests 256Mi RAM / 500m CPU, limits to 512Mi RAM / 1000m CPU.

- **Service (`postgres-service.yaml`)**:
  - Creates a `ClusterIP` service to expose Postgres on port `5432` for the backend.

- **Secret (`postgres-secret.yaml`)**:
  - Stores base64-encoded database credentials (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`).

---

## Frontend (Persona A)

### 1. Nginx Service

The frontend is stateless and deployed using a `Deployment`.

- **Deployment (`nginx-deployment.yaml`)**:
  - **Replicas**: 2 (mirrors the backend scaling approach).
  - **Image**: `greendevcorp/nginx:week9` — non-root Nginx that proxies `/api/` requests to the backend service.
  - **`imagePullPolicy: Never`**: The image is built and loaded locally into Minikube; this prevents Kubernetes from attempting a pull from Docker Hub (where the image is private/absent).
  - **Port**: `8080` (unprivileged port, consistent with the week 9 non-root setup).
  - **Resource Limits (Intermediate)**: Requests 64Mi RAM / 100m CPU, limits to 128Mi RAM / 250m CPU.
  - **Probes (Intermediate)**: Both `livenessProbe` and `readinessProbe` use `httpGet` on the `/health` endpoint (port 8080). Kubernetes will only route traffic to healthy pods and will restart any that fail.

- **Service (`nginx-service.yaml`)**:
  - Creates a `NodePort` service that maps external port `30080` → internal port `8080`.
  - Using `NodePort` (instead of `ClusterIP`) exposes the frontend to external traffic, making it reachable via `minikube ip:30080` during local development.

---

## Architecture & Communication

### How pods communicate (service discovery)

Kubernetes assigns a stable DNS name to every Service. Pods reach each other using these names — no hardcoded IPs needed:

| Caller | Target | DNS name used |
|--------|--------|---------------|
| Nginx | Backend | `http://backend:3000` |
| Backend | Postgres | `postgres:5432` |

CoreDNS (the cluster's DNS server) resolves `backend` → `backend.default.svc.cluster.local` → ClusterIP automatically. This is why the nginx `proxy_pass` and the backend `PGHOST=postgres` env variable work without any IP configuration.

### How external clients reach the frontend

- The `nginx` Service is of type **NodePort**, which opens port `30080` on the Minikube node.
- On Linux/macOS: `http://$(minikube ip):30080`
- On Windows (Docker Desktop): the Minikube node IP is not directly routable from the host. Use `kubectl port-forward` instead:
  ```bash
  kubectl port-forward svc/nginx 8080:80
  # → access at http://localhost:8080
  ```
- Backend and Postgres use **ClusterIP** (internal only) — they are never exposed outside the cluster.

### Scaling behaviour

When `kubectl scale deployment nginx --replicas=3` is run, Kubernetes:
1. Creates a third pod from the same template.
2. The `nginx` Service automatically load-balances traffic across all 3 pods (round-robin via kube-proxy).
3. No downtime occurs because existing pods keep serving while the new one starts.
4. The readiness probe gates traffic: the new pod only receives requests once `/health` returns 200.

When a pod is killed (`kubectl delete pod -l app=backend`), the Deployment controller detects the missing replica and schedules a replacement immediately — demonstrating automatic self-healing.

---

## How to Run & Verify

### Prerequisites — load images into Minikube

The custom images are not on a public registry, so they must be built locally and loaded into Minikube's Docker daemon before deploying:

```bash
# Build (if not already built)
docker build -t greendevcorp/nginx:week9 week9/nginx/
docker build -t greendevcorp/backend:week9 week9/backend/

# Load into Minikube
minikube image load greendevcorp/nginx:week9
minikube image load greendevcorp/backend:week9
```

### Deploy

1. Start Minikube:
   ```bash
   minikube start
   ```

2. Apply the manifests:
   ```bash
   kubectl apply -f kubernetes/
   ```

3. Check the status of pods, services, and PVCs:
   ```bash
   kubectl get pods
   kubectl get services
   kubectl get pvc
   ```

4. Access the frontend (Windows):
   ```bash
   kubectl port-forward svc/nginx 8080:80
   # Open http://localhost:8080
   ```

5. Test Scaling:
   ```bash
   kubectl scale deployment backend --replicas=3
   kubectl get pods --watch   # observe new pod appearing
   kubectl scale deployment backend --replicas=2
   ```

6. Test Resilience:
   ```bash
   kubectl delete pod -l app=backend
   kubectl get pods --watch   # observe automatic restart
   ```

