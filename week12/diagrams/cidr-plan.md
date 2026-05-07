# Plan de direccionamiento (CIDR)

> **Owner:** Persona A
> **Estado:** TODO

## Bloque global

`10.0.0.0/16` (65.534 hosts utiles) - reservado para toda la organizacion.

## Subdivision

| Subnet         | Rango usable                | Hosts | Proposito                           |
|----------------|-----------------------------|-------|-------------------------------------|
| 10.0.1.0/24    | 10.0.1.1 - 10.0.1.254       | 254   | Entorno dev                         |
| 10.0.2.0/24    | 10.0.2.1 - 10.0.2.254       | 254   | Entorno staging                     |
| 10.0.3.0/24    | 10.0.3.1 - 10.0.3.254       | 254   | Entorno prod                        |
| 10.0.10.0/24   | 10.0.10.1 - 10.0.10.254     | 254   | Acceso de partners externos         |
| 10.0.100.0/24  | 10.0.100.1 - 10.0.100.254   | 254   | Servicios compartidos (DNS, NTP...) |

> TODO Persona A:
> - Confirmar la tabla, cambiarla si tiene sentido para nuestro escenario
> - Indicar que DHCP/gateways se usarian (.1 reservado para gateway, .2 para DNS, etc.)
> - Reservar rango para crecimiento futuro

## Razonamiento

### Por que /24 por entorno
> TODO: explicar el calculo. /24 = 254 hosts utiles. Para 20+ personas y unos
> cuantos servicios por entorno sobra de momento, y deja espacio para
> autoescalado o multi-replicas sin cambiar el plan.

### Por que separar dev / staging / prod en subnets distintas
> TODO: relacionarlo con segmentacion de seguridad. Si todos viviesen en la
> misma /24 las NetworkPolicies se basarian solo en labels; con subnets
> distintas tienes una capa de defensa mas (firewall a nivel de red).

### Por que partners en su propia subnet
> TODO: principio de least privilege. Los partners necesitan acceso solo a
> ciertos endpoints publicos, no a toda la red corporativa.

### Reservas y crecimiento
> TODO: dejar al menos `10.0.0.0/24` libre para infraestructura compartida
> (kube-system, monitoring, ingress) y rangos vacios para futuras unidades de
> negocio o oficinas.
