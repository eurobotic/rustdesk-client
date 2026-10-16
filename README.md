# RustDesk client Eurostec

Cliente [RustDesk](https://github.com/rustdesk/rustdesk) com a marca da Eurostec e o servidor da empresa já configurado. Ninguém mantém um fork à mão: a cada release do upstream, um workflow baixa a versão nova, aplica ícones e logo, embute o endereço e a chave do servidor e deixa o próprio processo de build do RustDesk compilar e publicar.

**Download:** [releases/latest](https://github.com/eurobotic/rustdesk-client/releases/latest). Instaladores `nexus-desk-X.Y.Z-...` para Windows x64 e arm64 (`.exe` e `.msi`), Linux x64 e arm64 (`.deb`, `.AppImage`, `.rpm`) e macOS (`.dmg` Intel e Apple Silicon).

O servidor fica em [`eurobotic/rustdesk_srv`](https://github.com/eurobotic/rustdesk_srv) (Terraform na AWS). O passo a passo completo, do servidor à instalação nos computadores, está no [`SETUP.md`](https://github.com/eurobotic/rustdesk_srv/blob/main/SETUP.md) desse repositório.

## Como funciona

```
main (este branch)                 tags 1.5.0-1, 1.5.1-1, ... (órfãs)
├── branding/   insumos de marca   ├── árvore completa do rustdesk@1.5.0
├── scripts/    sync e patches     │   + ícones/logo da Eurostec
└── .github/    sync.yml           │   + config.rs com servidor e chave
    └── promote.yml                └── .github/workflows do upstream (podado)
```

1. `sync.yml` roda todo dia (ou à mão). `scripts/sync.sh` pergunta ao GitHub qual é a última release do `rustdesk/rustdesk`; se já existe uma tag `X.Y.Z-N` aqui, para.
2. Clona a tag do upstream com o submódulo `libs/hbb_common`, vendoriza o submódulo e aplica:
   - `embed-server.sh`: `RENDEZVOUS_SERVERS` e `RS_PUB_KEY` em `libs/hbb_common/src/config.rs`, e os campos ID server, relay, API server e chave entram em `OVERWRITE_SETTINGS`, o que os deixa fixos e desabilitados na tela de rede (o mesmo mecanismo do `custom.txt` da versão Pro);
   - `set-app-name.sh` (quando `BRAND_APP_NAME` está definido): no Windows o aplicativo passa a se chamar `<nome>` por dentro: `<nome>.exe` instalado, serviço, firewall, atalhos, pasta em Program Files, título da janela e pasta de configuração `%APPDATA%\<nome>`; metadados do exe e MSI acompanham. macOS e Linux continuam `RustDesk.app` e `/usr/bin/rustdesk` por dentro, com ícone e logo da Eurostec, porque lá o nome é caminho de pacote;
   - `apply-branding.sh`: todos os ícones e logos (lista em `branding/README.md`); opcionalmente o nome do produto nos metadados do `.exe` e do `.app`;
   - `prune-jobs.py`: tira do `flutter-build.yml` os jobs de iOS, Android, sciter, flatpak, web e os `publish` que não usamos;
   - `grant-release-permission.py`: acrescenta `permissions: contents: write` ao `flutter-tag.yml`, porque a organização deixa o token do Actions em somente leitura por padrão e a release precisa de escrita;
   - remove `fdroid.yml`, que também dispara em tags só para publicar um arquivo de versão do F-Droid;
   - `patch-nasm.py`: o job de macOS baixa o NASM de www.nasm.us, que cai com frequência; o passo ganha tentativas e um fallback que compila a mesma versão a partir do GitHub.
3. Faz um commit **órfão** com a árvore pronta (`git add -f`, porque o `.gitignore` do RustDesk ignora `*png` e o upstream adicionou as imagens à força) e empurra só a tag `X.Y.Z-N` (`N` é o contador de rebuild da mesma versão). O push usa um PAT porque push com o token do Actions não dispara workflows.
4. O `flutter-tag.yml` **do upstream, naquela tag**, dispara e compila Windows, Linux e macOS exatamente como o projeto faz, publicando a release `X.Y.Z-N` como pré-lançamento. Zero manutenção dos passos de build: cada versão traz o workflow dela.
5. `promote.yml` acorda quando esse build termina, renomeia os arquivos de `rustdesk-X.Y.Z-...` para `<BRAND_APP_NAME>-X.Y.Z-...`, confere os seis instaladores e tira o pré-lançamento, marcando como *latest*.

A árvore de cada tag é o código fonte completo daquele binário (AGPL-3.0). O arquivo `EUROSTEC.md` dentro dela lista o que mudou em relação ao upstream.

## Configuração do repositório

Uma vez só, em Settings do repositório:

| Onde | Nome | Valor |
| --- | --- | --- |
| Variables | `RUSTDESK_HOST` | `rustdesk.eurobotics.com.br` |
| Variables | `RUSTDESK_KEY` | chave pública do servidor (`scripts/show-key.sh` no repo do servidor). Não é segredo. |
| Variables | `BRAND_APP_NAME` | `nexus-desk`: nome do aplicativo no Windows e prefixo dos arquivos da release. Só letras, números e hífen (regra do instalador). Vazio mantém "rustdesk". |
| Variables | `BRAND_PRODUCT_NAME` | opcional: texto das propriedades do `.exe` e do `.app`, se quiser diferente de `BRAND_APP_NAME`. |
| Secrets | `CLIENT_REPO_TOKEN` | PAT fine-grained só para este repositório, com **Contents: write** e **Workflows: write** (a tag carrega `.github/workflows`). |

```bash
gh variable set RUSTDESK_HOST --body rustdesk.eurobotics.com.br
gh variable set RUSTDESK_KEY --body "$(AWS_PROFILE=eurobotics ../rustdesk_srv/scripts/show-key.sh)"
gh secret set CLIENT_REPO_TOKEN   # cola o PAT
```

A organização eurobotic mantém o token do Actions em somente leitura por padrão e não deixa o repositório mudar isso; por isso o sync insere `permissions: contents: write` no `flutter-tag.yml` de cada tag, o que basta para a release ser criada.

Os workflows do upstream rodam com `secrets: inherit`, então o PAT fica visível para o código do RustDesk naquela tag. Ele só tem poder sobre este repositório, o mesmo que o token padrão do Actions já teria.

Insumos de marca: `branding/icon.svg` e `branding/logo.png` (ou `.svg`). Detalhes e tamanhos em [`branding/README.md`](branding/README.md). Sem `icon.*` o sync falha de propósito.

## Rodar à mão

```bash
# build da última release (ou de uma específica), pela interface do Actions ou:
gh workflow run sync.yml
gh workflow run sync.yml -f upstream_tag=1.5.0 -f rebuild=true

# teste local, sem enviar nada: deixa a árvore pronta em work/rustdesk
RUSTDESK_HOST=rustdesk.eurobotics.com.br RUSTDESK_KEY=<chave> UPSTREAM_TAG=1.5.0 scripts/sync.sh --dry-run
```

Quando um job falha por um site externo fora do ar (o build do RustDesk baixa de aomedia.googlesource.com, www.nasm.us e outros), reexecute só ele: `gh run rerun <id> --failed`. Os jobs que passaram ficam, e o refeito adiciona o instalador à mesma release. `rebuild=true` é para quando a correção foi no nosso lado: gera `X.Y.Z-2`, e a release antiga pode ser apagada.

Um repositório público sem commits por 60 dias tem o `schedule` desligado pelo GitHub; o aviso chega por e-mail e um clique religa.

## Avisos aos usuários

- **Windows:** o instalador não é assinado. O SmartScreen mostra "Windows protegeu o computador"; clique em *Mais informações* › *Executar assim mesmo*. Assinar exige um certificado de código (custo anual) e os secrets `SIGN_BASE_URL`/`SIGN_SECRET_KEY` que o workflow do upstream já sabe usar.
- **macOS:** sem notarização, o Gatekeeper bloqueia na primeira abertura: botão direito no app › *Abrir*, ou `xattr -d com.apple.quarantine /Applications/RustDesk.app`.
- **Linux:** `.deb` para Ubuntu/Debian e `.AppImage` para o resto.
- No Windows o cliente se instala como `nexus-desk` (exe, serviço, atalhos) e usa a pasta `%APPDATA%\nexus-desk`, separada de um RustDesk oficial: pode coexistir, mas o ID é outro. No macOS e Linux o app continua se chamando RustDesk por dentro e divide a configuração com o oficial.
- Os campos de servidor (ID server, relay, API, chave) aparecem desabilitados nas configurações de rede: estão fixos no binário.

## Fallback sem rebuild

Para apontar o RustDesk oficial do Windows para o servidor sem recompilar, basta renomear o executável: `rustdesk-host=rustdesk.eurobotics.com.br,key=<chave>.exe`. O cliente lê a configuração do próprio nome na primeira execução.
