# Arquitectura del sistema — Infraestructura GreenDevCorp

## Diagrama complet del sistema

```
                       INTERNET / DESENVOLUPADOR
                                  │
                          ┌───────▼────────┐
                          │   GitHub       │
                          │   (git push)   │
                          └───────┬────────┘
                                  │ trigger
                    ┌─────────────▼─────────────┐
                    │   GitHub Actions (CI)      │
                    │  ┌────────────────────┐    │
                    │  │ Construir img back │    │
                    │  │ Construir img nginx│    │
                    │  │ Escaneig Trivy     │    │
                    │  │ Validar Terraform  │    │
                    │  └─────────┬──────────┘    │
                    └────────────┼───────────────┘
                                 │ push imatges
                    ┌────────────▼───────────────┐
                    │       Docker Hub            │
                    │  greendevcorp/backend:sha-* │
                    │  greendevcorp/nginx:sha-*   │
                    └────────────┬───────────────┘
                                 │ pull (desplegament local)
                    ┌────────────▼───────────────┐
                    │   terraform apply           │
                    │   (week11/terraform/)       │
                    └────────────┬───────────────┘
                                 │
              ┌──────────────────▼──────────────────────┐
              │         Minikube (Kubernetes)            │
              │                                          │
              │  ┌─────────┐   NetworkPolicy             │
              │  │  nginx  │   (default-deny + allowlist)│
              │  │ :8080   ├──────────────────────┐      │
              │  │ NodePort│                      │      │
              │  │  30080  │                 TCP 3000     │
              │  └────┬────┘                      │      │
              │       │ (accés extern)      ┌─────▼────┐ │
              │  navegador/curl             │ backend  │ │
              │                             │  :3000   │ │
              │                             └─────┬────┘ │
              │                             TCP 5432      │
              │                             ┌─────▼────┐ │
              │                             │ postgres │ │
              │                             │  :5432   │ │
              │                             │StatefulSet│ │
              │                             │  PVC 1Gi │ │
              │                             └──────────┘ │
              └──────────────────────────────────────────┘

         DESENVOLUPAMENT LOCAL (Docker Compose — week9/)
         ┌──────────────────────────────────────────────┐
         │  frontend-net          backend-net            │
         │  ┌───────┐            ┌──────────┐           │
         │  │ nginx │──TCP 8080──│ backend  │           │
         │  │ :80   │            │ :3000    │           │
         │  └───────┘            └────┬─────┘           │
         │                      TCP 5432                 │
         │                      ┌─────▼────┐             │
         │                      │postgres  │             │
         │                      │ :5432    │             │
         │                      └──────────┘             │
         │  monitoring-net                               │
         │  ┌──────────────┐  ┌─────────┐               │
         │  │  Prometheus  │  │ Grafana │               │
         │  │  :9090       │  │  :3001  │               │
         │  └──────┬───────┘  └─────────┘               │
         │         │ scrape                              │
         │  ┌──────▼───────┐                            │
         │  │ node-exporter│                            │
         │  │ :9100        │                            │
         │  └──────────────┘                            │
         └──────────────────────────────────────────────┘
```

## Inventari de components

| Component     | Tecnologia                  | Rol                              | Xarxa                         |
|---------------|-----------------------------|----------------------------------|-------------------------------|
| nginx         | nginx:alpine (no root)      | Reverse proxy / frontend estàtic | frontend-net                  |
| backend       | node:20-alpine + prom-client| API REST + endpoint de mètriques | frontend-net + backend-net    |
| postgres      | postgres:16-alpine          | Base de dades relacional         | backend-net                   |
| Prometheus    | prom/prometheus             | Recollida de mètriques           | frontend-net + monitoring-net |
| Grafana       | grafana/grafana             | Visualització de mètriques       | monitoring-net                |
| node-exporter | prom/node-exporter          | Mètriques del sistema host       | monitoring-net                |

## Fluxos de dades

| Flux                         | Protocol | Port                     | Permès per                           |
|------------------------------|----------|--------------------------|--------------------------------------|
| Internet → nginx             | HTTP     | 30080 (NodePort) / 80 (Compose) | NodePort / port-forward         |
| nginx → backend              | HTTP     | 3000                     | NetworkPolicy allow-frontend-backend |
| backend → postgres           | PostgreSQL| 5432                    | NetworkPolicy allow-backend-postgres |
| Prometheus → backend         | HTTP scrape| 3000                   | frontend-net (Compose)               |
| Prometheus → node-exporter   | HTTP scrape| 9100                   | monitoring-net                       |
| Grafana → Prometheus         | HTTP query | 9090                   | monitoring-net                       |
| Tots els pods → kube-dns     | UDP/TCP  | 53                       | NetworkPolicy allow-dns              |

## Arquitectura de seguretat

- **Zero-trust default-deny**: tot el tràfic Kubernetes bloquejat excepte el permès explícitament.
- **Contenidors no root**: nginx s'executa com `nginxuser`, backend com `appuser`.
- **Builds Docker multistage**: les imatges de producció no contenen eines de compilació ni fitxers font.
- **Gestió de secrets**: credencials de PostgreSQL via Kubernetes Secrets / variables sensibles de Terraform (mai commitats).
- **Escaneig d'imatges**: Trivy s'executa al CI en cada push; falla el build en CVEs CRITICAL/HIGH.
- **Segmentació de xarxa**: frontend-net aïllada de backend-net; monitoring-net aïllada de les dues.

## Flux IaC i CI/CD

```
Canvi de codi
  → git push
  → GitHub Actions CI
      ├── docker buildx build (capes en cache)
      ├── push imatge amb tag SHA a Docker Hub
      ├── Trivy scan (falla en CRITICAL/HIGH)
      └── terraform fmt/init/validate
  → [CI en verd]
  → l'equip executa: terraform apply -var-file=dev.tfvars -var="backend_image=...:sha-abc123"
  → Kubernetes actualitza els Pods sense temps d'inactivitat
```

## Procediment de rollback

```bash
# Opció 1 — Rollback natiu de Kubernetes
kubectl rollout undo deployment/backend-dev
kubectl rollout status deployment/backend-dev

# Opció 2 — Rollback via Terraform al tag anterior
terraform apply -var-file=dev.tfvars -var="backend_image=<usuari>/backend:sha-<sha-anterior>"

# Comprovar l'historial de rollouts
kubectl rollout history deployment/backend-dev
```
