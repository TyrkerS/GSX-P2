# Guia de resolució de problemes — Infraestructura GreenDevCorp

## Problemes amb Docker Compose

### `docker-compose up` falla immediatament

```bash
# Comprovar si Docker Desktop està en funcionament
docker info

# Comprovar si hi ha conflictes de ports (80, 3001, 9090 han d'estar lliures)
# Windows:
netstat -ano | findstr ":80"
# Linux/Mac:
lsof -i :80

# Comprovar que el fitxer .env existeix amb els valors correctes
cat week9/.env
```

### Un servei es queda en estat "unhealthy"

```bash
# Inspeccionar la sortida del healthcheck
docker inspect greendevcorp-backend | grep -A 10 Health

# Veure els logs del servei per a errors
docker-compose logs backend

# Causes habituals:
# - El backend no pot connectar-se a postgres (comprovar les variables POSTGRES_*)
# - Postgres tarda massa a iniciar-se (depends_on amb service_healthy ho gestiona)
# - Port ja en ús
```

### Error "variable POSTGRES_USER no establerta"

```bash
# El fitxer .env no existeix — crear-lo des de la plantilla
cp week9/.env.example week9/.env
# Editar .env i establir els valors reals
```

---

## Problemes amb Kubernetes / Minikube

### Pods encallats en `Pending`

```bash
# Comprovar els events del pod
kubectl describe pod <nom-del-pod>

# Causes habituals:
# 1. Recursos insuficients — comprovar les sol·licituds de recursos vs disponibles
kubectl describe nodes

# 2. ImagePullBackOff — imatge no trobada a Docker Hub
kubectl get pod <nom-del-pod> -o yaml | grep image

# 3. PVC no vinculat (per a postgres)
kubectl get pvc
kubectl describe pvc postgres-data-postgres-dev-0
```

### Pods encallats en `CrashLoopBackOff`

```bash
# Comprovar els logs del crash (contenidor actual i anterior)
kubectl logs <nom-del-pod>
kubectl logs <nom-del-pod> --previous

# Causes habituals per al backend:
# - Variable d'entorn mancant (PGHOST, PGPASSWORD)
# - Tag d'imatge incorrecte (comprovar les variables de terraform)

# Causes habituals per a postgres:
# - Corrupció del directori de dades — eliminar el PVC per reiniciar
kubectl delete pvc postgres-data-postgres-dev-0
```

### `ImagePullBackOff`

```bash
# Comprovar la imatge exacta que s'utilitza
kubectl describe pod <nom-del-pod> | grep Image

# Verificar que la imatge existeix a Docker Hub
docker pull <imatge>:<tag>

# Si es fa servir un registre privat, comprovar imagePullSecrets
# Per a week11/terraform, les imatges han de ser públiques a Docker Hub
```

### El servei X no pot arribar al servei Y

```bash
# 1. Comprovar si les NetworkPolicies bloquegen el tràfic
kubectl get networkpolicies

# 2. Verificar que els pods tenen les labels correctes
kubectl get pods --show-labels

# 3. Provar la connectivitat des d'un pod
kubectl exec -it <nginx-pod> -- wget -qO- --timeout=5 http://backend-dev:3000/health

# 4. Comprovar si Minikube fa servir Calico (necessari per a NetworkPolicies)
kubectl get pods -n kube-system | grep calico
# Si no hi ha pods de calico: minikube delete && minikube start --cni=calico

# 5. Comprovar que el selector del service coincideix amb les labels dels pods
kubectl describe service backend-dev
kubectl get pods -l app=backend,environment=dev
```

### `minikube service nginx-dev` no s'obre

```bash
# A Windows amb el driver Docker, fer servir port-forward en lloc d'això
kubectl port-forward svc/nginx-dev 8080:80

# Obrir http://localhost:8080 al navegador
```

### `terraform apply` falla

```bash
# Comprovar el missatge d'error específic
terraform apply -var-file=dev.tfvars 2>&1

# Habitual: "cannot re-use a name that is still in use" — el recurs ja existeix
# Solució: importar el recurs existent o eliminar-lo manualment
kubectl delete deployment nginx-dev
terraform apply -var-file=dev.tfvars

# Habitual: connexió refusada a l'API de Kubernetes
# Solució: assegurar-se que Minikube està en funcionament
minikube status
minikube start

# Habitual: variable "postgres_user" no establerta
# Solució: dev.tfvars no existeix o li falten valors
cat week11/terraform/dev.tfvars
```

---

## Problemes amb CI/CD

### El build de GitHub Actions falla — error de push a Docker Hub

```bash
# Verificar que els secrets estan configurats als paràmetres del repositori de GitHub:
# Settings → Secrets and variables → Actions
# Necessaris: DOCKER_USERNAME, DOCKER_PASSWORD
```

### L'escaneig de Trivy falla per vulnerabilitats trobades

```bash
# El build falla intencionadament en CVEs CRITICAL/HIGH
# Opcions:
# 1. Actualitzar la imatge base al Dockerfile (FROM node:20-alpine → darrera versió)
# 2. Comprovar l'informe de Trivy per als CVEs específics
# 3. L'opció --ignore-unfixed ja està configurada — només falla en vulns corregibles
```

### `terraform validate` falla al CI

```bash
# Reproduir localment:
cd week11/terraform/
terraform fmt -check    # corregir amb: terraform fmt
terraform init -backend=false
terraform validate

# Habitual: problema de format — executar `terraform fmt` i commitar el resultat
```

---

## Problemes d'observabilitat

### Grafana mostra "No data" als panels

```bash
# 1. Verificar que Prometheus scraping el backend
# Obrir http://localhost:9090/targets al navegador
# El job "backend" ha de mostrar "UP"

# 2. Generar tràfic per crear mètriques
curl http://localhost/
curl http://localhost/health

# 3. Comprovar la consulta Prometheus a Grafana
# Clicar en un panel → Edit → comprovar la consulta PromQL
# Executar la mateixa consulta a http://localhost:9090/graph

# 4. Comprovar que el backend exposa /metrics
curl http://localhost:3000/metrics   # des de dins de la xarxa docker
docker exec greendevcorp-backend wget -qO- http://localhost:3000/metrics
```

### Prometheus mostra el target del backend com a "DOWN"

```bash
# Verificar que el contenidor del backend està sa
docker-compose ps

# Comprovar la configuració de Prometheus
cat week9/monitoring/prometheus/prometheus.yml

# El hostname del backend a prometheus.yml ha de coincidir amb el nom del servei a docker-compose.yml
# prometheus.yml: targets: ['backend:3000']
# docker-compose.yml: nom del servei: backend ✓
```

### node-exporter no té dades (Windows)

```bash
# A Windows Docker Desktop, node-exporter exporta mètriques de la VM Linux,
# no del host Windows. Aquest és el comportament esperat.
# Les mètriques de la VM (CPU, memòria, disc) segueixen sent visibles i significatives.
```
