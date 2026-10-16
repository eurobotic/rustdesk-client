# RustDesk 1.5.0 com marca Eurostec

Árvore gerada automaticamente por [`eurobotic/rustdesk-client`](https://github.com/eurobotic/rustdesk-client) a partir de
[rustdesk/rustdesk@1.5.0](https://github.com/rustdesk/rustdesk/tree/1.5.0) (commit fada664df7a294d1d1a9ca3e7cd3637069122f17).

Diferenças em relação ao upstream:
- `libs/hbb_common/src/config.rs`: ID server `rustdesk.eurobotics.com.br` e a chave pública do servidor da Eurostec.
- Ícones e logos em `res/`, `flutter/assets/`, `flutter/windows/runner/resources/` e `flutter/macos/Runner/`.
- `.github/workflows/flutter-build.yml`: só os jobs de Windows, Linux e macOS.
- `.github/workflows/flutter-tag.yml`: `permissions: contents: write` para o token do Actions poder publicar a release.
- Submódulo `libs/hbb_common` vendorizado.

Licença: AGPL-3.0, como o upstream. Este é o código fonte completo dos binários da release `1.5.0-1`.
