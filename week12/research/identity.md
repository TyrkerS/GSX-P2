# Identity Management

> **Owner:** Persona B
> **Estado:** TODO

Este documento responde a la seccion "Research: Identity Management" y
"Identity strategy for GreenDevCorp" del PDF (Semana 12).

## 1. Authentication vs Authorization

La **Autenticación (Authentication o Authn)** se encarga de verificar "quién eres". Es el proceso mediante el cual el sistema valida la identidad del usuario a través de algo que sabe (contraseña), algo que tiene (token, SMS) o algo que es (biometría). Si el proceso de autenticación falla, el usuario no puede acceder al sistema bajo ninguna circunstancia.

Por otro lado, la **Autorización (Authorization o Authz)** determina "qué puedes hacer". Una vez que el usuario ha sido autenticado exitosamente, el sistema de autorización decide a qué recursos o acciones específicas tiene acceso, normalmente basándose en roles (RBAC) o políticas de acceso. Por ejemplo, iniciar sesión en GitHub con un nombre de usuario y contraseña es autenticación; sin embargo, que GitHub te permita ver un repositorio privado pero no te permita hacer *push* a la rama principal de otro proyecto, es autorización.

## 2. Centralized Identity

### LDAP (Lightweight Directory Access Protocol)
LDAP es un protocolo estándar utilizado para consultar y modificar servicios de directorio jerárquicos. Funciona como una base de datos optimizada para lecturas rápidas que almacena información sobre usuarios, grupos, dispositivos y políticas de la organización. Sus casos de uso más comunes incluyen la validación centralizada de credenciales (para no tener usuarios locales en cada servidor), listar miembros de grupos para control de acceso, o buscar información corporativa como el correo o departamento de un empleado. Las implementaciones más extendidas son OpenLDAP (open-source) y 389 Directory Server.

### Active Directory (AD)
Active Directory es la implementación privativa de Microsoft para servicios de directorio, y de facto el estándar en entornos empresariales fuertemente basados en Windows. Combina LDAP para el acceso al directorio, Kerberos para la autenticación segura, y DNS para la resolución de servicios. Su mayor ventaja competitiva, además de la integración nativa con Windows, es el uso de Group Policy Objects (GPOs), que permiten a los administradores gestionar de forma centralizada la configuración y seguridad de miles de equipos desde un solo punto.

### SSO (Single Sign-On)
Single Sign-On (SSO) es una solución que permite a un usuario autenticarse una única vez y acceder a múltiples aplicaciones de forma transparente sin tener que volver a introducir sus credenciales. Generalmente utiliza protocolos modernos como SAML o OIDC (construido sobre OAuth2). Sus beneficios son dobles: para el usuario, elimina la fatiga de contraseñas y mejora la experiencia; para la organización, centraliza el control de acceso, reduce riesgos de filtraciones (menos passwords débiles) y hace que el proceso de *offboarding* sea instantáneo, ya que revocar el acceso en el proveedor de identidad bloquea automáticamente la entrada a todos los sistemas dependientes.

## 3. Recomendación para GreenDevCorp

Dado el contexto de GreenDevCorp (startup en crecimiento con más de 20 empleados, equipos técnicos y de operaciones, dos oficinas internacionales, múltiples entornos y colaboradores externos), la estrategia de identidad debe priorizar la seguridad, la centralización y la reducción de sobrecarga operativa.

**Estrategia Recomendada:**
Recomiendo encarecidamente adoptar un **Proveedor de Identidad (IdP) gestionado en la nube** (como Google Workspace, Microsoft Entra ID u Okta) en lugar de desplegar y mantener soluciones *on-premise* como OpenLDAP o Active Directory. Sobre este IdP, se debe implementar **Single Sign-On (SSO)** utilizando OIDC/SAML para integrar todas las herramientas internas y externas (GitHub, AWS/GCP, dashboards de Kubernetes, Grafana, herramientas de CI/CD). Además, el control de acceso (Autorización) debe basarse en un modelo de **Control de Acceso Basado en Roles (RBAC)**, agrupando a los usuarios en grupos lógicos según su función (ej. `dev-team`, `ops-team`, `partners`) y asignando permisos a nivel de grupo, nunca a nivel de usuario individual.

**Trade-offs y Justificación:**
- **Coste y Mantenimiento:** Aunque un IdP en la nube tiene un coste recurrente por usuario (OpEx), elimina la enorme carga operativa y el gasto en infraestructura (CapEx) de mantener servidores LDAP distribuidos globalmente para dar servicio a dos oficinas, parchear vulnerabilidades y gestionar copias de seguridad de identidades críticas.
- **Disponibilidad:** Si el sistema de identidad cae, nadie puede trabajar. Un IdP comercial garantiza SLAs del 99.9% y escalabilidad global, algo muy difícil de conseguir con un equipo de operaciones pequeño que aún está automatizando su infraestructura base.
- **Vendor Lock-in vs Seguridad:** Si bien se genera una dependencia del proveedor, se gana acceso a características avanzadas de seguridad nativas e imprescindibles para el teletrabajo y la conexión entre oficinas, como la Autenticación Multifactor (MFA), el análisis de riesgo de inicio de sesión y la gestión de acceso condicional, las cuales serían muy complejas de construir internamente.

**Prácticas a Evitar:**
Queda estrictamente descartado el uso de cuentas locales independientes en cada servidor o aplicación, ya que hace inviable un *offboarding* seguro y rápido cuando alguien abandona la empresa. De igual forma, está prohibido el uso de credenciales compartidas (ej. una cuenta genérica `admin` para todo el equipo de operaciones); cada acción debe ser atribuible a una identidad individual mediante auditoría.

**Evolución Futura (Roadmap):**
A corto plazo (1-3 meses), el objetivo es migrar los repositorios de código y las aplicaciones críticas de infraestructura (Kubernetes, monitoring) detrás del SSO del IdP, aplicando MFA obligatorio. A medio plazo (6 meses), se conectará la VPN (si es que no se transiciona a un modelo Zero Trust Network Access completo) para que las dos oficinas autentiquen el tráfico de red mediante el mismo proveedor. Finalmente, a largo plazo, se puede automatizar el ciclo de vida completo del usuario conectando el IdP con los sistemas de RRHH.
