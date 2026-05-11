# Setmana 9 — Orquestració multi-contenidor (Docker Compose)

## Visió general

Aquesta setmana passem d'un sol contenidor (Setmana 8) a un conjunt
multi-contenidor coordinat definit en un únic fitxer `docker-compose.yml`.
El conjunt conté tres serveis que es comuniquen a través d'una xarxa Docker
privada i fan servir un volum amb nom per a la persistència de dades.

## Diagrama d'arquitectura

```
                          Host (localhost)
                                 │
                                 │  :80
                                 ▼
              ┌──────────────────────────────────────┐
              │   nginx  (greendevcorp/nginx:week9)  │
              │   - serveix index.html estàtic a /   │
              │   - /health retorna "healthy"        │
              │   - /api/ → reverse proxy al backend │
              └────────────┬─────────────────────────┘
                           │  [frontend-net] http://backend:3000
                           ▼
              ┌──────────────────────────────────────┐
              │   backend  (servidor HTTP Node.js)   │
              │   - respon amb JSON                  │
              │   - endpoint /health                 │
              └────────────┬─────────────────────────┘
                           │  [backend-net] postgres://postgres:5432
                           ▼
              ┌──────────────────────────────────────┐
              │   postgres  (imatge oficial)         │
              │   - dades persistents en volum       │
              │     postgres_data → /var/lib/...     │
              └──────────────────────────────────────┘

          El descobriment de serveis s'aconsegueix per nivells de xarxa.
```

## Serveis

### 1. nginx

- **Imatge:** construïda des de `./nginx/Dockerfile` (base `nginx:latest`)
- **Rol:** porta d'entrada del conjunt. Serveix una pàgina estàtica i
  actua com a reverse proxy per al backend.
- **Mapatge de ports:** `${NGINX_PORT:-80}:80` (host:contenidor)
- **Rutes:**
  - `GET /` → `index.html` estàtic
  - `GET /health` → literal `healthy` (s'utilitza per a smoke tests)
  - `GET /api/...` → `proxy_pass` cap a `http://backend:3000/`
- **Per què un reverse proxy?** Amaga el backend de la xarxa del host
  (el port del backend NO es publica), centralitza TLS/logging en un
  únic punt d'entrada i demostra la resolució DNS entre serveis
  (`backend` com a hostname es resol pel DNS integrat de Docker).

### 2. backend

- **Imatge:** construïda des de `./application/Dockerfile` (multistage, usuari
  no root, base `node:20-alpine`).
- **Rol:** servidor HTTP simple de Node.js que respon amb JSON. És
  l'objectiu del reverse proxy `/api/` de nginx.
- **Mapatge de ports:** cap. El servei escolta al port `3000` només dins de la
  xarxa Docker, per tant **no és accessible des del host directament** —
  tot el tràfic extern ha de passar per nginx. Això és intencionat:
  il·lustra el principi "els serveis no han d'exposar ports que no
  necessiten".
- **Variables d'entorn:** `PORT` (llegida per `app.js` via `process.env.PORT`,
  per defecte `3000`).
- **`depends_on: postgres`:** assegura que el contenidor de base de dades
  s'inicia abans que el backend. Nota: amb el `depends_on` bàsic, això
  només garanteix l'ordre d'arrencada, no que postgres estigui *llest*
  per acceptar connexions. La forma avançada afegeix un `healthcheck`
  adequat + `condition: service_healthy` per a això.

### 3. postgres

- **Imatge:** `postgres:16-alpine` (imatge oficial, petita empremta).
- **Rol:** base de dades relacional. Inclosa per demostrar un servei
  amb estat coexistint amb els sense estat i per justificar l'ús d'un
  volum amb nom per a la persistència.
- **Mapatge de ports:** cap. Només accessible des d'altres contenidors a
  `postgres:5432`.
- **Variables d'entorn (requerides per la imatge oficial):**
  - `POSTGRES_USER` — usuari administrador creat al primer arrencament.
  - `POSTGRES_PASSWORD` — contrasenya d'administrador.
  - `POSTGRES_DB` — base de dades inicial creada al primer arrencament.
- **Volum amb nom:** `postgres_data` muntat a
  `/var/lib/postgresql/data`. Tots els fitxers de la base de dades hi
  viuen, de manera que les dades sobreviuen a `docker-compose down` i
  la recreació de contenidors.

## Xarxa

Fem servir **xarxes personalitzades (Tier ***)** allunyant-nos d'un únic
pont predeterminat per a un aïllament precís.

- **`frontend-net`**: Compartida només entre `nginx` i `backend`. Nginx es
  connecta de forma nativa via `http://backend:3000`.
- **`backend-net`**: Compartida només entre `backend` i `postgres`.
- **Garanties d'aïllament**: El frontend Nginx no té cap ruta mapeada a la
  base de dades. Fins i tot si el proxy frontend es veu compromès, els
  atacants no poden accedir directament a Postgres.

## Restriccions de producció (Avançat i Intermedi)

L'arquitectura actualitzada incorpora funcionalitats per a desplegaments
resilients i robustos corresponents a nivells superiors:

- **Healthchecks**: Els serveis tenen sondes integrades (com `pg_isready`,
  `curl`, `wget`) que comproven constantment la disponibilitat.
- **Ordre de preparació**: En lloc del simple ordre d'arrencada, fem servir
  `condition: service_healthy` a través de Compose. Per exemple, `backend`
  aturarà completament l'arrencada fins que Postgres emeti estat llest,
  eliminant les condicions de carrera.
- **Restriccions de recursos (`deploy.resources.limits`)**: Clau per a
  l'escalabilitat multi-inquilí, restringim les capacitats de còmput
  (fraccions de CPU i quota de RAM) per node.
- **Restriccions de logs (`logging`)**: Limitem els logs locals a
  `json-file: 10m` per evitar que les instàncies docker saturin el sistema
  host amb el temps.

## Configuració

La configuració s'externalitza amb variables d'entorn, mai s'inclou
a les imatges ni es codifica directament a `docker-compose.yml`:

- **`.env.example`** — plantilla amb valors de substitució. Commitat a
  git perquè qualsevol membre de l'equip pugui reproduir la configuració.
- **`.env`** — valors reals per a l'entorn local. **Ignorat per git**
  (vegeu `.gitignore`) perquè pot contenir credencials.
- **Substitució:** `docker-compose` carrega automàticament `.env` des del
  mateix directori que `docker-compose.yml` i substitueix
  expressions `${VAR}` / `${VAR:-default}` abans d'iniciar els serveis.

| Variable            | Usat per  | Propòsit                                      |
|---------------------|-----------|-----------------------------------------------|
| `NGINX_PORT`        | nginx     | Port del host que exposa el lloc (defecte 80) |
| `BACKEND_PORT`      | backend   | Port intern del servidor Node.js              |
| `POSTGRES_USER`     | postgres  | Usuari administrador creat al primer arrencament |
| `POSTGRES_PASSWORD` | postgres  | Contrasenya d'administrador                   |
| `POSTGRES_DB`       | postgres  | Nom de la base de dades inicial               |

Per iniciar un clon nou: `cp .env.example .env` i editar-lo com calgui.

## Volums

Només es defineix un volum amb nom:

- **`postgres_data`** — muntat a `/var/lib/postgresql/data` dins del
  contenidor `postgres`. Conté tots els fitxers de la base de dades: el
  clúster en si mateix, la base de dades `greendevcorp`, taules, índexs i
  logs WAL.

**Què sobreviu a `docker-compose down`:** tot allò a `postgres_data`.
La comanda elimina els contenidors però deixa els volums amb nom intactes.
Només `docker-compose down -v` eliminaria també el volum.

**Com hem verificat la persistència:**

```bash
# 1. Stack en funcionament
docker-compose up -d

# 2. Crear una fila a postgres
docker-compose exec postgres \
  psql -U greendevcorp -d greendevcorp \
  -c "CREATE TABLE IF NOT EXISTS notes (msg TEXT);
      INSERT INTO notes VALUES ('persistence test');"

# 3. Aturar el stack (contenidors eliminats, volum conservat)
docker-compose down

# 4. Tornar a engegar-lo
docker-compose up -d

# 5. La fila segueix allà
docker-compose exec postgres \
  psql -U greendevcorp -d greendevcorp -c "SELECT * FROM notes;"
# → "persistence test"
```

## Com executar

```bash
# des de week9/
cp .env.example .env          # editar amb les credencials reals
docker-compose up -d --build  # construir imatges i engegar el stack
docker-compose ps             # verificar que tots els serveis estan actius
```

## Verificació / Smoke tests

```bash
# 1. Pàgina estàtica servida per nginx
curl http://localhost/

# 2. Endpoint de salut de Nginx
curl http://localhost/health

# 3. Reverse proxy: nginx → backend
curl http://localhost/api/

# 4. DNS entre serveis (des de dins del contenidor nginx)
docker-compose exec nginx curl http://backend:3000/health

# 5. Persistència: aturar el stack (conservar volums) i tornar a engegar
docker-compose down
docker-compose up -d
# Les dades a postgres_data han de seguir allà (vegeu la secció de Volums).
```

## Resolució de problemes

- `docker-compose logs <servei>` — inspeccionar la sortida d'un servei individual.
- `docker-compose ps` — veure quins contenidors estan sans.
- `docker network inspect week9_greendevcorp-net` — verificar que tots els serveis
  estan connectats a la mateixa xarxa.
- `502 Bad Gateway` a `/api/` normalment significa que el backend no està
  llest; comprovar `docker-compose logs backend`.

## Passos pendents / Propers passos

El nivell **bàsic (\*)** és complet i verificat d'extrem a extrem.

### Intermedi (\*\*) — recomanat, puja la nota de 5-7 a 8-9

- [x] Afegir `healthcheck:` a cadascun dels tres serveis:
  - nginx: `curl -f http://localhost:8080/health`
  - backend: `wget -q -O - http://localhost:3000/health`
  - postgres: `pg_isready -U ${POSTGRES_USER}`
- [x] Substituir les llistes `depends_on:` senzilles per la forma llarga amb
  `condition: service_healthy`, de manera que:
  - el backend només s'inicia quan postgres està llest per acceptar connexions.
  - nginx només s'inicia quan el backend és realment sa (no més
    `502 Bad Gateway` transitoris en el primer arrencament).
- [x] Afegir una secció curta en aquest document explicant *per què* els
  health checks + l'ordre de preparació importen (no només "l'ordre d'arrencada").

### Avançat (\*\*\*) — opcional, apunta a un 10

- [x] Configurar un driver `logging:` per servei amb límits de mida (per exemple
  `json-file` amb `max-size: 10m`, `max-file: 3`) perquè els logs no puguin
  omplir el disc.
- [x] Afegir límits de recursos (`deploy.resources.limits` per a CPU i
  memòria) a cada servei i documentar els valors escollits.
- [x] Xarxes personalitzades més enllà del pont únic (per exemple, separar
  la base de dades en la seva pròpia xarxa accessible només per al backend).
