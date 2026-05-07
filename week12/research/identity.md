# Identity Management

> **Owner:** Persona B
> **Estado:** TODO

Este documento responde a la seccion "Research: Identity Management" y
"Identity strategy for GreenDevCorp" del PDF (Semana 12).

## 1. Authentication vs Authorization

> TODO Persona B - 1-2 parrafos por concepto:
>
> - **Authentication (authn):** "quien eres". Verificas la identidad del usuario
>   (password, certificado, token, biometrico, MFA). Si el authn falla, no entras.
> - **Authorization (authz):** "que puedes hacer". Una vez autenticado, decides
>   a que recursos tiene acceso (RBAC, ABAC, ACLs).
> - Ejemplo concreto: meterte en GitHub con tu password = authn. GitHub permite
>   que veas el repo X pero no que hagas push al main = authz.

## 2. Centralized Identity

### LDAP (Lightweight Directory Access Protocol)
> TODO Persona B:
> - Que es: protocolo estandar para consultar/modificar directorios jerarquicos
>   de usuarios, grupos y recursos
> - Casos de uso: validar credenciales, listar miembros de un grupo, buscar
>   datos de un empleado
> - Implementaciones comunes: OpenLDAP (open source), 389 Directory Server

### Active Directory (AD)
> TODO Persona B:
> - Implementacion de Microsoft basada en LDAP + Kerberos + DNS
> - Estandar en empresas con stack Windows
> - Anade Group Policy (gestion centralizada de configuracion de equipos)

### SSO (Single Sign-On)
> TODO Persona B:
> - Que problema resuelve: el usuario se autentica UNA vez y puede acceder a
>   multiples aplicaciones sin volver a meter password
> - Protocolos: SAML (mas tradicional), OIDC (moderno, sobre OAuth2)
> - Beneficios: menos passwords que recordar/filtrar, control centralizado de
>   accesos, easier offboarding (revocas en un sitio = revocas en todos)

## 3. Recomendacion para GreenDevCorp

> TODO Persona B - este es el apartado que mas pesa en el oral.
>
> Contexto: GreenDevCorp tiene 20+ personas, multiples teams (devs, data,
> ops), 2 oficinas en paises distintos, environments dev/staging/prod,
> partners externos.
>
> Estructura sugerida de la respuesta:
>
> 1. **Que recomendarias y por que.** Por ejemplo:
>    - Identity provider gestionado (Google Workspace, Microsoft Entra ID,
>      Okta) en vez de montar OpenLDAP/AD on-prem
>    - SSO via OIDC para todas las apps internas (GitHub, monitoring,
>      Kubernetes dashboard, Grafana...)
>    - Grupos por equipo para hacer authz por RBAC
>
> 2. **Trade-offs.** Discute:
>    - Coste recurrente vs coste de mantener tu propio LDAP
>    - Vendor lock-in vs autonomia
>    - Operacional: quien se encarga si el IdP cae?
>    - Cumplimiento (RGPD): donde se almacenan los datos de empleados
>
> 3. **Que NO recomendarias.** Por ejemplo:
>    - Crear cuentas locales independientes en cada sistema (no escala,
>      offboarding inseguro)
>    - Compartir credenciales (root, admin) entre miembros del equipo
>
> 4. **Como evolucionarias.** Roadmap a 12 meses: empezar por SSO en
>    aplicaciones criticas, luego extender, finalmente integrar con AWS/GCP IAM.
