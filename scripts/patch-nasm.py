#!/usr/bin/env python3
"""Deixa o passo "Install NASM" do job de macOS tolerante a www.nasm.us fora do ar.

O upstream baixa o zip do NASM 2.16.03 direto de www.nasm.us com um único wget; o site recusa
conexões com frequência e o job inteiro de macOS morre no segundo minuto. Trocamos por tentativas
com espera e, se nada vier, compilação da mesma versão a partir do espelho oficial no GitHub.
Se o upstream mudar o passo, avisa e não faz nada: o build segue como o upstream fez.

Uso: patch-nasm.py <caminho/flutter-build.yml>
"""
import sys

OLD = """          wget https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/macosx/nasm-2.16.03-macosx.zip
          unzip nasm-2.16.03-macosx.zip
          sudo cp nasm-2.16.03/nasm /usr/local/bin/nasm
"""
NEW = """          ok=""
          for i in 1 2 3 4 5; do
            if wget -q --timeout=30 https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/macosx/nasm-2.16.03-macosx.zip; then ok=1; break; fi
            echo "nasm.us indisponivel (tentativa $i); esperando 30 s"; sleep 30
          done
          if [ -n "$ok" ]; then
            unzip nasm-2.16.03-macosx.zip
            sudo cp nasm-2.16.03/nasm /usr/local/bin/nasm
          else
            echo "nasm.us fora do ar; compilando o NASM 2.16.03 a partir do GitHub"
            brew install autoconf automake
            git clone --depth 1 --branch nasm-2.16.03 https://github.com/netwide-assembler/nasm.git nasm-src
            (cd nasm-src && ./autogen.sh && ./configure && make -j"$(sysctl -n hw.ncpu)" nasm)
            sudo cp nasm-src/nasm /usr/local/bin/nasm
          fi
"""


def main() -> int:
    path = sys.argv[1]
    text = open(path, encoding="utf-8").read()
    if OLD not in text:
        print("patch-nasm: passo Install NASM diferente do esperado; deixado como está", file=sys.stderr)
        return 0
    open(path, "w", encoding="utf-8").write(text.replace(OLD, NEW, 1))
    print("patch-nasm: download do NASM com tentativas e fallback para compilar do GitHub")
    return 0


if __name__ == "__main__":
    sys.exit(main())
