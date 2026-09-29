FROM ghcr.io/fatedier/frps:v0.71.0

COPY frps.toml /etc/frp/frps.toml
COPY entrypoint.sh /usr/local/bin/cbn-frps-entrypoint.sh
RUN chmod 0555 /usr/local/bin/cbn-frps-entrypoint.sh

EXPOSE 8080 7000
ENTRYPOINT ["/bin/sh", "/usr/local/bin/cbn-frps-entrypoint.sh"]
