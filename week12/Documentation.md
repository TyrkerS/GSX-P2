# Week 12: Network Design & Identity

> **Estado:** Persona A completada. Persona B pendiente (secciones 4 y 5).
>
> Persona A: implementacion (red + NetworkPolicies). Persona B: investigacion (servicios core + identidad).

## 1. Arquitectura de red

Ver `diagrams/network-architecture.md` para el diagrama completo (Mermaid)
y la tabla de flujos permitidos / prohibidos.

**Modelo de segmentacion en una frase:** una DMZ con un unico Nginx
expuesto a internet enruta hacia tres entornos aislados (dev/staging/prod),
cada uno con su backend y su postgres dedicados. Partners externos viven
en su propia subred y solo acceden a endpoints publicos via DMZ. Ningun
entorno puede iniciar trafico hacia otro y nadie puede saltarse el Nginx
para llegar a un backend.

## 2. Plan de direccionamiento (CIDR)

Ver `diagrams/cidr-plan.md`.

**Resumen del rationale:**
- Bloque global `10.0.0.0/16` (RFC 1918) suficiente para toda
  GreenDevCorp.
- `/24` por entorno: 254 hosts cubre con margen el catalogo actual y el
  tercer octeto identifica el entorno de un vistazo (`10.0.1.X` = dev,
  `10.0.2.X` = staging, `10.0.3.X` = prod).
- Subnets separadas por entorno = capa de defensa adicional sobre las
  NetworkPolicies (segmentacion L3 + L7).
- Partners en `10.0.10.0/24` aislados; rangos de monitoring y crecimiento
  reservados.

## 3. NetworkPolicies en Kubernetes

**Estrategia: zero-trust / default-deny + allowlist explicita.**
Bloquear todo por defecto y abrir solo los flujos que el negocio
necesita. Esta es la postura recomendada por la documentacion oficial de
Kubernetes y por NIST SP 800-207 (zero trust architecture).

**Policies implementadas (en `network-policies/`):**

| Fichero                          | Que hace                                                       |
|----------------------------------|----------------------------------------------------------------|
| `00-default-deny.yaml`           | Niega todo ingress y egress en el namespace `default`.         |
| `05-allow-dns.yaml`              | Excepcion minima: cualquier pod puede hablar con kube-dns:53.  |
| `10-allow-frontend-backend.yaml` | nginx-dev <-> backend-dev (ingress + egress, TCP 3000).        |
| `20-allow-backend-postgres.yaml` | backend-dev <-> postgres-dev (ingress + egress, TCP 5432).     |
| `templates-staging-prod.yaml`    | Mismo patron para staging y prod (plantillas listas).          |
| `30-deny-cross-env.yaml`         | Decision documentada: aislamiento cross-env por construccion.  |

**Por que dos policies por flujo (ingress + egress).** Bajo default-deny,
los paquetes pueden salir del origen pero ser bloqueados al llegar al
destino, o llegar y no poder volver. Cada flujo necesita policy en
ambos extremos. Si solo abres uno, los `kubectl exec ... wget`
timeoutean y suele costar un buen rato debuggear.

**Como se ha probado.** Los tests viven en `verify-week12.ps1`. Resumen
de los cinco casos:

```powershell
# 1. Antes de aplicar policies: nginx-dev -> backend-dev funciona
kubectl exec <nginx-pod> -- wget -qO- --timeout=5 http://backend:3000/health
# Esperado: 200 OK

# 2. Aplicar default-deny: el mismo comando ahora falla
kubectl apply -f network-policies/00-default-deny.yaml
kubectl exec <nginx-pod> -- wget -qO- --timeout=5 http://backend:3000/health
# Esperado: timeout

# 3. Aplicar todas las policies: dev funciona de nuevo
kubectl apply -f network-policies/
kubectl exec <nginx-pod> -- wget -qO- --timeout=5 http://backend:3000/health
# Esperado: 200 OK

# 4. Test cross-pod no autorizado: pod sin labels -> backend
kubectl run tester --rm -it --image=busybox --restart=Never -- \
    wget -qO- --timeout=5 http://backend:3000/
# Esperado: timeout (no hay policy que lo permita)

# 5. Test acceso directo a DB sin pasar por backend: nginx -> postgres
kubectl exec <nginx-pod> -- nc -zv -w 5 postgres 5432
# Esperado: timeout (nginx no tiene allow a postgres)
```

**Cambio de CNI a Calico (critico para Minikube).** Por defecto Minikube
usa el CNI `kindnet`, que **NO aplica NetworkPolicies** (las acepta y las
silencia). Si arrancas el cluster con kindnet, todas las policies se
crean correctamente pero el trafico sigue fluyendo libre — lo cual es
mas peligroso que no tener policies, porque da una falsa sensacion de
seguridad. Para que tengan efecto:

```powershell
minikube delete
minikube start --cni=calico
```

Verificar despues que Calico esta corriendo:
```powershell
kubectl get pods -n kube-system | Select-String calico
```

## 4. Servicios core (DNS / DHCP / NTP)

> TODO Persona B: integrar resumen aqui.

Ver `research/core-services.md`.

## 5. Identity Management

> TODO Persona B: integrar resumen + recomendacion final aqui.

Ver `research/identity.md`.

## 6. Analisis de seguridad

### Trafico permitido y por que

| Flujo                       | Por que se permite                                                |
|-----------------------------|-------------------------------------------------------------------|
| Internet -> Nginx (443)     | Producto publico; Nginx termina TLS y enruta.                     |
| Partners -> Nginx (443)     | Integraciones externas via API publica.                           |
| Nginx -> backend-X (3000)   | Reverse proxy normal; Nginx es el unico punto de entrada al app.  |
| backend-X -> postgres-X     | Cada app accede solo a SU base de datos del mismo entorno.        |
| Pod -> kube-dns (53)        | Sin DNS no se resuelven hostnames; obligatorio para la app.       |

### Trafico bloqueado y por que

| Flujo bloqueado                  | Riesgo que mitiga                                              |
|----------------------------------|----------------------------------------------------------------|
| Cualquiera -> backend sin labels | Movimiento lateral desde un pod comprometido.                  |
| Nginx -> postgres-X              | Defensa en profundidad: si Nginx cae no hay acceso directo DB. |
| backend-X -> postgres-Y (X!=Y)   | Aislamiento entre entornos; un bug en dev no toca prod.        |
| dev <-> staging <-> prod         | Compromiso de un entorno no escala al siguiente.               |
| Partners -> backends             | Los partners solo ven la API publica, no la red interna.       |
| Backends -> internet (egress)    | Reduce superficie de exfiltracion y de C2 callbacks.           |

### Como prevenir misconfiguraciones

- **Default-deny como base.** Si alguien olvida una policy, el efecto es
  que algo se rompe (visible) en lugar de que algo quede abierto
  (invisible). Fail-closed > fail-open.
- **Labels como contrato.** Toda policy selecciona por `app=` y
  `environment=`. Un pod sin esos labels no recibe ningun allow y por
  default-deny queda aislado. En produccion real anadiriamos un
  admission controller (Kyverno / OPA Gatekeeper) que rechace pods sin
  estos labels.
- **CNI con soporte real.** Verificado que Minikube corre con Calico (no
  kindnet). En el cluster real seria una check de provisioning.
- **Revisiones de pares.** Todo cambio en `network-policies/` se revisa
  por la otra persona del equipo antes de mergear, como cualquier otro
  codigo.
- **Tests automatizables.** `verify-week12.ps1` ejecuta los cinco
  escenarios; la idea es portarlo a CI cuando tengamos un cluster
  efimero por PR.

## 7. Lo que el equipo ha aprendido

> TODO conjunto al cerrar la semana:
> - Decisiones clave y trade-offs
> - Limitaciones del setup actual
> - Que se haria distinto si tuvieramos mas tiempo
