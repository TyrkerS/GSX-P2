# Setmana 8: Contenidors (Docker)

Aquest directori conté la configuració d'infraestructura de contenidors per a la transformació digital de GreenDevCorp, resolent les tasques de la Setmana 8.

## Estructura

```text
week8/
├── application/
│   ├── app.js
│   ├── Dockerfile
│   └── package.json
└── nginx/
    ├── Dockerfile
    ├── index.html
    └── nginx.conf
```

---

## 1. Contenidor Nginx (Frontend)



---

## 2. Contenidor de l'Aplicació Backend

**Ubicació:** `application/Dockerfile`

Un servidor HTTP senzill fet amb Node.js que actua com a capa d'aplicació funcional.

### Imatge Base i Dependències
- **Imatge base:** `node:20-alpine`. Similar a l'Nginx, emprem la imatge mínima Alpine per a l'entorn de Node.js.
- **Dependències:** Empra els mòduls HTTP natius de Node.js, per tant, no li calen paquets `npm` externs, mantenint l'aplicació extremadament lleugera.

### Hardening de Seguretat i Optimitzacions (Intermedi i Avançat)
- **Multi-stage Builds:** El Dockerfile està dividit en una fase de compilació (`builder`) i una fase de producció. Tot i que aquesta aplicació actual és ràpida i senzilla, aquesta estructura et permet assegurar que les dependències de desenvolupament no passaran a la descàrrega de producció final.
- **Execució sense privilegis (Non-root):** Evitem l'usuari `root` aplicant les bones pràctiques: hem creat específicament l'usuari i grup `appuser`/`appgroup` i hem indicat l'ordre de pas (`USER appuser`) just abans d'iniciar el servei.

---

## Com Construir i Executar els contenidors Localment

Per poder comprovar qualsevol dels contenidors al teu ordinador manualment de forma local, navega dins de la carpeta `week8` i escriu les següents ordres:

### Nginx
1. **Construeix la imatge:**
   ```bash
   cd nginx
   docker build -t nginx-gsx .
   ```
2. **Executa el contenidor:**
   ```bash
   # Mapegem el port de l'ordinador (80) al port del contenidor non-root (8080)
   docker run -d -p 80:8080 --name gsx-frontend nginx-gsx
   ```
3. **Verifica'l:** Obre un navegador web i navega cap a `http://localhost` (o executa `curl http://localhost`).

### Backend Node.js
1. **Construeix la imatge:**
   ```bash
   cd ../application
   docker build -t backend-gsx .
   ```
2. **Executa el contenidor:**
   ```bash
   # Mapegem el port habitual (3000)
   docker run -d -p 3000:3000 --name gsx-backend backend-gsx
   ```
3. **Verifica'l:** Obre un navegador anant a `http://localhost:3000` o usa `curl http://localhost:3000`.

---

## Pujada al Docker Hub

Un cop fets els passos previs, per completar la tasca Core de la pràctica has de pujar aquestes imatges al teu perfil de Docker Hub:

1. **Inicia sessió a Docker Hub mitjançant terminal:**
   ```bash
   docker login
   ```
2. **Etiqueta (Tag) les teves Imatges:** Substitueix `eltunomdusuari` pel teu nom d'usuari real de Docker Hub.
   ```bash
   docker tag nginx-gsx eltunomdusuari/nginx-gsx:v1
   docker tag backend-gsx eltunomdusuari/backend-gsx:v1
   ```
3. **Puja les Imatges al servidor:**
   ```bash
   docker push eltunomdusuari/nginx-gsx:v1
   docker push eltunomdusuari/backend-gsx:v1
   ```

