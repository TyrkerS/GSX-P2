FROM nginx:alpine

# Nivell Avançat (***): Configuració non-root per a més seguretat
RUN addgroup -S nginxgroup && adduser -S nginxuser -G nginxgroup

# Assignem permisos a l'usuari sobre els directoris necessaris de Nginx
RUN chown -R nginxuser:nginxgroup /var/cache/nginx /var/run /var/log/nginx && \
    touch /tmp/nginx.pid && \
    chown nginxuser:nginxgroup /tmp/nginx.pid

# Copiar HTML
COPY index.html /usr/share/nginx/html/index.html

# Copiar configuración personalizada
COPY nginx.conf /etc/nginx/nginx.conf

# Canviem a l'usuari creat
USER nginxuser

# Exposem un port unprivileged (més gran de 1024)
EXPOSE 8080