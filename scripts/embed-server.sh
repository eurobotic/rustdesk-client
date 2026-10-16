#!/usr/bin/env bash
# Embute o servidor da Eurostec no cliente: troca as duas constantes de libs/hbb_common/src/config.rs
# que o RustDesk usa como ID server e chave padrão. O usuário instala e já está no servidor certo.
#
# Uso: embed-server.sh <arvore-rustdesk> <host> <chave-publica-base64>
set -euo pipefail

tree="${1:?árvore do RustDesk}"
host="${2:?host do servidor, ex. rustdesk.eurobotics.com.br}"
key="${3:?chave pública do servidor (conteúdo de id_ed25519.pub)}"
cfg="$tree/libs/hbb_common/src/config.rs"

[ -f "$cfg" ] || { echo "embed-server: $cfg não existe (submódulo não baixado?)" >&2; exit 1; }
[[ "$key" =~ ^[A-Za-z0-9+/=]{40,48}$ ]] || { echo "embed-server: a chave não parece uma chave ed25519 em base64: $key" >&2; exit 1; }

sed -i -E \
  -e "s|^(pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[)\"[^\"]*\"(\];)|\1\"$host\"\2|" \
  -e "s|^(pub const RS_PUB_KEY: &str = )\"[^\"]*\";|\1\"$key\";|" \
  "$cfg"

grep -q "^pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[\"$host\"\];" "$cfg" \
  || { echo "embed-server: RENDEZVOUS_SERVERS não casou; o upstream mudou o formato de config.rs" >&2; exit 1; }
grep -q "^pub const RS_PUB_KEY: &str = \"$key\";" "$cfg" \
  || { echo "embed-server: RS_PUB_KEY não casou; o upstream mudou o formato de config.rs" >&2; exit 1; }

echo "embed-server: ID server $host e chave embutidos em config.rs"
