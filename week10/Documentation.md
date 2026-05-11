# Setmana 10 — Orquestració (Kubernetes)

## Visió general

Aquesta setmana traslladem la nostra aplicació en contenidors a Kubernetes.
Kubernetes proporciona orquestració, permetent-nos gestionar contenidors a
escala amb recuperació automàtica, actualitzacions progressives i gestió
de recursos.

La infraestructura es divideix en un component frontend (Nginx) i components
backend (servidor Node.js + base de dades Postgres).

## Backend i base de dades

Aquesta secció documenta els manifests de Kubernetes per als serveis Backend
i Base de dades, complint els requisits Bàsics, Intermedis i Avançats.

### 1. Servei Backend

El backend no té estat i es desplega amb un `Deployment`.

- **Deployment (`backend-deployment.yaml`)**:
  - **Rèpliques**: 2 (demonstra escalat bàsic).
  - **Imatge**: `greendevcorp/backend:week9`.
  - **Configuració**: Fa servir un `ConfigMap` (`backend-config`) per injectar
    la variable d'entorn `PORT`. Les credencials de la base de dades
    s'injecten de forma segura via un `Secret`.
  - **Límits de recursos (Intermedi)**: Sol·licita 128Mi RAM / 250m CPU,
    límit de 256Mi RAM / 500m CPU.
  - **Sondes (Intermedi)**: Tant `livenessProbe` com `readinessProbe` estan
    configurades usant `wget` per fer ping a l'endpoint `/health`. Això
    assegura que Kubernetes només enruti tràfic a pods sans i reiniciï
    automàticament els que fallen.

- **Service (`backend-service.yaml`)**:
  - Crea un servei `ClusterIP` per exposar els pods del backend internament
    al port `3000`.

- **ConfigMap (`backend-configmap.yaml`)**:
  - Centralitza els paràmetres de configuració.

### 2. Base de dades Postgres

La base de dades té estat i requereix emmagatzematge persistent, per tant
es desplega amb un `StatefulSet`.

- **StatefulSet (`postgres-statefulset.yaml`)**:
  - **Avançat (\*\*\*)**: Fa servir `volumeClaimTemplates` per provisionar
    automàticament un `PersistentVolumeClaim` (PVC) d'1Gi per a
    `/var/lib/postgresql/data`. Això garanteix que les dades persisteixin
    entre reinicis de pods i re-planificacions.
  - **Imatge**: `postgres:16-alpine`.
  - **Sondes (Intermedi)**: Fa servir `pg_isready` per verificar que la base
    de dades està llesta per acceptar connexions.
  - **Límits de recursos (Intermedi)**: Sol·licita 256Mi RAM / 500m CPU,
    límit de 512Mi RAM / 1000m CPU.

- **Service (`postgres-service.yaml`)**:
  - Crea un servei `ClusterIP` per exposar Postgres al port `5432` per al
    backend.

- **Secret (`postgres-secret.yaml`)**:
  - Emmagatzema les credencials de la base de dades codificades en base64
    (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`).

---

## Frontend

### 1. Servei Nginx

El frontend no té estat i es desplega amb un `Deployment`.

- **Deployment (`nginx-deployment.yaml`)**:
  - **Rèpliques**: 2 (reflex de l'escalat del backend).
  - **Imatge**: `greendevcorp/nginx:week9` — Nginx no root que fa proxy de
    les peticions `/api/` cap al servei backend.
  - **`imagePullPolicy: Never`**: La imatge es construeix i es carrega
    localment a Minikube; això evita que Kubernetes intenti descarregar-la
    de Docker Hub (on la imatge és privada o inexistent).
  - **Port**: `8080` (port no privilegiat, consistent amb la configuració
    no root de la setmana 9).
  - **Límits de recursos (Intermedi)**: Sol·licita 64Mi RAM / 100m CPU,
    límit de 128Mi RAM / 250m CPU.
  - **Sondes (Intermedi)**: Tant `livenessProbe` com `readinessProbe` fan
    servir `httpGet` a l'endpoint `/health` (port 8080). Kubernetes només
    enrutarà tràfic a pods sans i reiniciarà els que fallin.

- **Service (`nginx-service.yaml`)**:
  - Crea un servei `NodePort` que mapeja el port extern `30080` → port
    intern `8080`.
  - Usar `NodePort` (en lloc de `ClusterIP`) exposa el frontend al tràfic
    extern, fent-lo accessible via `minikube ip:30080` durant el
    desenvolupament local.

---

## Arquitectura i comunicació

### Com es comuniquen els pods (descobriment de serveis)

Kubernetes assigna un nom DNS estable a cada Service. Els pods es localitzen
entre ells usant aquests noms — sense necessitat d'IPs codificades:

| Qui crida  | Destí    | Nom DNS usat          |
|------------|----------|-----------------------|
| Nginx      | Backend  | `http://backend:3000` |
| Backend    | Postgres | `postgres:5432`       |

CoreDNS (el servidor DNS del clúster) resol `backend` →
`backend.default.svc.cluster.local` → ClusterIP automàticament. Per això
el `proxy_pass` de nginx i la variable d'entorn `PGHOST=postgres` del
backend funcionen sense cap configuració d'IP.

### Com accedeixen els clients externs al frontend

- El Service `nginx` és de tipus **NodePort**, que obre el port `30080` al
  node Minikube.
- A Linux/macOS: `http://$(minikube ip):30080`
- A Windows (Docker Desktop): la IP del node Minikube no és directament
  enrutable des del host. Usar `kubectl port-forward`:
  ```bash
  kubectl port-forward svc/nginx 8080:80
  # → accessible a http://localhost:8080
  ```
- Backend i Postgres fan servir **ClusterIP** (només intern) — mai
  s'exposen fora del clúster.

### Comportament d'escalat

Quan s'executa `kubectl scale deployment nginx --replicas=3`, Kubernetes:
1. Crea un tercer pod a partir del mateix template.
2. El Service `nginx` equilibra automàticament el tràfic entre els 3 pods
   (round-robin via kube-proxy).
3. No hi ha temps d'inactivitat perquè els pods existents segueixen servint
   mentre el nou s'inicia.
4. La sonda de disponibilitat controla el tràfic: el nou pod només rep
   peticions quan `/health` retorna 200.

Quan un pod s'elimina (`kubectl delete pod -l app=backend`), el controlador
del Deployment detecta la rèplica que falta i programa un reemplaçament
immediatament — demostrant l'auto-recuperació automàtica.

---

## Com executar i verificar

### Prerequisits — carregar imatges a Minikube

Les imatges personalitzades no estan en un registre públic, per tant s'han
de construir localment i carregar al daemon Docker de Minikube:

```bash
# Construir (si no s'ha fet ja)
docker build -t greendevcorp/nginx:week9 week9/nginx/
docker build -t greendevcorp/backend:week9 week9/backend/

# Carregar a Minikube
minikube image load greendevcorp/nginx:week9
minikube image load greendevcorp/backend:week9
```

### Desplegar

1. Iniciar Minikube:
   ```bash
   minikube start
   ```

2. Aplicar els manifests:
   ```bash
   kubectl apply -f kubernetes/
   ```

3. Comprovar l'estat dels pods, serveis i PVCs:
   ```bash
   kubectl get pods
   kubectl get services
   kubectl get pvc
   ```

4. Accedir al frontend (Windows):
   ```bash
   kubectl port-forward svc/nginx 8080:80
   # Obrir http://localhost:8080
   ```

5. Provar l'escalat:
   ```bash
   kubectl scale deployment backend --replicas=3
   kubectl get pods --watch   # observar el nou pod aparèixer
   kubectl scale deployment backend --replicas=2
   ```

6. Provar la resiliència:
   ```bash
   kubectl delete pod -l app=backend
   kubectl get pods --watch   # observar el reinici automàtic
   ```
