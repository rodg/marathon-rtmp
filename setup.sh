#!/usr/bin/env sh
curl https://cfhcable.dl.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz -o pcre-8.45.tar.gz

source .env

envsubst '${DOMAIN}' < templates/cert.conf.template > cert.conf