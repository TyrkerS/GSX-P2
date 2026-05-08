# Plan de direccionamiento (CIDR)

> **Owner:** Persona A
> **Estado:** Implementado

## Bloque global

`10.0.0.0/16` (65.534 hosts utiles) - reservado para toda la organizacion
GreenDevCorp. Espacio privado segun RFC 1918, no enrutable en internet.

## Subdivision

| Subnet         | Rango usable                | Hosts | Gateway      | DNS         | Proposito                              |
|----------------|-----------------------------|-------|--------------|-------------|----------------------------------------|
| 10.0.0.0/24    | 10.0.0.1 - 10.0.0.254       | 254   | 10.0.0.1     | 10.0.100.2  | Infra compartida (kube-system, ingress)|
| 10.0.1.0/24    | 10.0.1.1 - 10.0.1.254       | 254   | 10.0.1.1     | 10.0.100.2  | Entorno dev                            |
| 10.0.2.0/24    | 10.0.2.1 - 10.0.2.254       | 254   | 10.0.2.1     | 10.0.100.2  | Entorno staging                        |
| 10.0.3.0/24    | 10.0.3.1 - 10.0.3.254       | 254   | 10.0.3.1     | 10.0.100.2  | Entorno prod                           |
| 10.0.10.0/24   | 10.0.10.1 - 10.0.10.254     | 254   | 10.0.10.1    | 10.0.100.2  | Acceso de partners externos (VPN)      |
| 10.0.100.0/24  | 10.0.100.1 - 10.0.100.254   | 254   | 10.0.100.1   | -           | Servicios compartidos (DNS, NTP, LDAP) |
| 10.0.200.0/24  | reservado                   | 254   | -            | -           | Monitoring (Prometheus, Grafana)       |
| 10.0.4.0/22    | reservado (4.0 - 7.255)     | 1022  | -            | -           | Crecimiento futuro (nuevos entornos)   |

**Convenciones aplicadas en cada /24:**
- `.1`  -> gateway (router/firewall del segmento).
- `.2`  -> resolver DNS local del segmento (forwarder hacia 10.0.100.2).
- `.10 - .49`  -> servicios estaticos (LB, ingress, balanceadores).
- `.50 - .200` -> rango DHCP para pods/VMs autoescaladas.
- `.201 - .254`-> reserva manual (deploys especiales, debugging).

## Razonamiento

### Por que /24 por entorno
- 254 hosts utiles cubre el catalogo actual (nginx, backend con replicas,
  postgres, sidecars de monitoring) varias veces y deja margen para
  autoescalado horizontal.
- Es el tamano mas legible: el tercer octeto identifica el entorno
  (`.1.X` = dev, `.2.X` = staging, `.3.X` = prod) lo que facilita auditar
  capturas de trafico y firewall logs a simple vista.
- Cambiar a /23 o /22 solo se justifica si un entorno supera ~150 pods
  estables; en ese punto el coste de reasignar es bajo.

### Por que separar dev / staging / prod en subnets distintas
- **Defensa en capas.** Las NetworkPolicies de Kubernetes (capa 7 logica
  por labels) son una barrera; routing y firewall a nivel de red (capa 3
  por subnet) son una barrera independiente. Si una de las dos se
  configura mal, la otra sigue conteniendo el incidente.
- **Auditoria mas simple.** Filtrar logs `src=10.0.1.0/24 dst=10.0.3.0/24`
  detecta cualquier intento dev -> prod sin tener que correlacionar labels
  contra deployments.
- **Compliance.** Cumple con principios de segmentacion exigidos por casi
  cualquier framework (ISO 27001 A.13.1, PCI-DSS req. 1.3, NIS2): un
  entorno comprometido no permite acceso lateral al siguiente.

### Por que partners en su propia subnet
- **Least privilege.** Partners necesitan acceso solo a endpoints publicos
  (via DMZ/Nginx); no deben siquiera ver el espacio interno.
- **Trazabilidad.** Cualquier conexion saliente desde 10.0.10.0/24 que
  intente alcanzar 10.0.X.0/24 (X != 10) es alerta inmediata sin tener
  que inspeccionar payload.
- **Revocacion granular.** Si hay que cortar a un partner, basta con
  eliminar su /28 dentro de 10.0.10.0/24, sin tocar produccion.

### Reservas y crecimiento
- `10.0.0.0/24` queda fuera de los entornos: es para infra que sirve a
  todos (ingress controllers, cert-manager, registry interno).
- `10.0.200.0/24` reservado para monitoring para que las dependencias
  sean unidireccionales (todos -> monitoring, nunca al reves).
- `10.0.4.0/22` (1022 hosts) reservado intacto para futuras unidades de
  negocio, oficinas o un cuarto entorno (p.ej. `qa` o `staging-eu`) sin
  tener que renumerar nada.
- Quedan ~57.000 IPs libres en el /16 para multi-region o adquisiciones.
