# build image
FROM alpine:latest as builder

ARG NGINX_VERSION=1.16.1
ARG NGINX_RTMP_VERSION=1.2.7


RUN apk --no-cache add build-base libressl-dev

RUN mkdir -p /tmp/build && \
    cd /tmp/build && \
    wget -q -O nginx.tar.gz http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -zxf nginx.tar.gz && \
    wget -q -O nginx-rtmp-module.tar.gz https://github.com/winshining/nginx-http-flv-module/archive/v${NGINX_RTMP_VERSION}.tar.gz && \
    tar -zxf nginx-rtmp-module.tar.gz && \
    # for whatever reason Docker Hub needs the tar command to be followed by another command
    cd nginx-${NGINX_VERSION}

COPY ./pcre-8.45.tar.gz /tmp/build/pcre-8.45.tar.gz

RUN cd /tmp/build && tar -zxf pcre-8.45.tar.gz

COPY ./patch.diff /tmp/build/patch.diff
RUN cd /tmp/build/nginx-http-flv-module-${NGINX_RTMP_VERSION} && \
    patch -p1 < /tmp/build/patch.diff

RUN ls -la /tmp/build

RUN cd /tmp/build/nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/lock/nginx.lock \
        --http-client-body-temp-path=/tmp/nginx/client-body \
        --user=nginx --group=nginx \
        --without-http_gzip_module \
        --with-http_ssl_module \
        --with-pcre=../pcre-8.45 \
        --add-module=../nginx-http-flv-module-${NGINX_RTMP_VERSION} && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    cp objs/nginx /tmp/build/


# final image
FROM alpine:latest
LABEL maintainer="Niklas Grießer <niklas@griesser.me>"

RUN apk update && \
    apk add \
        libressl \
        libstdc++ \
        ca-certificates\
        gettext \
        ffmpeg

RUN addgroup -S nginx && \
    adduser -s /sbin/nologin -G nginx -S -D -H nginx

RUN mkdir -p /etc/nginx /var/log/nginx /var/www && \
    chown -R nginx:nginx /var/log/nginx /var/www && \
    chmod -R 775 /var/log/nginx /var/www

RUN mkdir -p /tmp/nginx/client-body /tmp/nginx/dash /tmp/nginx/hls && \
    chown -R nginx:nginx /tmp/nginx && \
    chmod -R 770 /tmp/nginx

RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 1935

COPY --from=builder /tmp/build/nginx /usr/local/sbin/nginx
RUN chmod 550 /usr/local/sbin/nginx

COPY nginx.conf.template /etc/nginx/nginx.conf.template

RUN mkdir -p /var/thumbnails /tmp/thumbnail_recordings && \
    chown -R nginx:nginx /var/thumbnails && \
    chmod -R 777 /var/thumbnails

RUN chown -R nginx:nginx /tmp/thumbnail_recordings && \
    chmod -R 777 /tmp/thumbnail_recordings

COPY ./index.html /var/www/player/html/index.html

COPY docker-entrypoint.sh /
RUN chown nginx:nginx /docker-entrypoint.sh
RUN chmod 777 /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD ["nginx", "-g", "daemon off;"]

