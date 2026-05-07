# Week 12: Network Design & Identity

> **Estado:** EN PROGRESO. Esta documentacion integra el trabajo de las dos personas del equipo.
> Persona A: implementacion (red + NetworkPolicies). Persona B: investigacion (servicios core + identidad).

## 1. Arquitectura de red
> TODO Persona A: enlazar al diagrama y resumir en un parrafo el modelo de segmentacion.

Ver `diagrams/network-architecture.md` para el diagrama completo.

## 2. Plan de direccionamiento (CIDR)
> TODO Persona A: enlazar y resumir el rationale de la subdivision.

Ver `diagrams/cidr-plan.md`.

## 3. NetworkPolicies en Kubernetes
> TODO Persona A:
> - Listar los policies implementadas en `network-policies/`
> - Explicar la estrategia (default-deny + permitir explicitamente)
> - Documentar como se han probado (commands `kubectl exec` + curl/nc)
> - Anotar el cambio de CNI a Calico para que las policies tengan efecto en Minikube

## 4. Servicios core (DNS / DHCP / NTP)
> TODO Persona B: integrar resumen aqui.

Ver `research/core-services.md`.

## 5. Identity Management
> TODO Persona B: integrar resumen + recomendacion final aqui.

Ver `research/identity.md`.

## 6. Analisis de seguridad
> TODO Persona A:
> - Que trafico se permite y por que
> - Que trafico se bloquea y por que
> - Como prevenir misconfiguraciones (default-deny, labels obligatorias, revisiones)

## 7. Lo que el equipo ha aprendido
> TODO conjunto al cerrar la semana:
> - Decisiones clave y trade-offs
> - Limitaciones del setup actual
> - Que se haria distinto si tuvieramos mas tiempo
