FROM grafana/grafana:latest

USER root

ARG GF_GID="472"
RUN addgroup --system --gid $GF_GID grafana && \
    chown -R root:root /etc/grafana && \
    chmod -R a+r /etc/grafana && \
    chown -R grafana:grafana /var/lib/grafana && \
    chown -R grafana:grafana /usr/share/grafana

EXPOSE 3100
