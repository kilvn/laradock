FROM chishin/nginx-proxy-manager-zh:release

RUN python3 -m pip install --upgrade pip \
    && pip install certbot-dns-dnspod \
    && pip install zope

ARG NGINX_PHP_UPSTREAM_CONTAINER=php-fpm
ARG NGINX_PHP_UPSTREAM_PORT=9000

# Set upstream conf and remove the default conf
RUN echo "upstream php-upstream { server ${NGINX_PHP_UPSTREAM_CONTAINER}:${NGINX_PHP_UPSTREAM_PORT}; }" > /etc/nginx/conf.d/upstream.conf
