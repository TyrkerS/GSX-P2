# Week 11: Backend Infrastructure as Code & CI/CD

Esta documentación detalla la implementación de la Infraestructura como Código (IaC) para el componente **Backend y Base de Datos (PostgreSQL)** utilizando Terraform, así como la configuración del pipeline CI/CD en GitHub Actions.

## 1. IaC: Elección de Herramienta y Arquitectura

### Selección de Herramienta: Terraform
Se ha elegido **Terraform** por su enfoque declarativo, que permite mantener un control estricto sobre el estado de la infraestructura. A diferencia de Ansible (que es más procedimental), Terraform es ideal para orquestar recursos de Kubernetes asegurando que el estado actual coincida siempre con el estado deseado.

### Arquitectura en Terraform
Los archivos de Terraform se encuentran en el directorio `terraform/` y están organizados de la siguiente forma:

- **`main.tf`**: Contiene la definición de los recursos de Kubernetes:
  - `kubernetes_deployment.backend`: Orquesta los Pods del backend Node.js.
  - `kubernetes_stateful_set.postgres`: Maneja la base de datos PostgreSQL, asegurando la identidad persistente de sus Pods y los volúmenes (PVC).
  - `kubernetes_service`: Expone internamente el backend y la base de datos.
  - `kubernetes_config_map` y `kubernetes_secret`: Proveen de configuración y secretos al backend y base de datos respectivamente, inyectándolos como variables de entorno.
- **`variables.tf`**: Permite la flexibilidad de despliegue para diferentes entornos. Contiene variables como `environment` (dev/staging), `backend_replicas`, e imágenes a usar.
- **`outputs.tf`**: Muestra información crítica una vez finalizado el despliegue (ej. los nombres de los servicios).

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
