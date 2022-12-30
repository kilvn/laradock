FROM uozi/nginx-ui:latest

RUN echo "deb https://mirrors.163.com/debian/ bullseye main non-free contrib" > /etc/apt/sources.list \
    && echo "deb-src https://mirrors.163.com/debian/ bullseye main non-free contrib" >> /etc/apt/sources.list \
    && echo "deb https://mirrors.aliyun.com/debian-security/ bullseye-security main" >> /etc/apt/sources.list \
    && echo "deb-src https://mirrors.aliyun.com/debian-security/ bullseye-security main" >> /etc/apt/sources.list \
    && echo "deb https://mirrors.163.com/debian/ bullseye-updates main non-free contrib" >> /etc/apt/sources.list \
    && echo "deb-src https://mirrors.163.com/debian/ bullseye-updates main non-free contrib" >> /etc/apt/sources.list \
    && echo "deb https://mirrors.163.com/debian/ bullseye-backports main non-free contrib" >> /etc/apt/sources.list \
    && echo "deb-src https://mirrors.163.com/debian/ bullseye-backports main non-free contrib" >> /etc/apt/sources.list

RUN apt update \
    && apt upgrade -y \
    && apt install -y zsh vim nano telnet coreutils lsof procps

RUN set -x ; \
    addgroup -g 82 -S www-data ; \
    adduser -u 82 -D -S -G www-data www-data && exit 0 ; exit 1

ARG NGINX_PHP_UPSTREAM_CONTAINER=php-fpm
ARG NGINX_PHP_UPSTREAM_PORT=9000

ARG NGINX_PHP74_UPSTREAM_CONTAINER=php-fpm74
ARG NGINX_PHP56_UPSTREAM_CONTAINER=php-fpm56

# Create 'messages' file used from 'logrotate'
RUN touch /var/log/messages

# Set upstream conf and remove the default conf
RUN echo "upstream php-upstream { server ${NGINX_PHP_UPSTREAM_CONTAINER}:${NGINX_PHP_UPSTREAM_PORT}; }" > /etc/nginx/conf.d/upstream.conf \
    && echo "upstream php74-upstream { server ${NGINX_PHP74_UPSTREAM_CONTAINER}:${NGINX_PHP_UPSTREAM_PORT}; }" >> /etc/nginx/conf.d/upstream.conf \
    && echo "upstream php56-upstream { server ${NGINX_PHP56_UPSTREAM_CONTAINER}:${NGINX_PHP_UPSTREAM_PORT}; }" >> /etc/nginx/conf.d/upstream.conf \
    && rm /etc/nginx/conf.d/nginx-ui.conf

#CMD ["nohup", "/app/nginx-ui", "--config", "/etc/nginx-ui/app.ini", "&"]

EXPOSE 80 443 9000
