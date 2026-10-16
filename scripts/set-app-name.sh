#!/usr/bin/env bash
# Dá ao cliente o nome da Eurostec no Windows: APP_NAME passa a valer só quando compilado para
# Windows, e com isso o exe instalado vira <nome>.exe, o serviço, as regras de firewall, os
# atalhos, a pasta em Program Files e o título da janela seguem o nome, e o esquema de URL fica
# <nome>://. A pasta de configuração também muda (%APPDATA%\<nome>), então o cliente não divide
# ID nem configurações com um RustDesk oficial instalado na mesma máquina.
#
# macOS e Linux continuam "RustDesk" por dentro de propósito: lá o nome também é caminho de
# pacote (RustDesk.app, /usr/share/rustdesk, plists), e trocar exigiria mexer no empacotamento
# do upstream a cada versão.
#
# Uso: set-app-name.sh <arvore-rustdesk> <nome>    (nome só com [A-Za-z0-9-], regra do instalador)
set -euo pipefail

tree="${1:?árvore do RustDesk}"
name="${2:?nome do aplicativo}"
[[ "$name" =~ ^[A-Za-z0-9-]+$ ]] || { echo "set-app-name: o nome só pode ter letras, números e hífen: $name" >&2; exit 1; }

cfg="$tree/libs/hbb_common/src/config.rs"
wf="$tree/.github/workflows/flutter-build.yml"

# --- APP_NAME, só no Windows --------------------------------------------------------------
sed -i -E "s|^    pub static ref APP_NAME: RwLock<String> = RwLock::new\\(\"RustDesk\"\\.to_owned\\(\\)\\);|    pub static ref APP_NAME: RwLock<String> = RwLock::new(if cfg!(target_os = \"windows\") { \"$name\" } else { \"RustDesk\" }.to_owned());|" "$cfg"
grep -q "pub static ref APP_NAME: RwLock<String> = RwLock::new(if cfg!(target_os = \"windows\") { \"$name\" }" "$cfg" \
  || { echo "set-app-name: APP_NAME não casou; o upstream mudou a declaração em config.rs" >&2; exit 1; }

# --- Metadados do exe e do empacotador portátil (propriedades do arquivo no Windows) --------
for toml in "$tree/Cargo.toml" "$tree/libs/portable/Cargo.toml"; do
  sed -i -E \
    -e "s|^(ProductName = )\"RustDesk\"|\\1\"$name\"|" \
    -e "s|^(FileDescription = )\"RustDesk Remote Desktop\"|\\1\"$name\"|" \
    -e "s|^(OriginalFilename = )\"rustdesk.exe\"|\\1\"$name.exe\"|" \
    "$toml"
  grep -q "^ProductName = \"$name\"" "$toml" || { echo "set-app-name: winres não casou em $toml" >&2; exit 1; }
done

# --- MSI: o preprocess.py procura <nome>.exe na pasta de distribuição e grava o nome no pacote.
# O passo do template MSI (para a versão Pro) é removido junto com seu upload.
python3 -I - "$wf" "$name" <<'PY'
import sys
path, name = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()

old = """          pushd ./res/msi
          python preprocess.py --arp -d ../../rustdesk
          nuget restore msi.sln
"""
new = f"""          mv ./rustdesk/rustdesk.exe ./rustdesk/{name}.exe
          pushd ./res/msi
          python preprocess.py --arp -d ../../rustdesk --app-name {name}
          nuget restore msi.sln
"""
assert text.count(old) == 1, "set-app-name: passo 'Build msi' diferente do esperado"
text = text.replace(old, new)

old = """          sha256sum ../../SignOutput/rustdesk-*.msi
"""
new = """          sha256sum ../../SignOutput/rustdesk-*.msi
          mv ../../rustdesk/{name}.exe ../../rustdesk/rustdesk.exe
""".replace("{name}", name)
assert text.count(old) == 1, "set-app-name: fim do passo 'Build msi' diferente do esperado"
text = text.replace(old, new)

start = text.index("      - name: Build pre-built MSI template\n")
end = text.index("      - name: Sign rustdesk self-extracted file\n")
assert start < end
text = text[:start] + text[end:]
assert "msi template" not in text.lower()
open(path, "w", encoding="utf-8").write(text)
import yaml
yaml.safe_load(text)
print(f"set-app-name: MSI gera {name}.msi com o app {name}.exe; passo do template removido")
PY

echo "set-app-name: APP_NAME=$name no Windows (exe, serviço, atalhos, título); macOS e Linux seguem RustDesk por dentro"
