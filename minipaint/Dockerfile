# Docker file for miniPaint
# Refer: https://github.com/kilvn/docker-minipaint

FROM alpine:latest

RUN set -x \
    && apk update -f \
    && apk upgrade \
    && apk --no-cache add -f git curl bash nodejs@16 npm \
    && npm install -g npm -y \
    && rm -rf /var/cache/apk/* \
    && echo "Asia/Shanghai" > /etc/timezone \

RUN mkdir /var/www
WORKDIR /var/www
RUN git clone https://github.com/viliusle/miniPaint.git

WORKDIR /var/www/miniPaint
RUN sed -i "s/'en'/'zh'/g" src/js/config.js \
    && npm install

CMD ["npm", "run", "server"]
EXPOSE 8080/tcp
