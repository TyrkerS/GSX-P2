# Manual d'operacions — Infraestructura GreenDevCorp

## Prerequisits

| Eina          | Versió | Instal·lació |
|---------------|--------|--------------|
| Docker Desktop| 4.x+   | https://docs.docker.com/desktop/ |
| kubectl       | 1.28+  | inclòs amb Minikube |
| Minikube      | 1.32+  | https://minikube.sigs.k8s.io/ |
| Terraform     | 1.6+   | https://www.terraform.io/downloads |
| Git           | 2.x+   | https://git-scm.com/ |

---

## 1. Iniciar el stack Docker Compose (desenvolupament)

```bash
cd week9/

# Primera vegada: copiar la plantilla de variables
cp .env.example .env
# Editar .env i establir POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, GRAFANA_PASSWORD

# Iniciar tots els serveis (nginx, backend, postgres, prometheus, grafana, node-exporter)
docker-compose up -d

# Verificar que tots els serveis estan sans
docker-compose ps

# Veure logs de tots els serveis
docker-compose logs -f

# Veure logs d'un servei específic
docker-compose logs -f backend
```

**Punts d'accés:**
- Aplicació: http://localhost:80
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001 (usuari: admin, contrasenya: des de .env)

```bash
# Aturar el stack
docker-compose down

# Aturar i eliminar volums (destrueix les dades de la base de dades!)
docker-compose down -v
```

---

## 2. Iniciar Minikube i desplegar via Terraform

```bash
# Iniciar Minikube amb Calico CNI (necessari per a les NetworkPolicies)
minikube start --cni=calico

# Verificar que el clúster funciona
kubectl cluster-info
kubectl get nodes

# Primera vegada: crear dev.tfvars
cd week11/terraform/
cp example.tfvars dev.tfvars
# Editar dev.tfvars i establir postgres_user, postgres_password, postgres_db

# Previsualitzar el que crearà Terraform
terraform init
terraform plan -var-file=dev.tfvars

# Desplegar tot
terraform apply -var-file=dev.tfvars

# Verificar que els pods estan en funcionament
kubectl get pods
kubectl get services
```

---

## 3. Desplegar una nova versió de l'aplicació

```bash
# 1. Fer canvis al codi i fer push a GitHub
git add .
git commit -m "feat: descriure el canvi"
git push origin main

# 2. Esperar que el CI estigui en verd (comprovar la pestanya GitHub Actions)
#    El CI construirà la imatge i la pujarà amb el tag: <DOCKER_USERNAME>/backend:sha-<commit>

# 3. Obtenir el commit SHA
git rev-parse --short HEAD
# Exemple de sortida: a1b2c3d

# 4. Desplegar la nova imatge a Minikube
cd week11/terraform/
terraform apply \
  -var-file=dev.tfvars \
  -var="backend_image=<DOCKER_USERNAME>/backend:sha-a1b2c3d"

# 5. Monitoritzar l'actualització progressiva
kubectl rollout status deployment/backend-dev
kubectl get pods -w
```

---

## 4. Escalar un servei

```bash
# Escalar el backend a 4 rèpliques via Terraform (recomanat — manté l'estat sincronitzat)
cd week11/terraform/
terraform apply -var-file=dev.tfvars -var="backend_replicas=4"

# O escalar directament amb kubectl (temporal, es sobreescriurà al proper terraform apply)
kubectl scale deployment backend-dev --replicas=4

# Observar com apareixen els pods
kubectl get pods --watch

# Tornar a l'escala original
kubectl scale deployment backend-dev --replicas=2
```

---

## 5. Fer rollback a una versió anterior

```bash
# Opció A — Rollback natiu de Kubernetes (el més ràpid)
kubectl rollout undo deployment/backend-dev
kubectl rollout status deployment/backend-dev

# Comprovar l'historial de rollouts
kubectl rollout history deployment/backend-dev

# Rollback a una revisió específica
kubectl rollout undo deployment/backend-dev --to-revision=2

# Opció B — Rollback via Terraform (manté l'estat IaC consistent)
terraform apply \
  -var-file=dev.tfvars \
  -var="backend_image=<DOCKER_USERNAME>/backend:sha-<sha-anterior>"
```

---

## 6. Comprovar logs

```bash
# Logs de Kubernetes
kubectl get pods
kubectl logs <nom-del-pod>
kubectl logs <nom-del-pod> --previous   # logs del contenidor que ha fallat
kubectl logs -l app=backend --all-containers   # tots els pods del backend

# Logs de Docker Compose
docker-compose logs -f backend
docker-compose logs -f --tail=100 nginx
```

---

## 7. Aplicar NetworkPolicies de Kubernetes

```bash
# Assegurar-se que Minikube funciona amb Calico
kubectl get pods -n kube-system | grep calico

# Aplicar totes les polítiques de xarxa
kubectl apply -f week12/network-policies/

# Verificar que les polítiques s'han creat
kubectl get networkpolicies

# Provar que el default-deny funciona (hauria de fer timeout)
kubectl run tester --rm -it --image=busybox --restart=Never -- \
    wget -qO- --timeout=5 http://backend-dev:3000/

# Provar que el tràfic autoritzat funciona (des del pod nginx)
NGINX_POD=$(kubectl get pod -l app=nginx -o jsonpath='{.items[0].metadata.name}')
kubectl exec $NGINX_POD -- wget -qO- --timeout=5 http://backend-dev:3000/health
```

---

## 8. Accedir al dashboard d'observabilitat

```bash
# Grafana disponible a Docker Compose a http://localhost:3001
# Credencials per defecte: admin / (valor de GRAFANA_PASSWORD a .env)

# A Kubernetes, usar port-forward
kubectl port-forward svc/grafana 3001:3000 &
# Obrir http://localhost:3001
```

---

## 9. Destruir l'entorn Kubernetes

```bash
cd week11/terraform/
terraform destroy -var-file=dev.tfvars
```

---

## 10. Executar el test d'integració complet

```powershell
# Des de week11/
.\verify-e2e.ps1

# Saltar el pas de destroy (només apply + verificació)
.\verify-e2e.ps1 -SkipDestroy
```
