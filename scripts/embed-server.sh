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

# Trava os campos de servidor: tudo que está em OVERWRITE_SETTINGS vale sempre, não é salvo
# pelo usuário e aparece desabilitado na tela de rede (is_option_fixed). É o mesmo mecanismo
# que o custom.txt da versão Pro usa com "override-settings".
over='pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from(['
over="$over(\"custom-rendezvous-server\".to_owned(), \"$host\".to_owned()), "
over="$over(\"relay-server\".to_owned(), \"$host:21117\".to_owned()), "
over="$over(\"api-server\".to_owned(), String::new()), "
over="$over(\"key\".to_owned(), \"$key\".to_owned())]));"
sed -i -E "s|^    pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = Default::default\(\);|    $over|" "$cfg"
grep -q '^    pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from(\[("custom-rendezvous-server"' "$cfg" \
  || { echo "embed-server: OVERWRITE_SETTINGS não casou; o upstream mudou a declaração em config.rs" >&2; exit 1; }

echo "embed-server: ID server $host e chave embutidos e travados em config.rs"
