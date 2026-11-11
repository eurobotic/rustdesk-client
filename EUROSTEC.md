# RustDesk 1.5.3 com marca Eurostec

Árvore gerada automaticamente por [`eurobotic/rustdesk-client`](https://github.com/eurobotic/rustdesk-client) a partir de
[rustdesk/rustdesk@1.5.3](https://github.com/rustdesk/rustdesk/tree/1.5.3) (commit 95cca3f661f635b3cc85c04935fe8d96d8f432ef).

Diferenças em relação ao upstream:
- `libs/hbb_common/src/config.rs`: ID server `rustdesk.eurobotics.com.br` e a chave pública do servidor da Eurostec.
- Ícones e logos em `res/`, `flutter/assets/`, `flutter/windows/runner/resources/` e `flutter/macos/Runner/`.
- Nome do aplicativo no Windows: `nexus-desk` (APP_NAME em config.rs, metadados winres, MSI). macOS e Linux seguem "RustDesk" por dentro.
- `.github/workflows/flutter-build.yml`: só os jobs de Windows, Linux e macOS.
- `.github/workflows/flutter-tag.yml`: `permissions: contents: write` para o token do Actions poder publicar a release.
- `.github/workflows/fdroid.yml` removido (publicava um arquivo de versão para o F-Droid).
- Submódulo `libs/hbb_common` vendorizado.

Licença: AGPL-3.0, como o upstream. Este é o código fonte completo dos binários da release `1.5.3-1`.
