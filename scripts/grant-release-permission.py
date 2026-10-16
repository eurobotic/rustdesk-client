#!/usr/bin/env python3
"""Garante que o flutter-tag.yml do upstream peça escrita em contents para o GITHUB_TOKEN.

O flutter-build.yml publica a release com o token padrão do Actions, mas só o job de SBOM declara
permissions. A organização eurobotic deixa o padrão em somente leitura, então sem isto o build
termina e a release não é criada. Um workflow pode elevar a própria permissão com a chave
permissions; o workflow chamado (flutter-build.yml) herda o teto do chamador.

Uso: grant-release-permission.py <caminho/flutter-tag.yml>
"""
import sys

import yaml


def main() -> int:
    path = sys.argv[1]
    text = open(path, encoding="utf-8").read()
    doc = yaml.safe_load(text)
    if "permissions" in doc:
        print(f"grant-release-permission: {path} já declara permissions: {doc['permissions']}")
        return 0
    marker = "\njobs:\n"
    if marker not in text:
        print("grant-release-permission: não achei o bloco jobs:", file=sys.stderr)
        return 1
    text = text.replace(marker, "\npermissions:\n  contents: write\n" + marker, 1)
    open(path, "w", encoding="utf-8").write(text)
    doc = yaml.safe_load(text)
    assert doc["permissions"] == {"contents": "write"}
    print("grant-release-permission: permissions.contents = write em flutter-tag.yml")
    return 0


if __name__ == "__main__":
    sys.exit(main())
