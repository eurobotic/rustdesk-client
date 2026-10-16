#!/usr/bin/env bash
# Aplica a marca da Eurostec por cima de uma árvore do RustDesk: ícones, logos e, se pedido, o
# nome do produto nos metadados do Windows e do macOS. Não muda APP_NAME (pasta de config,
# esquema de URL e nome dos binários continuam "rustdesk").
#
# Uso: apply-branding.sh <arvore-rustdesk> <pasta-branding> [nome-do-produto]
# Precisa de ImageMagick 7 (magick) e python3.
set -euo pipefail

tree="${1:?árvore do RustDesk}"
branding="${2:?pasta com icon.svg/png e logo.svg/png}"
product_name="${3:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pick() { # pick <base> -> caminho do primeiro de base.svg, base.png que existir
  for ext in svg png; do
    [ -f "$branding/$1.$ext" ] && { echo "$branding/$1.$ext"; return 0; }
  done
  return 1
}

icon_src="$(pick icon)" || { echo "apply-branding: falta $branding/icon.svg ou icon.png" >&2; exit 1; }
logo_src="$(pick logo)" || { echo "apply-branding: falta $branding/logo.svg ou logo.png" >&2; exit 1; }
logo_dark_src="$(pick logo_dark || true)"

# Os arquivos que vamos substituir precisam existir na árvore: se não existem, o upstream mudou
# o layout e o script tem que ser revisto, não silenciosamente pular.
required=(
  res/icon.png res/icon.ico res/32x32.png res/64x64.png res/128x128.png res/128x128@2x.png
  res/mac-icon.png res/tray-icon.ico res/mac-tray-dark-x2.png res/mac-tray-light-x2.png
  flutter/windows/runner/resources/app_icon.ico flutter/macos/Runner/AppIcon.icns
  flutter/assets/icon.svg
)
for f in "${required[@]}"; do
  [ -f "$tree/$f" ] || { echo "apply-branding: $f não existe na árvore; o layout do upstream mudou" >&2; exit 1; }
done

# --- Ícone: rasteriza a 1024 e deriva todos os tamanhos ------------------------------------
if [[ "$icon_src" == *.svg ]]; then
  magick -background none -density 400 "$icon_src" -resize 1024x1024 -gravity center -extent 1024x1024 "$work/1024.png"
else
  w="$(magick identify -format '%w' "$icon_src")"
  [ "$w" -ge 512 ] || { echo "apply-branding: icon.png tem ${w}px; precisa de pelo menos 512" >&2; exit 1; }
  magick "$icon_src" -resize 1024x1024 -gravity center -background none -extent 1024x1024 "$work/1024.png"
fi
for s in 16 32 48 64 128 256 512; do
  magick "$work/1024.png" -resize "${s}x${s}" "$work/$s.png"
done

cp "$work/1024.png" "$tree/res/icon.png"
cp "$work/1024.png" "$tree/res/mac-icon.png"
cp "$work/32.png"   "$tree/res/32x32.png"
cp "$work/64.png"   "$tree/res/64x64.png"
cp "$work/128.png"  "$tree/res/128x128.png"
cp "$work/256.png"  "$tree/res/128x128@2x.png"
cp "$work/256.png"  "$tree/flutter/assets/icon.png"
magick "$work/16.png" "$work/32.png" "$work/48.png" "$work/64.png" "$work/128.png" "$work/256.png" "$tree/res/icon.ico"
cp "$tree/res/icon.ico" "$tree/flutter/windows/runner/resources/app_icon.ico"
magick "$work/16.png" "$work/32.png" "$tree/res/tray-icon.ico"
magick "$work/1024.png" -resize 60x60 "$tree/res/mac-tray-dark-x2.png"
magick "$work/1024.png" -resize 48x48 "$tree/res/mac-tray-light-x2.png"
python3 -I "$here/make-icns.py" "$tree/flutter/macos/Runner/AppIcon.icns" \
  16="$work/16.png" 32="$work/32.png" 64="$work/64.png" 128="$work/128.png" \
  256="$work/256.png" 512="$work/512.png" 1024="$work/1024.png"
if [[ "$icon_src" == *.svg ]]; then
  for f in res/scalable.svg res/logo.svg flutter/assets/icon.svg; do
    [ -f "$tree/$f" ] && cp "$icon_src" "$tree/$f"
  done
fi

# --- Logo da tela inicial: até 300x60, nas versões clara e escura ---------------------------
render_logo() { # render_logo <src> <dst>
  if [[ "$1" == *.svg ]]; then
    magick -background none -density 300 "$1" -resize 300x60 "$2"
  else
    magick "$1" -resize '300x60>' "PNG32:$2"
  fi
}
render_logo "$logo_src" "$tree/flutter/assets/logo.png"
cp "$tree/flutter/assets/logo.png" "$tree/flutter/assets/logo_light.png"
if [ -n "$logo_dark_src" ]; then
  render_logo "$logo_dark_src" "$tree/flutter/assets/logo_dark.png"
else
  # Sem versão escura: o que é preto (texto) vira branco; o azul da marca fica como está.
  magick "$tree/flutter/assets/logo.png" -fuzz 35% -fill white -opaque black "$tree/flutter/assets/logo_dark.png"
fi

# --- Nome do produto nos metadados (opcional) -----------------------------------------------
if [ -n "$product_name" ]; then
  rc="$tree/flutter/windows/runner/Runner.rc"
  xc="$tree/flutter/macos/Runner/Configs/AppInfo.xcconfig"
  sed -i -E "s/(VALUE \"CompanyName\", )\"[^\"]*\"/\1\"Eurostec\"/; s/(VALUE \"ProductName\", )\"[^\"]*\"/\1\"$product_name\"/; s/(VALUE \"FileDescription\", )\"[^\"]*\"/\1\"$product_name\"/" "$rc"
  sed -i -E "s/^(PRODUCT_NAME = ).*/\1$product_name/" "$xc"
  grep -q "\"$product_name\"" "$rc" || { echo "apply-branding: não consegui trocar o nome em Runner.rc" >&2; exit 1; }
fi

echo "apply-branding: ícones e logos aplicados a partir de $icon_src e $logo_src"
