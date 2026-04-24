FROM nginx:alpine

RUN addgroup -S nginxgroup && adduser -S nginxuser -G nginxgroup

RUN chown -R nginxuser:nginxgroup /var/cache/nginx /var/run /var/log/nginx && \
    touch /tmp/nginx.pid && \
    chown nginxuser:nginxgroup /tmp/nginx.pid

# Copiar HTML
COPY index.html /usr/share/nginx/html/index.html

# Copiar configuración personalizada
COPY nginx.conf /etc/nginx/nginx.conf

USER nginxuser

EXPOSE 8080