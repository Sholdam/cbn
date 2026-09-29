#!/bin/sh
set -eu

: "${FRP_TOKEN:?FRP_TOKEN is required}"
: "${FRP_SERVER_CERT_B64:?FRP_SERVER_CERT_B64 is required}"
: "${FRP_SERVER_KEY_B64:?FRP_SERVER_KEY_B64 is required}"

umask 077
mkdir -p /run/frp
printf '%s\n' "$FRP_TOKEN" > /run/frp/token
printf '%s' "$FRP_SERVER_CERT_B64" | base64 -d > /run/frp/server.crt
printf '%s' "$FRP_SERVER_KEY_B64" | base64 -d > /run/frp/server.key
unset FRP_TOKEN FRP_SERVER_CERT_B64 FRP_SERVER_KEY_B64

exec /usr/bin/frps -c /etc/frp/frps.toml
