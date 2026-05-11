# Week 13: Integration, Observability & Finalization

> **Estat:** Completada.

## Challenge A: Observability amb Prometheus i Grafana

### Arquitectura de monitorització

S'ha integrat un stack d'observabilitat complet al `docker-compose.yml` de la setmana 9:

| Servei | Imatge | Port | Funció |
|--------|--------|------|--------|
| prometheus | prom/prometheus | 9090 | Recull mètriques cada 15s |
| grafana | grafana/grafana | 3001 | Visualitza mètriques amb dashboards |
| node-exporter | prom/node-exporter | 9100 | Mètriques del sistema host/VM |

### Instrumentació de l'aplicació

El backend Node.js ara exposa el endpoint `/metrics` amb **prom-client** (llibreria oficial de Prometheus per a Node.js). Mètriques implementades:

**Mètriques per defecte (prom-client `collectDefaultMetrics`):**
- `nodejs_heap_size_used_bytes` — memòria heap usada
- `nodejs_heap_size_total_bytes` — memòria heap total
- `process_cpu_seconds_total` — ús de CPU
- `nodejs_eventloop_lag_seconds` — lag del event loop

**Mètriques personalitzades:**
- `http_requests_total{method, status_code, path}` — comptador de requests per codi HTTP
- `http_request_duration_seconds{method, path}` — histograma de latència

### Com s'ha configurat Prometheus

El fitxer `week9/monitoring/prometheus/prometheus.yml` defineix tres scrape targets:

```yaml
scrape_configs:
  - job_name: 'backend'
    static_configs:
      - targets: ['backend:3000']   # /metrics endpoint de l'app
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

Prometheus pertany a la xarxa `frontend-net` (per arribar al backend) i a `monitoring-net` (per parlar amb Grafana i node-exporter).

### Dashboard de Grafana

El dashboard `GreenDevCorp — Application Overview` (provisionat automàticament a l'arrancada) inclou:

1. **HTTP Request Rate** — peticions per segon per endpoint
2. **HTTP Request Duration p50/p95/p99** — latència percentil
3. **Requests by HTTP Status Code** — pastís d'èxits vs errors
4. **Node.js Heap Memory** — memòria heap used vs total
5. **CPU Usage** — percentatge de CPU del procés backend
6. **Event Loop Lag** — salut del runtime Node.js
7. **Total Requests (últims 5m)** — comptador de requests recent
8. **Host CPU (node-exporter)** — CPU del sistema subjacent

### Com accedir

```bash
cd week9/
cp .env.example .env   # editar amb credencials reals
docker-compose up -d

# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3001  (admin / valor de GRAFANA_PASSWORD a .env)
```

### Decisió de disseny: Docker Compose vs Kubernetes per a Monitoring

Per a la demostració de l'assignació, s'ha optat per integrar Prometheus i Grafana al Docker Compose (setmana 9) en lloc de Kubernetes. **Raonament:** el Compose és l'entorn que té el backend amb mètriques, és reproduïble localment sense Minikube, i és el nivell on es pot generar tràfic real. En producció real, el stack de monitoring s'executaria en Kubernetes (via Helm chart `kube-prometheus-stack`), però el concepte i la configuració és idèntic.

---

## Challenge B: Full Integration Test

### Procediment

L'objectiu és demostrar que la infraestructura és **completament reproducible des de zero** a partir del codi IaC.

#### Pas 1: Destruir l'entorn anterior

```powershell
cd week11/terraform/
terraform destroy -var-file=dev.tfvars -auto-approve

# Verificar que no queda res
kubectl get pods
kubectl get services
kubectl get pvc
```

**Resultat esperat:** "No resources found" en tots els comandaments.

#### Pas 2: Desplegar des de zero amb Terraform

```powershell
terraform apply -var-file=dev.tfvars -auto-approve
```

**Resultat esperat:**
```
kubernetes_config_map.nginx_config: Creating...
kubernetes_secret.postgres_secret: Creating...
kubernetes_config_map.backend_config: Creating...
...
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
```

#### Pas 3: Verificar que tot arranca

```powershell
# Esperar que tots els pods estiguin Ready
kubectl wait --for=condition=Ready pods --all --timeout=180s

# Llistar pods
kubectl get pods
```

**Resultat esperat:**
```
NAME                              READY   STATUS    RESTARTS   AGE
backend-dev-xxx                   1/1     Running   0          90s
backend-dev-yyy                   1/1     Running   0          90s
nginx-dev-xxx                     1/1     Running   0          90s
nginx-dev-yyy                     1/1     Running   0          90s
postgres-dev-0                    1/1     Running   0          90s
```

#### Pas 4: Verificar comunicació end-to-end

```powershell
# Accedir a Nginx des del host (crea túnel automàtic)
minikube service nginx-dev

# O via port-forward
kubectl port-forward svc/nginx-dev 8080:80 &
curl http://localhost:8080/
curl http://localhost:8080/health
```

**Resultat esperat:** HTTP 200 amb resposta JSON del backend.

#### Pas 5: Verificar NetworkPolicies

```powershell
# Aplicar les policies
kubectl apply -f ../../week12/network-policies/

# Test: tràfic no autoritzat bloquejat
kubectl run tester --rm -it --image=busybox --restart=Never -- wget -qO- --timeout=5 http://backend-dev:3000/
# Esperat: timeout (bloquejat per default-deny)

# Test: tràfic autoritzat funciona
$NGINX_POD = kubectl get pod -l app=nginx -o jsonpath='{.items[0].metadata.name}'
kubectl exec $NGINX_POD -- wget -qO- --timeout=5 http://backend-dev:3000/health
# Esperat: {"status":"healthy","service":"backend"}
```

#### Pas 6: Verificar Docker Compose + Observabilitat

```powershell
cd ../../week9/
docker-compose up -d
docker-compose ps   # tots els serveis healthy

# Generar tràfic
for ($i=0; $i -lt 20; $i++) { curl http://localhost/ ; curl http://localhost/health }

# Verificar mètriques
curl http://localhost:9090/api/v1/query?query=http_requests_total
# Obrir Grafana: http://localhost:3001
```

### Resultat del test

| Verificació | Resultat |
|------------|---------|
| `terraform apply` des de zero | ✅ Tots els recursos creats |
| 5 pods en Running | ✅ nginx×2, backend×2, postgres×1 |
| HTTP 200 via NodePort | ✅ Nginx serveix contingut |
| Comunicació nginx→backend | ✅ Proxy `/api/` funciona |
| Persistència postgres (PVC) | ✅ Dades sobreviuen al restart del pod |
| NetworkPolicies: tràfic bloquejat | ✅ Timeout des de pod sense labels |
| NetworkPolicies: tràfic permès | ✅ nginx→backend health check OK |
| Docker Compose stack | ✅ 6 serveis healthy |
| Prometheus scraping backend | ✅ Target UP a http://localhost:9090/targets |
| Dashboard Grafana | ✅ Mètriques visibles a http://localhost:3001 |

**Temps de desplegament Kubernetes des de zero:** aproximadament 60-90 segons (primer cop, depèn de la descàrrega d'imatges).

### Script automatitzat

El script `week11/verify-e2e.ps1` automatitza els passos 1-4 i fa un smoke test HTTP. S'executa amb:

```powershell
cd week11/
.\verify-e2e.ps1
```

---

## Challenge C: Documentation

La documentació completa del projecte es troba distribuïda de la manera següent:

| Document | Ubicació | Contingut |
|----------|---------|-----------|
| Architecture | `week13/ARCHITECTURE.md` | Diagrama complet, flux de dades, seguretat |
| Runbook | `week13/RUNBOOK.md` | Com desplegar, escalar, fer rollback |
| Troubleshooting | `week13/TROUBLESHOOTING.md` | Errors comuns i com diagnosticar-los |
| Week 8 docs | `week8/Documentation.md` | Docker, Dockerfiles, seguretat |
| Week 9 docs | `week9/Documentation.md` | Docker Compose, xarxes, volums |
| Week 10 docs | `week10/Documentation.md` | Kubernetes, StatefulSets, probes |
| Week 11 docs | `week11/Documentation.md` | Terraform, CI/CD, flux end-to-end |
| Week 12 docs | `week12/Documentation.md` | Xarxa, NetworkPolicies, identitat |
| README | `README.md` | Quick start, links a tota la documentació |

---

## Challenge D: Reflection & Interview Prep

### Preguntes freqüents d'entrevista

**"Per què Kubernetes i no Docker Compose per a producció?"**
Compose és ideal per a desenvolupament local: simple, ràpid, un sol fitxer. Kubernetes és necessari quan necessites: auto-healing (reinicia pods caiguts), scaling horitzontal automàtic, rolling updates sense downtime, i gestió de múltiples nodes. Per a GreenDevCorp creixent, Kubernetes és la resposta correcta; per al laptop d'un desenvolupador, Compose és suficient.

**"Un contenidor cau. Com ho debugueges?"**
`kubectl get pods` per veure l'estat. `kubectl describe pod <name>` per veure events i motiu del cràsh. `kubectl logs <name> --previous` per veure logs de la darrera execució. Si és `ImagePullBackOff`, el tag de la imatge és incorrecte. Si és `CrashLoopBackOff`, l'app falla a l'arrancada (buscar l'error als logs). Si és `OOMKilled`, els resource limits de memòria són massa baixos.

**"Com gestionaries 10x de tràfic?"**
Escalar els deployments de backend (`kubectl scale` o `terraform apply -var="backend_replicas=10"`). Activar Horizontal Pod Autoscaler (HPA) per escalar automàticament per mètriques de CPU/requests. Postgres és l'únic StatefulSet — no s'escala horitzontalment sense read replicas (ProxSQL / Patroni). A llarg termini, moure a una base de dades gestionada (AWS RDS, Cloud SQL).

**"Quin és el punt feble de la vostra arquitectura?"**
El Nginx és un SPOF (Single Point of Failure): si cau, tot el tràfic s'atura. En producció real, substituiríem el Nginx propi per un Ingress Controller amb múltiples rèpliques (nginx-ingress o Traefik) darrere d'un LoadBalancer extern. A més, les NetworkPolicies actuals no inspeccionen L7 (no prevenen SQL injection dins connexions TCP autoritzades).

**"Quin seria el proper pas si tinguéssiu més temps?"**
1. Ingress Controller amb certificat TLS (cert-manager + Let's Encrypt)
2. Horizontal Pod Autoscaler basat en mètriques Prometheus (KEDA)
3. Implementació real d'OpenLDAP o Dex per a autenticació centralitzada a Kubernetes
4. Pipeline CD automatitzat cap a Minikube via self-hosted runner o ArgoCD

### Reflexions individuals

Pol Regy Borja


Dana Elena Asaftei



### Captura del dashboard

![Dashboard GreenDevCorp — Grafana](grafana-dashboard.png)
