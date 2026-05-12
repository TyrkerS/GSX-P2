# Nivell Intermedi (**): Compilació en múltiples etapes (Multistage Builds) per a l'optimització
# Etapa 1: Entorn de construcció
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
# Instal·lació neta de dependències (si n'hi hagués) sense les de desenvolupament
RUN npm install
COPY app.js .

# Etapa 2: Entorn de producció (Runtime)
# Nivell Intermedi i Avançat: Imatge base mínima i Optimització de Capes
FROM node:20-alpine

# Actualitzar npm per corregir vulnerabilitats en les seves dependències internes
RUN npm install -g npm@latest --no-fund --no-audit

# Nivell Avançat (***): Hardening de Seguretat - Creem i utilitzem un usuari sense privilegis
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Únicament copiem els fitxers estrictament necessaris de l'etapa "builder" anterior
COPY --from=builder --chown=appuser:appgroup /app/ .

# Canviem a l'usuari sense privilegis (non-root)
USER appuser

# Exposem el port de l'aplicació
EXPOSE 3000

# Arrancada (start) de l'aplicació
CMD ["node", "app.js"]
