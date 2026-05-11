# Infraestructura GreenDevCorp — GSX Pràctica 2

Infraestructura cloud-native moderna per a una startup en creixement, construïda al llarg de 6 setmanes. Cobreix contenidors, orquestració, Infraestructura com a Codi, CI/CD, seguretat de xarxa i observabilitat.

## Inici ràpid

### Opció A — Docker Compose (desenvolupament, tot-en-un)

```bash
cd week9/
cp .env.example .env        # editar amb les credencials reals
docker-compose up -d
```

| Servei | URL |
|--------|-----|
| Aplicació (nginx) | http://localhost:80 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3001 (admin / valor de GRAFANA_PASSWORD a .env) |

### Opció B — Kubernetes via Terraform (semblant a producció)

```bash
# Iniciar Minikube amb Calico CNI (necessari per a les NetworkPolicies)
minikube start --cni=calico

# Desplegar tot des d'IaC
cd week11/terraform/
cp example.tfvars dev.tfvars   # omplir les credencials de postgres
terraform init
terraform apply -var-file=dev.tfvars

# Accedir a l'aplicació
minikube service nginx-dev

# Aplicar les polítiques de seguretat de xarxa
kubectl apply -f week12/network-policies/
```

---

## Estructura del projecte

```
GSX-P2/
├── .github/workflows/
│   └── ci-backend.yml          Pipeline CI: build + push + escaneig Trivy + validació Terraform
├── week8/                      Docker — contenidoritzar dues aplicacions
│   ├── application/            Backend Node.js (multistage, no root, mètriques prom-client)
│   ├── nginx/                  Frontend Nginx (alpine, no root, port 8080)
│   └── Documentation.md
├── week9/                      Docker Compose — orquestració multi-contenidor
│   ├── docker-compose.yml      nginx + backend + postgres + prometheus + grafana + node-exporter
│   ├── monitoring/
│   │   ├── prometheus/         configuració de scrape prometheus.yml
│   │   └── grafana/            datasource + dashboard proveïts automàticament
│   ├── .env.example            plantilla de variables d'entorn
│   └── Documentation.md
├── week10/                     Kubernetes — desplegar, escalar, auto-recuperar
│   ├── kubernetes/             Deployments, Services, ConfigMaps, StatefulSet, PVC
│   └── Documentation.md
├── week11/                     Infraestructura com a Codi + CI/CD
│   ├── terraform/              Terraform gestiona el stack K8s complet (main.tf, variables.tf, outputs.tf)
│   ├── verify-e2e.ps1          script de test d'integració end-to-end
│   └── Documentation.md
├── week12/                     Disseny de xarxa + identitat
│   ├── diagrams/               network-architecture.md (Mermaid), cidr-plan.md
│   ├── network-policies/       zero-trust default-deny + NetworkPolicies en allowlist
│   ├── research/               explicacions DNS/DHCP/NTP, estratègia d'identitat (LDAP/AD/SSO)
│   └── Documentation.md
└── week13/                     Integració, observabilitat i finalització
    ├── ARCHITECTURE.md         diagrama complet del sistema + fluxos de dades
    ├── RUNBOOK.md              com desplegar, escalar, fer rollback, comprovar logs
    ├── TROUBLESHOOTING.md      problemes habituals i com diagnosticar-los
    ├── Documentation.md        Repte A (observabilitat), B (test d'integració), C+D
    └── REFLECTION_TEMPLATE.md  plantilla per als assaigs individuals
```

---

## Què s'ha construït

| Setmana | Tema | Nivell |
|---------|------|--------|
| 8 | Docker: builds multistage, usuaris no root, instrumentació de mètriques Prometheus | ★★★ Avançat |
| 9 | Docker Compose: 3 serveis d'app + 3 serveis de monitoratge, xarxes personalitzades, healthchecks, límits de recursos | ★★★ Avançat |
| 10 | Kubernetes: Deployments, StatefulSet (postgres + PVC), sondes, escalat, auto-recuperació | ★★★ Avançat |
| 11 | Terraform IaC + GitHub Actions CI (cache Buildx + escaneig Trivy + validació Terraform) | ★★★ Avançat |
| 12 | Disseny de xarxa (CIDR), NetworkPolicies zero-trust (Calico), estratègia d'identitat (LDAP/AD/SSO) | ★★ Intermedi |
| 13 | Prometheus + dashboard Grafana, test d'integració complet, documentació completa | ★★ Intermedi |

---

## Pipeline CI/CD

Cada `git push` a `main` dispara GitHub Actions:

```
push → GitHub Actions
  ├── Construir imatge backend (Docker Buildx + cache GHA) → Docker Hub
  ├── Construir imatge nginx  (Docker Buildx + cache GHA) → Docker Hub
  ├── Escaneig de seguretat Trivy backend (falla en CVEs CRITICAL/HIGH)
  ├── Escaneig de seguretat Trivy nginx   (falla en CVEs CRITICAL/HIGH)
  └── terraform fmt/init/validate (sense apply remot)
```

Secrets de GitHub necessaris: `DOCKER_USERNAME`, `DOCKER_PASSWORD`.

---

## Seguretat de xarxa

Kubernetes fa servir un model **zero-trust default-deny** aplicat per les NetworkPolicies de Calico:

- Tot l'ingress i egress bloquejat per defecte
- Allowlist explícita: nginx → backend (TCP 3000), backend → postgres (TCP 5432)
- Tots els pods poden arribar a kube-dns (UDP/TCP 53)
- El tràfic entre entorns (dev/staging/prod) és bloquejat per construcció

> **Important:** Minikube s'ha d'iniciar amb `--cni=calico`. El CNI kindnet per defecte accepta el YAML de NetworkPolicy però l'ignora silenciosament.

---

## Índex de documentació

| Document | Descripció |
|----------|------------|
| [Arquitectura](week13/ARCHITECTURE.md) | Diagrama complet del sistema, fluxos de dades, model de seguretat |
| [Manual d'operacions](week13/RUNBOOK.md) | Desplegar, escalar, fer rollback, comprovar logs — pas a pas |
| [Resolució de problemes](week13/TROUBLESHOOTING.md) | Errors habituals i com diagnosticar-los |
| [Setmana 8](week8/Documentation.md) | Decisions Docker i explicació dels Dockerfiles |
| [Setmana 9](week9/Documentation.md) | Arquitectura Docker Compose i configuració |
| [Setmana 10](week10/Documentation.md) | Recursos Kubernetes i orquestració |
| [Setmana 11](week11/Documentation.md) | Terraform IaC i pipeline CI/CD |
| [Setmana 12](week12/Documentation.md) | Disseny de xarxa, NetworkPolicies, estratègia d'identitat |
| [Setmana 13](week13/Documentation.md) | Observabilitat, test d'integració, reflexió |

---

## Stack tecnològic

| Categoria | Tecnologia | Propòsit |
|-----------|-----------|---------|
| Contenidors | Docker (multistage, no root, alpine) | Empaquetar aplicacions |
| Orquestració | Kubernetes (Minikube) | Desplegar, escalar, auto-recuperar |
| IaC | Terraform (proveïdor hashicorp/kubernetes) | Infraestructura reproduïble |
| CI/CD | GitHub Actions | Build, escaneig i validació automatitzats |
| Registre | Docker Hub | Emmagatzemar imatges de contenidors |
| Observabilitat | Prometheus + Grafana + prom-client | Recollida de mètriques i dashboards |
| Seguretat de xarxa | Calico + Kubernetes NetworkPolicies | Segmentació zero-trust |
| Base de dades | PostgreSQL 16 (StatefulSet + PVC) | Emmagatzematge relacional persistent |
