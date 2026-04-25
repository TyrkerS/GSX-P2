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

## Frontend (Persona A) - TO BE COMPLETED


### 1. Nginx Service

- **Deployment (`nginx-deployment.yaml`)**:
  - ...
- **Service (`nginx-service.yaml`)**:
  - ...

---

## How to Run & Verify


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

4. Test Scaling:
   ```bash
   kubectl scale deployment backend --replicas=3
   ```

5. Test Resilience:
   ```bash
   kubectl delete pod -l app=backend
   ```

