#!/usr/bin/env sh
set -eu

source .env

envsubst '${DOMAIN} ${DONE} ${PUBLISH}' < nginx.conf.template > nginx.conf

exec "$@"