# Insumos de marca

| Arquivo | Obrigatório | Uso |
| --- | --- | --- |
| `icon.svg` (ou `icon.png` com pelo menos 1024x1024, quadrado) | **sim** | Ícone do aplicativo: janela, barra de tarefas, bandeja, instalador, `.app` do macOS, menus do Linux. |
| `logo.svg` ou `logo.png` (horizontal) | sim | Logo mostrado na tela inicial do cliente. É renderizado em até **300x60**; um PNG já nesse tamanho é o ideal. |
| `logo_dark.svg` ou `logo_dark.png` | não | Versão do logo para o tema escuro. Se faltar, o script deriva uma a partir do logo trocando o preto por branco. |

O ícone **não** pode ter o fundo transparente demais nem detalhes finos: ele é reduzido até 16x16.

Origem dos arquivos atuais (outubro de 2026), todos de https://eurostec.com.br:
- `icon.svg`: desenhado a partir do símbolo oficial (as duas barras), com geometria medida em `mstile-150x150.png` e as cores do gradiente amostradas lá (#2985c1, #00acd8, #2388c3), sobre fundo branco arredondado. O `safari-pinned-tab.svg` do site é um traçado automático serrilhado e não serviu.
- `logo.png`: `images/logo.png` do site, 288x60, que já cabe no limite de 300x60 do RustDesk.

`placeholder/icon.svg` existe só para o teste local do pipeline (`scripts/sync.sh --dry-run` com `BRANDING_DIR=branding/placeholder`). O sync real falha se `branding/icon.*` não existir.

O que o `scripts/apply-branding.sh` gera a partir desses insumos, por cima da árvore do RustDesk:

- `res/icon.png`, `res/mac-icon.png` (1024), `res/32x32.png`, `res/64x64.png`, `res/128x128.png`, `res/128x128@2x.png`
- `res/icon.ico` e `flutter/windows/runner/resources/app_icon.ico` (16 a 256)
- `res/tray-icon.ico` (16 e 32), `res/mac-tray-dark-x2.png`, `res/mac-tray-light-x2.png`
- `res/scalable.svg`, `res/logo.svg`, `flutter/assets/icon.svg` (cópias do SVG, quando o insumo é SVG)
- `flutter/macos/Runner/AppIcon.icns`
- `flutter/assets/icon.png`, `flutter/assets/logo.png`, `flutter/assets/logo_light.png`, `flutter/assets/logo_dark.png`
