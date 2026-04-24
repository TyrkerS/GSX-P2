# Week 9 — Multi-Container Orchestration (Docker Compose)

## Overview

This week we move from single containers (Week 8) to a coordinated
multi-container stack defined in a single `docker-compose.yml` file.
The stack contains three services that communicate over a private Docker
network and use a named volume for data persistence.

## Architecture Diagram

```
                          Host (localhost)
                                 │
                                 │  :80
                                 ▼
              ┌──────────────────────────────────────┐
              │   nginx  (greendevcorp/nginx:week9)  │
              │   - serves static index.html at /    │
              │   - /health returns "healthy"        │
              │   - /api/ → reverse proxy to backend │
              └────────────┬─────────────────────────┘
                           │  [frontend-net] http://backend:3000
                           ▼
              ┌──────────────────────────────────────┐
              │   backend  (Node.js HTTP server)     │
              │   - responds with JSON               │
              │   - /health endpoint                 │
              └────────────┬─────────────────────────┘
                           │  [backend-net] postgres://postgres:5432
                           ▼
              ┌──────────────────────────────────────┐
              │   postgres  (official image)         │
              │   - persistent data in named volume  │
              │     postgres_data → /var/lib/...     │
              └──────────────────────────────────────┘

          Service discovery is scoped by tier mapping. 
```

## Services

### 1. nginx (Persona A)

- **Image:** built from `./nginx/Dockerfile` (base `nginx:latest`)
- **Role:** front door of the stack. Serves a static landing page and
  acts as a reverse proxy for the backend.
- **Port mapping:** `${NGINX_PORT:-80}:80` (host:container)
- **Routes:**
  - `GET /` → static `index.html`
  - `GET /health` → literal `healthy` (used for smoke tests)
  - `GET /api/...` → `proxy_pass` to `http://backend:3000/`
- **Why a reverse proxy?** It hides the backend from the host network
  (the backend port is NOT published), centralizes TLS/logging in a
  single entry point, and demonstrates inter-service DNS resolution
  (`backend` as a hostname is resolved by Docker's embedded DNS).

### 2. backend (Persona B)

- **Image:** built from `./application/Dockerfile` (multistage, non-root
  user, base `node:20-alpine`).
- **Role:** simple Node.js HTTP server that responds with JSON. It is
  the target of the `/api/` reverse proxy in nginx.
- **Port mapping:** none. The service listens on `3000` only inside the
  Docker network, so it is **not reachable from the host directly** —
  all external traffic has to go through nginx. This is intentional:
  it demonstrates the "services should not expose ports they don't
  need" principle.
- **Env vars:** `PORT` (read by `app.js` via `process.env.PORT`,
  defaulting to `3000`).
- **`depends_on: postgres`:** ensures the database container is
  started before the backend. Note: with the core `depends_on` this
  only guarantees start order, not that postgres is *ready* to accept
  connections. The intermediate tier adds a proper `healthcheck` +
  `condition: service_healthy` for that.

### 3. postgres (Persona B)

- **Image:** `postgres:16-alpine` (official image, small footprint).
- **Role:** relational database. Included to demonstrate a stateful
  service coexisting with the stateless ones and to justify the use of
  a named volume for persistence.
- **Port mapping:** none. Only reachable from other containers on
  `greendevcorp-net` at `postgres:5432`.
- **Env vars (required by the official image):**
  - `POSTGRES_USER` — admin user created on first boot.
  - `POSTGRES_PASSWORD` — admin password.
  - `POSTGRES_DB` — initial database created on first boot.
- **Named volume:** `postgres_data` mounted at
  `/var/lib/postgresql/data`. All database files live there, so the
  data survives `docker-compose down` and container recreation.

## Networking

We employ **Custom Networks (Tier ***)** moving away from a single default bridge to precise isolation.

- **`frontend-net`**: Shared only between `nginx` and `backend`. Nginx connects natively via `http://backend:3000`.
- **`backend-net`**: Shared only between `backend` and `postgres`.
- **Isolation guarantees**: The Nginx frontend has no route mapped to the database. Even if the frontend proxy is compromised, attackers cannot directly ping Postgres.

## Production Constraints (Advanced & Intermediate)

The updated architecture incorporates features for resilient, robust deployments mapping to higher tiers:

- **Healthchecks**: Services have built-in probes (e.g. `pg_isready`, `curl`, `wget`) constantly checking availability. 
- **Ordered Readiness**: Rather than mere start order, we use `condition: service_healthy` across Compose. For instance, `backend` will completely halt startup until Postgres emits ready status, eliminating race conditions.
- **Resource Constraints (`deploy.resources.limits`)**: Crucial for multi-tenant scalability, we restrict compute capabilities (CPU fractions & RAM quota) per node.
- **Log constraints (`logging`)**: We cap local logs at `json-file: 10m` to prevent docker instances from suffocating the host system over time.

## Configuration

Configuration is externalised with environment variables, never baked
into images or hard-coded in `docker-compose.yml`:

- **`.env.example`** — template with placeholder values. Committed to
  git so any teammate can reproduce the setup.
- **`.env`** — real values for the local environment. **Ignored by git**
  (see `.gitignore`) because it may contain credentials.
- **Substitution:** `docker-compose` automatically loads `.env` from the
  same directory as `docker-compose.yml` and substitutes
  `${VAR}` / `${VAR:-default}` expressions before starting services.

| Variable            | Used by   | Purpose                                     |
|---------------------|-----------|---------------------------------------------|
| `NGINX_PORT`        | nginx     | Host port exposing the site (default 80)    |
| `BACKEND_PORT`      | backend   | Internal port of the Node.js server         |
| `POSTGRES_USER`     | postgres  | Admin user created on first boot            |
| `POSTGRES_PASSWORD` | postgres  | Admin password                              |
| `POSTGRES_DB`       | postgres  | Initial database name                       |

To bootstrap a fresh clone: `cp .env.example .env` and edit as needed.

## Volumes

Only one named volume is defined:

- **`postgres_data`** — mounted at `/var/lib/postgresql/data` inside the
  `postgres` container. Contains all database files: the cluster
  itself, the `greendevcorp` database, tables, indexes, and WAL logs.

**What survives `docker-compose down`:** everything in `postgres_data`.
The command removes the containers but leaves named volumes intact.
Only `docker-compose down -v` would also delete the volume.

**How we verified persistence:**

```bash
# 1. Stack up
docker-compose up -d

# 2. Create a row in postgres
docker-compose exec postgres \
  psql -U greendevcorp -d greendevcorp \
  -c "CREATE TABLE IF NOT EXISTS notes (msg TEXT);
      INSERT INTO notes VALUES ('persistence test');"

# 3. Tear the stack down (containers gone, volume kept)
docker-compose down

# 4. Bring it back up
docker-compose up -d

# 5. The row is still there
docker-compose exec postgres \
  psql -U greendevcorp -d greendevcorp -c "SELECT * FROM notes;"
# → "persistence test"
```

## How to Run

```bash
# from week9/
cp .env.example .env          # Persona B will provide .env.example
docker-compose up -d --build  # build images and start the stack
docker-compose ps             # verify all services are Up
```

## Verification / Smoke Tests

```bash
# 1. Static page served by nginx
curl http://localhost/

# 2. Nginx health endpoint
curl http://localhost/health

# 3. Reverse proxy: nginx → backend
curl http://localhost/api/

# 4. Inter-service DNS (from inside the nginx container)
docker-compose exec nginx curl http://backend:3000/health

# 5. Persistence: bring the stack down (keep volumes) and back up
docker-compose down
docker-compose up -d
# Data in postgres_data must still be there (see Persona B section).
```

## Troubleshooting

- `docker-compose logs <service>` — inspect a single service's output.
- `docker-compose ps` — see which containers are healthy.
- `docker network inspect week9_greendevcorp-net` — verify all services
  are attached to the same network.
- `502 Bad Gateway` on `/api/` usually means the backend is not yet
  ready; check `docker-compose logs backend`.

## Authors

- Persona A: nginx service, architecture diagram, reverse-proxy config.
- Persona B: backend service, postgres + volume, env configuration.

## Pending / Next Steps

The **core (\*)** tier is complete and verified end-to-end. The
following items are still open:

### Intermediate (\*\*) — recommended, bumps grade from 5–7 to 8–9

- [x] Add `healthcheck:` to each of the three services:
  - nginx: `curl -f http://localhost:8080/health`
  - backend: `wget -q -O - http://localhost:3000/health`
  - postgres: `pg_isready -U ${POSTGRES_USER}`
- [x] Replace the plain `depends_on:` lists with the long form using
  `condition: service_healthy`, so that:
  - backend only starts once postgres is ready to accept connections.
  - nginx only starts once the backend is actually healthy (no more
    transient `502 Bad Gateway` on first boot).
- [x] Add a short section in this document explaining *why* health
  checks + ordered readiness matter (not just "start order").

### Advanced (\*\*\*) — optional, targets a 10

- [x] Configure a `logging:` driver per service with size limits (e.g.
  `json-file` with `max-size: 10m`, `max-file: 3`) so logs cannot fill
  the disk.
- [x] Add resource limits (`deploy.resources.limits` for CPU and
  memory) to each service and document the chosen values.
- [x] Custom networks beyond the single bridge (e.g. separate the
  database into its own network only reachable by the backend).


### Housekeeping

- [ ] Git commits from both authors (evidence of collaboration is part
  of the grading rubric). Make sure `git config user.name` and
  `user.email` are set correctly on each machine before committing.
- [ ] Quick README at the repo root (or a link from it) pointing to
  this document.
