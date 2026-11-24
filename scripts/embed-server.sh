#!/usr/bin/env bash
# Embute o servidor da Eurostec no cliente: troca as duas constantes de libs/hbb_common/src/config.rs
# que o RustDesk usa como ID server e chave padrão. O usuário instala e já está no servidor certo.
#
# Uso: embed-server.sh <arvore-rustdesk> <host> <chave-publica-base64> [websocket]
#   websocket = Y liga "Use WebSocket" por padrão: o cliente fala com o servidor por wss://<host>
#   na porta 443 (sempre via relay). O usuário ainda pode desligar em Configurações › Rede.
set -euo pipefail

tree="${1:?árvore do RustDesk}"
host="${2:?host do servidor, ex. rustdesk.eurobotics.com.br}"
key="${3:?chave pública do servidor (conteúdo de id_ed25519.pub)}"
websocket="${4:-}"
cfg="$tree/libs/hbb_common/src/config.rs"

[ -f "$cfg" ] || { echo "embed-server: $cfg não existe (submódulo não baixado?)" >&2; exit 1; }
case "$websocket" in Y|N|"") ;; *) echo "embed-server: websocket tem que ser Y, N ou vazio, não '$websocket'" >&2; exit 1 ;; esac
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
# api-server = https://<host> não é uma API (o servidor open source não tem): é o que faz o modo
# WebSocket usar wss://<host>/ws/id e /ws/relay na porta 443, atendida pelo Caddy do servidor.
over='pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from(['
over="$over(\"custom-rendezvous-server\".to_owned(), \"$host\".to_owned()), "
over="$over(\"relay-server\".to_owned(), \"$host:21117\".to_owned()), "
over="$over(\"api-server\".to_owned(), \"https://$host\".to_owned()), "
over="$over(\"key\".to_owned(), \"$key\".to_owned())]));"
sed -i -E "s|^    pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = Default::default\(\);|    $over|" "$cfg"
grep -q '^    pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from(\[("custom-rendezvous-server"' "$cfg" \
  || { echo "embed-server: OVERWRITE_SETTINGS não casou; o upstream mudou a declaração em config.rs" >&2; exit 1; }

# Modo WebSocket ligado de fábrica (build para rede que só deixa sair 443). Vai em DEFAULT_SETTINGS,
# não em OVERWRITE: é o valor inicial, e o botão "Use WebSocket" continua funcionando.
if [ "$websocket" = "Y" ]; then
  dflt='pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("allow-websocket".to_owned(), "Y".to_owned())]));'
  sed -i -E "s|^    pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = Default::default\(\);|    $dflt|" "$cfg"
  grep -q '^    pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from(\[("allow-websocket"' "$cfg" \
    || { echo "embed-server: DEFAULT_SETTINGS não casou; o upstream mudou a declaração em config.rs" >&2; exit 1; }
fi

echo "embed-server: ID server $host, API server https://$host e chave embutidos e travados em config.rs; websocket por padrão: ${websocket:-N}"
