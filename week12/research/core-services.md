# Servicios core: DNS, DHCP, NTP

> **Owner:** Persona B
> **Estado:** TODO

Este documento responde a la seccion "Research: Core Services" del PDF (Semana 12).
1-2 parrafos por servicio, escritos para alguien no tecnico.

## DNS (Domain Name System)

> TODO Persona B - cubrir:
> - Que es y que problema resuelve (humanos no recuerdan IPs)
> - Por que una organizacion necesita DNS interno (resolver nombres de servicios
>   internos sin pasar por DNS publico)
> - Como funciona high-level: cliente -> resolver -> root -> TLD -> autoritativo
> - Mencion a registros A, AAAA, CNAME, MX, TXT (sin profundizar)
> - Conexion con la asignatura: en Kubernetes los Services exponen DNS interno
>   automaticamente (p.ej. backend-dev.default.svc.cluster.local)

## DHCP (Dynamic Host Configuration Protocol)

> TODO Persona B - cubrir:
> - Que problema resuelve (asignacion manual de IPs no escala)
> - Como funciona el handshake DORA (Discover/Offer/Request/Ack) brevemente
> - Por que es util en una organizacion: portatiles que se conectan a la VPN,
>   nuevos servidores, dispositivos IoT...
> - Mencion a reservas DHCP (asignar siempre la misma IP a una MAC) para
>   servidores criticos
> - En Kubernetes: las IPs de los pods las gestiona el CNI, no DHCP, pero el
>   concepto sigue vigente para nodos del cluster y oficinas.

## NTP (Network Time Protocol)

> TODO Persona B - cubrir:
> - Que es y para que sirve (sincronizar relojes con precision sub-segundo)
> - Por que la sincronizacion de tiempo es CRITICA en seguridad:
>   - Logs forenses: si los timestamps no cuadran no puedes correlacionar eventos
>   - Certificados TLS: validez basada en tiempo, derivas de minutos rompen TLS
>   - Tokens (Kerberos, JWT): expiran en ventanas pequenas
>   - Auditoria/compliance: muchas normativas exigen UTC sincronizado
> - Como funciona high-level: stratum 0 (relojes atomicos) -> stratum 1
>   (servidores publicos) -> stratum N (clientes)
> - Buena practica: en una organizacion, montar 2-3 servidores NTP internos
>   que sincronicen contra pool.ntp.org y que el resto de la red apunte a ellos.
