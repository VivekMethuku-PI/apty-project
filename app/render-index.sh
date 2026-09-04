#!/bin/sh
set -eu
: "${ENVIRONMENT:=Dev}"
sed "s|__ENVIRONMENT__|${ENVIRONMENT}|g" \
  /usr/share/nginx/html/index.html.tmpl \
  > /usr/share/nginx/html/index.html
