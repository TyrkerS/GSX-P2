# Arquitectura de red - GreenDevCorp

> **Owner:** Persona A
> **Estado:** TODO
>
> Objetivo: visualizar la segmentacion logica de la red de la empresa
> mostrando entornos (dev/staging/prod), zonas (DMZ/internal/database)
> y conexiones externas (internet, partners).

## Diagrama

> Sustituye este placeholder por un diagrama Mermaid o ASCII art.
> Mermaid se renderiza directo en GitHub. Ejemplo de esqueleto:

```mermaid
flowchart LR
    INTERNET[Internet]
    PARTNERS[Partners externos]

    subgraph DMZ
        LB[Load Balancer / Nginx]
    end

    subgraph DEV[Entorno dev - 10.0.1.0/24]
        DEV_APP[backend-dev]
        DEV_DB[(postgres-dev)]
    end

    subgraph STAGING[Entorno staging - 10.0.2.0/24]
        STG_APP[backend-staging]
        STG_DB[(postgres-staging)]
    end

    subgraph PROD[Entorno prod - 10.0.3.0/24]
        PROD_APP[backend-prod]
        PROD_DB[(postgres-prod)]
    end

    INTERNET --> LB
    PARTNERS -.-> LB
    LB --> DEV_APP
    LB --> STG_APP
    LB --> PROD_APP
    DEV_APP --> DEV_DB
    STG_APP --> STG_DB
    PROD_APP --> PROD_DB
```

## Componentes

> TODO: por cada zona, decir que vive ahi, que puede recibir y a que puede llamar.

- **DMZ (Demilitarized Zone):** ...
- **Entorno dev:** ...
- **Entorno staging:** ...
- **Entorno prod:** ...
- **Partners externos:** ...

## Flujos de trafico

> TODO: enumerar los flujos validos. Ejemplos:
> - Internet -> LB en DMZ (HTTPS 443)
> - LB -> backend-prod (HTTP 3000)
> - backend-prod -> postgres-prod (TCP 5432)
> - dev <-> staging: prohibido
> - prod <-> dev: prohibido
