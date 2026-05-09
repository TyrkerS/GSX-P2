# Servicios core: DNS, DHCP, NTP

> **Owner:** Persona B
> **Estado:** TODO

Este documento responde a la seccion "Research: Core Services" del PDF (Semana 12).
1-2 parrafos por servicio, escritos para alguien no tecnico.

## DNS (Domain Name System)

El Sistema de Nombres de Dominio (DNS) es fundamentalmente la "agenda telefónica" de Internet y de las redes privadas. Su propósito principal es traducir nombres legibles por humanos (como `google.com` o `backend-api.local`) a direcciones IP numéricas (como `192.168.1.50`) que las máquinas utilizan para comunicarse. A alto nivel, cuando un cliente busca un dominio, la consulta pasa por varios niveles jerárquicos: el resolver local, servidores raíz (root), servidores TLD (.com, .net), y finalmente el servidor autoritativo que posee el registro final (ya sea un registro A para IPv4, AAAA para IPv6, CNAME para alias, etc.).

Para una organización, mantener un DNS interno es crítico. Permite a los distintos componentes y servicios localizarse entre sí utilizando nombres lógicos y estables en lugar de direcciones IP que pueden cambiar dinámicamente o de forma impredecible. Esto es especialmente cierto en entornos como Kubernetes, donde los Services proveen registros DNS internos de forma automática (ej. `backend-dev.default.svc.cluster.local`), aislando las consultas de la red pública por motivos de seguridad y asegurando que las aplicaciones sigan comunicándose sin importar dónde se reprogramen los contenedores.

## DHCP (Dynamic Host Configuration Protocol)

DHCP es el protocolo encargado de asignar dinámicamente direcciones IP y otros parámetros de configuración de red (como la puerta de enlace o los servidores DNS) a los dispositivos que se conectan a una red. Resuelve el problema de escalabilidad que supone configurar la red de forma manual en cada dispositivo. Funciona mediante un intercambio rápido en cuatro pasos conocido como DORA (Discover, Offer, Request, Acknowledge): el cliente transmite por broadcast buscando un servidor, el servidor le ofrece una IP disponible, el cliente la solicita formalmente y el servidor confirma la concesión.

En el contexto de una organización, DHCP es imprescindible para gestionar redes dinámicas de manera eficiente. Permite que portátiles que se conectan a la VPN, equipos invitados en oficinas o dispositivos IoT obtengan conectividad instantánea y libre de conflictos. Para servidores o infraestructura crítica, se suelen usar "reservas DHCP" que aseguran que una misma dirección MAC obtenga siempre la misma IP, combinando la facilidad de una administración centralizada con la estabilidad de una IP estática. Aunque en Kubernetes la asignación de IP en los pods la gestiona el CNI, el protocolo es vital para la provisión de los nodos físicos o virtuales del clúster subyacente.

## NTP (Network Time Protocol)

NTP es un protocolo diseñado para sincronizar los relojes de los dispositivos a través de una red con precisión de submilisegundos. Funciona basándose en una arquitectura jerárquica llamada stratum: el Stratum 0 representa fuentes de tiempo de altísima precisión (relojes atómicos o GPS), el Stratum 1 son servidores conectados directamente a esas fuentes, y así hasta llegar a los clientes (Stratum N). En una organización, la mejor práctica es desplegar 2 o 3 servidores NTP internos que sincronicen su tiempo contra fuentes públicas (como `pool.ntp.org`) y configuren toda la infraestructura y dispositivos locales para que apunten a estos servidores internos, garantizando cohesión en toda la red.

La sincronización precisa del tiempo no es un mero detalle operativo; es absolutamente crítica para la seguridad y la correcta función de los sistemas distribuidos. Si los relojes difieren, la correlación de eventos en logs forenses se vuelve imposible al intentar investigar un incidente o auditar la plataforma. Aún más importante, la validez de los certificados TLS y tokens de autenticación (como JWT o tickets de Kerberos) depende de ventanas de tiempo estrictas. Una desincronización de tan solo un par de minutos puede causar el rechazo generalizado de credenciales válidas o la rotura en las comunicaciones seguras del sistema.
