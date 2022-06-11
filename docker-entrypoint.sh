#!/usr/bin/env sh
set -eu

source .env

envsubst '${DOMAIN} ${DONE} ${PUBLISH}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

chmod 444 /etc/nginx/nginx.conf

exec "$@"