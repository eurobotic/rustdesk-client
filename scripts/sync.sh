#!/usr/bin/env bash
# Pega a última release do rustdesk/rustdesk, aplica a marca da Eurostec e o servidor embutido,
# e empurra a árvore pronta como uma tag órfã neste repositório. O push da tag dispara o
# flutter-tag.yml do próprio upstream (naquela versão), que compila e publica a release.
#
# Uso: scripts/sync.sh [--dry-run]
# Ambiente:
#   RUSTDESK_HOST       host do servidor (obrigatório), ex. rustdesk.eurobotics.com.br
#   RUSTDESK_KEY        chave pública do servidor (obrigatório)
#   UPSTREAM_TAG        tag do upstream; vazio = última release
#   REBUILD             "true" para gerar uma tag nova mesmo que essa versão já tenha build
#   BRAND_PRODUCT_NAME  nome do produto nos metadados do exe/app (opcional)
#   BRANDING_DIR        pasta de marca (padrão: branding/)
#   CLIENT_REPO         owner/nome deste repo (padrão: eurobotic/rustdesk-client)
#   CLIENT_REPO_TOKEN   PAT com Contents e Workflows: write (obrigatório sem --dry-run)
#   WORK_DIR            onde clonar (padrão: ./work)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry_run=false
[ "${1:-}" = "--dry-run" ] && dry_run=true

: "${RUSTDESK_HOST:?defina RUSTDESK_HOST}"
: "${RUSTDESK_KEY:?defina RUSTDESK_KEY}"
branding="${BRANDING_DIR:-$here/branding}"
client_repo="${CLIENT_REPO:-eurobotic/rustdesk-client}"
work="${WORK_DIR:-$here/work}"
upstream_repo="rustdesk/rustdesk"

[ -f "$branding/icon.svg" ] || [ -f "$branding/icon.png" ] \
  || { echo "sync: falta $branding/icon.svg (ou icon.png); veja branding/README.md" >&2; exit 1; }

# --- Qual versão -----------------------------------------------------------------------------
tag="${UPSTREAM_TAG:-}"
if [ -z "$tag" ]; then
  tag="$(gh api "repos/$upstream_repo/releases/latest" --jq .tag_name)"
fi
[[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "sync: tag do upstream fora do padrão X.Y.Z: $tag" >&2; exit 1; }

if ! remote_tags="$(git ls-remote --tags "https://github.com/$client_repo.git" "refs/tags/$tag-*" 2>/dev/null)"; then
  $dry_run || { echo "sync: não consegui ler as tags de $client_repo; o repositório existe?" >&2; exit 1; }
  echo "sync: dry-run sem acesso a $client_repo; assumindo que não há builds"
  remote_tags=""
fi
existing="$(echo "$remote_tags" | awk -F/ 'NF {print $NF}' | sort -V)"
if [ -n "$existing" ] && [ "${REBUILD:-false}" != "true" ]; then
  echo "sync: $tag já tem build ($(echo "$existing" | tr '\n' ' ')); nada a fazer. Use REBUILD=true para forçar."
  exit 0
fi
n=$(( $(echo "$existing" | grep -c . || true) + 1 ))
build_tag="$tag-$n"
echo "sync: upstream $tag -> tag $build_tag"

# --- Clona a tag e vendoriza o submódulo ------------------------------------------------------
rm -rf "$work"
mkdir -p "$work"
tree="$work/rustdesk"
git clone --quiet --depth 1 --branch "$tag" --recurse-submodules --shallow-submodules "https://github.com/$upstream_repo.git" "$tree"
upstream_commit="$(git -C "$tree" rev-parse HEAD)"
git -C "$tree" submodule foreach --quiet 'rm -rf .git'   # o conteúdo entra no commit, não o ponteiro
rm -f "$tree/.gitmodules"
rm -rf "$tree/.git"

# --- Marca, servidor e poda dos jobs --------------------------------------------------------
"$here/scripts/embed-server.sh" "$tree" "$RUSTDESK_HOST" "$RUSTDESK_KEY"
"$here/scripts/apply-branding.sh" "$tree" "$branding" "${BRAND_PRODUCT_NAME:-}"
python3 -I "$here/scripts/prune-jobs.py" "$tree/.github/workflows/flutter-build.yml"
python3 -I "$here/scripts/grant-release-permission.py" "$tree/.github/workflows/flutter-tag.yml"
python3 -I "$here/scripts/patch-nasm.py" "$tree/.github/workflows/flutter-build.yml"
# fdroid.yml também dispara em tags e tenta criar uma release "fdroid-version" (falha com 403 aqui).
rm -f "$tree/.github/workflows/fdroid.yml"

cat > "$tree/EUROSTEC.md" <<MD
# RustDesk $tag com marca Eurostec

Árvore gerada automaticamente por [\`$client_repo\`](https://github.com/$client_repo) a partir de
[rustdesk/rustdesk@$tag](https://github.com/rustdesk/rustdesk/tree/$tag) (commit $upstream_commit).

Diferenças em relação ao upstream:
- \`libs/hbb_common/src/config.rs\`: ID server \`$RUSTDESK_HOST\` e a chave pública do servidor da Eurostec.
- Ícones e logos em \`res/\`, \`flutter/assets/\`, \`flutter/windows/runner/resources/\` e \`flutter/macos/Runner/\`.
- \`.github/workflows/flutter-build.yml\`: só os jobs de Windows, Linux e macOS.
- \`.github/workflows/flutter-tag.yml\`: \`permissions: contents: write\` para o token do Actions poder publicar a release.
- \`.github/workflows/fdroid.yml\` removido (publicava um arquivo de versão para o F-Droid).
- Submódulo \`libs/hbb_common\` vendorizado.

Licença: AGPL-3.0, como o upstream. Este é o código fonte completo dos binários da release \`$build_tag\`.
MD

# --- Commit órfão e push da tag --------------------------------------------------------------
git -C "$tree" init -q -b build
# -f: o .gitignore do upstream ignora *png (entre outros) e os arquivos foram adicionados à força lá;
# sem -f, ícones e imagens ficariam fora do commit e o build quebra procurando por eles.
git -C "$tree" -c user.name="eurostec-rustdesk-bot" -c user.email="ti@eurobotics.com.br" \
  add -f -A
git -C "$tree" -c user.name="eurostec-rustdesk-bot" -c user.email="ti@eurobotics.com.br" \
  commit -q -m "RustDesk $tag com marca Eurostec ($build_tag)" -m "Upstream: rustdesk/rustdesk@$upstream_commit"
git -C "$tree" tag "$build_tag"

if $dry_run; then
  echo "sync: dry-run; árvore pronta em $tree, tag local $build_tag (nada enviado)"
  exit 0
fi

: "${CLIENT_REPO_TOKEN:?defina CLIENT_REPO_TOKEN (PAT com Contents e Workflows: write)}"
git -C "$tree" push --quiet "https://x-access-token:${CLIENT_REPO_TOKEN}@github.com/$client_repo.git" "refs/tags/$build_tag"
echo "sync: tag $build_tag enviada; o build aparece em https://github.com/$client_repo/actions"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## RustDesk $tag -> $build_tag"
    echo "- Upstream: rustdesk/rustdesk@$upstream_commit"
    echo "- Build: https://github.com/$client_repo/actions?query=branch%3A$build_tag"
    echo "- Release (quando terminar): https://github.com/$client_repo/releases/tag/$build_tag"
  } >> "$GITHUB_STEP_SUMMARY"
fi
