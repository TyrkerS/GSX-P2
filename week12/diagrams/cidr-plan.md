# Pla d'adreçament (CIDR)

> **Estat:** Implementat

## Bloc global

`10.0.0.0/16` (65.534 hosts útils) — reservat per a tota l'organització
GreenDevCorp. Espai privat segons RFC 1918, no enrutable a internet.

## Subdivisió

| Subxarxa       | Rang útil                   | Hosts | Porta d'enllaç | DNS         | Propòsit                               |
|----------------|-----------------------------|-------|----------------|-------------|----------------------------------------|
| 10.0.0.0/24    | 10.0.0.1 - 10.0.0.254       | 254   | 10.0.0.1       | 10.0.100.2  | Infra compartida (kube-system, ingress)|
| 10.0.1.0/24    | 10.0.1.1 - 10.0.1.254       | 254   | 10.0.1.1       | 10.0.100.2  | Entorn dev                             |
| 10.0.2.0/24    | 10.0.2.1 - 10.0.2.254       | 254   | 10.0.2.1       | 10.0.100.2  | Entorn staging                         |
| 10.0.3.0/24    | 10.0.3.1 - 10.0.3.254       | 254   | 10.0.3.1       | 10.0.100.2  | Entorn prod                            |
| 10.0.10.0/24   | 10.0.10.1 - 10.0.10.254     | 254   | 10.0.10.1      | 10.0.100.2  | Accés de partners externs (VPN)        |
| 10.0.100.0/24  | 10.0.100.1 - 10.0.100.254   | 254   | 10.0.100.1     | -           | Serveis compartits (DNS, NTP, LDAP)    |
| 10.0.200.0/24  | reservat                    | 254   | -              | -           | Monitoratge (Prometheus, Grafana)      |
| 10.0.4.0/22    | reservat (4.0 - 7.255)      | 1022  | -              | -           | Creixement futur (nous entorns)        |

**Convencions aplicades a cada /24:**
- `.1`  → porta d'enllaç (router/firewall del segment).
- `.2`  → resolver DNS local del segment (forwarder cap a 10.0.100.2).
- `.10 - .49`  → serveis estàtics (LB, ingress, balancejadors).
- `.50 - .200` → rang DHCP per a pods/VMs autoscalats.
- `.201 - .254`→ reserva manual (desplegaments especials, debugging).

## Raonament

### Per què /24 per entorn

- 254 hosts útils cobreix el catàleg actual (nginx, backend amb rèpliques,
  postgres, sidecars de monitoratge) moltes vegades i deixa marge per a
  l'escalat horitzontal.
- És la mida més llegible: el tercer octet identifica l'entorn de forma
  immediata (`.1.X` = dev, `.2.X` = staging, `.3.X` = prod), la qual cosa
  facilita auditar captures de tràfic i logs de firewall.
- Canviar a /23 o /22 només es justifica si un entorn supera ~150 pods
  estables; en aquest punt el cost de reassignar és baix.

### Per què separar dev / staging / prod en subxarxes diferents

- **Defensa en capes.** Les NetworkPolicies de Kubernetes (capa 7 lògica
  per labels) són una barrera; el routing i el firewall a nivell de xarxa
  (capa 3 per subxarxa) són una barrera independent. Si una de les dues es
  configura malament, l'altra segueix contenint l'incident.
- **Auditoria més simple.** Filtrar logs `src=10.0.1.0/24 dst=10.0.3.0/24`
  detecta qualsevol intent dev → prod sense haver de correlacionar labels
  amb desplegaments.
- **Compliment normatiu.** Compleix amb els principis de segmentació exigits
  per gairebé qualsevol framework (ISO 27001 A.13.1, PCI-DSS req. 1.3,
  NIS2): un entorn compromès no permet accés lateral al següent.

### Per què els partners en la seva pròpia subxarxa

- **Mínim privilegi.** Els partners necessiten accés només als endpoints
  públics (via DMZ/Nginx); no han ni de veure l'espai intern.
- **Traçabilitat.** Qualsevol connexió sortint des de 10.0.10.0/24 que
  intenti arribar a 10.0.X.0/24 (X != 10) és una alerta immediata sense
  necessitat d'inspeccionar el payload.
- **Revocació granular.** Si cal tallar l'accés a un partner, n'hi ha
  prou amb eliminar el seu /28 dins de 10.0.10.0/24, sense tocar producció.

### Reserves i creixement

- `10.0.0.0/24` queda fora dels entorns: és per a la infra que serveix
  a tots (ingress controllers, cert-manager, registre intern).
- `10.0.200.0/24` reservat per a monitoratge perquè les dependències
  siguin unidireccionals (tots → monitoring, mai al revés).
- `10.0.4.0/22` (1022 hosts) reservat íntegre per a futures unitats de
  negoci, oficines o un quart entorn (p.ex. `qa` o `staging-eu`) sense
  haver de renumerar res.
- Queden ~57.000 IPs lliures al /16 per a multi-regió o adquisicions.
