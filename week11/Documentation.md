# Week 11: Infrastructure as Code & CI/CD

Esta documentación detalla la implementación de la Infraestructura como Código (IaC) para el stack completo (**Nginx, Backend y PostgreSQL**) utilizando Terraform, así como la configuración del pipeline CI/CD en GitHub Actions.

## 1. IaC: Elección de Herramienta y Arquitectura

### Selección de Herramienta: Terraform
Se ha elegido **Terraform** por su enfoque declarativo, que permite mantener un control estricto sobre el estado de la infraestructura. A diferencia de Ansible (que es más procedimental), Terraform es ideal para orquestar recursos de Kubernetes asegurando que el estado actual coincida siempre con el estado deseado.

### Arquitectura en Terraform
Los archivos de Terraform se encuentran en el directorio `terraform/` y están organizados de la siguiente forma:

- **`main.tf`**: Contiene la definición de todos los recursos de Kubernetes:
  - `kubernetes_deployment.nginx`: Orquesta los Pods del servidor Nginx (proxy/frontend).
  - `kubernetes_service.nginx`: Expone Nginx al exterior mediante NodePort (puerto 30080).
  - `kubernetes_deployment.backend`: Orquesta los Pods del backend Node.js.
  - `kubernetes_service.backend`: Expone internamente el backend (ClusterIP).
  - `kubernetes_stateful_set.postgres`: Maneja la base de datos PostgreSQL con identidad persistente y PVC.
  - `kubernetes_service.postgres`: Expone internamente PostgreSQL (ClusterIP).
  - `kubernetes_config_map` y `kubernetes_secret`: Proveen configuración y secretos inyectados como variables de entorno.
- **`variables.tf`**: Permite flexibilidad de despliegue. Variables clave: `environment` (dev/staging), `nginx_replicas`, `backend_replicas`, `nginx_image`, `backend_image`.
- **`outputs.tf`**: Muestra los nombres de los servicios desplegados tras el apply.

## 2. Flujo de despliegue local (CD)
El objetivo de Terraform es sustituir la aplicación manual de archivos YAML en Kubernetes.

**Pasos para desplegar en local (Minikube):**
1. Asegúrate de tener Minikube corriendo y Terraform instalado.
2. Posiciónate en `terraform/`.
3. Inicializa Terraform:
   ```bash
   terraform init
   ```
4. Comprueba lo que se va a crear:
   ```bash
   terraform plan -var="environment=dev"
   ```
5. Aplica los cambios:
   ```bash
   terraform apply -var="environment=dev"
   ```

## 3. CI/CD: Pipeline con GitHub Actions

La validación y empaquetamiento de las imágenes se hace de forma automática usando **GitHub Actions**. El pipeline se encuentra en `.github/workflows/ci-backend.yml`.

### Flujo del Pipeline (CI)
1. **Trigger:** El flujo se dispara con eventos tipo `push` a la rama `main`.
2. **Build and Push (`build-and-push-backend`):**
   - Hace un checkout del código.
   - Inicia sesión en Docker Hub usando secretos de GitHub (`DOCKER_USERNAME` y `DOCKER_PASSWORD`).
   - Usa `docker/metadata-action` para generar automáticamente los tags correctos para la imagen basados en el commit y las etiquetas de la rama.
   - Construye la imagen utilizando el `Dockerfile` que se encuentra en `week8/application` y la sube al registro.
3. **Validación de IaC (`validate-terraform`):**
   - Configura el entorno de Terraform dentro de GitHub Actions.
   - Ejecuta `terraform fmt -check` para asegurar que el código cumple con las convenciones de formateo.
   - Ejecuta `terraform init -backend=false` y `terraform validate` para comprobar si la sintaxis y los tipos del código Terraform son correctos.

### Múltiples Entornos (Intermediate)
Para cumplir con el reto intermedio, se configuraron variables (`var.environment`) en `variables.tf`. El uso de estas variables permite desplegar entornos de `dev` y `staging` de forma separada utilizando la misma base de código. Por ejemplo, en CI/CD se puede modificar para que la rama `staging` use `-var="environment=staging"`, diferenciando claramente los nombres de los servicios y Pods en Kubernetes.

## 4. Flujo End-to-End: CI + CD local a Minikube

Este es el flujo completo desde un cambio de código hasta el despliegue actualizado en Minikube.

### Paso 1: Hacer un cambio y hacer push
```bash
# Ejemplo: modificar la aplicacion en week8/application
git add .
git commit -m "Update backend application"
git push origin main
```

### Paso 2: CI corre automaticamente en GitHub Actions
El pipeline (`.github/workflows/ci-backend.yml`) se dispara y ejecuta dos jobs en paralelo:

1. **`build-and-push-backend`**: construye la imagen Docker del backend y la sube a Docker Hub con dos tags:
   - `<DOCKER_USERNAME>/backend:main` (rama)
   - `<DOCKER_USERNAME>/backend:sha-<commit-SHA>` (identificador unico del commit)

2. **`validate-terraform`**: verifica que el codigo Terraform esta bien formateado y es valido sintacticamente.

### Paso 3: Obtener el tag de la imagen generada por CI
Una vez que el pipeline es verde, obtener el commit SHA del push:
```bash
git rev-parse --short HEAD
# Ejemplo de salida: a1b2c3d
```
El tag de la imagen sera: `<DOCKER_USERNAME>/backend:sha-a1b2c3d`

### Paso 4: Desplegar en Minikube con el nuevo tag
```bash
cd week11/terraform

# Inicializar (solo la primera vez)
terraform init

# Desplegar con el nuevo tag de imagen producido por CI
terraform apply \
  -var="environment=dev" \
  -var="backend_image=<DOCKER_USERNAME>/backend:sha-a1b2c3d"
```

### Paso 5: Verificar que el stack esta actualizado
```bash
# Ver que todos los pods estan corriendo
kubectl get pods

# Verificar la imagen que esta usando el pod del backend
kubectl describe pod -l app=backend | grep Image

# Ver los outputs de Terraform (nombres de servicios)
terraform output

# Acceder a Nginx desde fuera del cluster
minikube service nginx-dev
```

### Resumen del flujo
```
git push
    --> GitHub Actions (CI)
            --> build imagen backend --> push a Docker Hub con SHA tag
            --> terraform validate (sin tocar Minikube)
    --> [CI verde]
    --> terraform apply -var="backend_image=...:<SHA>" (local)
            --> Kubernetes actualiza los Pods del backend con la nueva imagen
            --> Nginx y PostgreSQL siguen corriendo sin interrupcion
```
