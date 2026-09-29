#!/usr/bin/env bash
set -euo pipefail

vault=/srv/cbn-production
target=$vault/secrets/frp
if [[ "$(findmnt -n -o SOURCE --target "$vault")" != /dev/mapper/cbn_production ]]; then
  echo 'CBN LUKS vault is not mounted' >&2
  exit 2
fi
if [[ -e "$target" ]]; then
  echo 'Tunnel credentials already exist; refusing to replace them' >&2
  exit 3
fi

umask 077
scratch=$(mktemp -d "$vault/secrets/.frp.XXXXXX")
trap 'rm -f -- "$scratch"/*; rmdir -- "$scratch"' EXIT
openssl rand -hex 32 > "$scratch/token"
openssl rand -hex 24 > "$scratch/preview_password"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out "$scratch/ca.key" 2>/dev/null
openssl req -new -x509 -sha256 -days 730 \
  -key "$scratch/ca.key" -out "$scratch/ca.crt" \
  -subj '/CN=CBN tunnel root' \
  -addext 'basicConstraints=critical,CA:TRUE' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign'
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out "$scratch/server.key" 2>/dev/null
openssl req -new -sha256 -key "$scratch/server.key" \
  -out "$scratch/server.csr" -subj '/CN=frps.cbn.internal'
printf '%s\n' \
  'basicConstraints=critical,CA:FALSE' \
  'keyUsage=critical,digitalSignature,keyEncipherment' \
  'extendedKeyUsage=serverAuth' \
  'subjectAltName=DNS:frps.cbn.internal' > "$scratch/server.ext"
openssl x509 -req -sha256 -days 365 -in "$scratch/server.csr" \
  -CA "$scratch/ca.crt" -CAkey "$scratch/ca.key" -CAcreateserial \
  -extfile "$scratch/server.ext" -out "$scratch/server.crt" >/dev/null 2>&1
openssl verify -CAfile "$scratch/ca.crt" "$scratch/server.crt"
mv -- "$scratch" "$target"
trap - EXIT
printf 'tunnel_credentials=prepared_inside_luks\n'
