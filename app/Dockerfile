FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html.tmpl /usr/share/nginx/html/index.html.tmpl
COPY render-index.sh /docker-entrypoint.d/render-index.sh

RUN chmod +x /docker-entrypoint.d/render-index.sh \
    && rm -f /usr/share/nginx/html/index.html
