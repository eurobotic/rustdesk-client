#!/usr/bin/env python3
"""Remove do flutter-build.yml do upstream os jobs que a Eurostec não distribui.

Edita o texto em vez de reescrever o YAML, para o resto do arquivo ficar byte a byte igual ao
upstream. Depois confere, lendo o YAML, que nenhum job restante depende de um job removido.

Uso: prune-jobs.py <caminho/flutter-build.yml>
"""
import re
import sys

import yaml

REMOVE = [
    "build-for-windows-sciter",
    "build-rustdesk-ios",
    "build-rustdesk-android",
    "build-rustdesk-android-universal",
    "build-rustdesk-linux-drm",
    "build-rustdesk-linux-sciter",
    "build-flatpak",
    "build-rustdesk-web",
    "publish-signed-update-metadata",
    "publish_unsigned",
]
JOB_LINE = re.compile(r"^  ([A-Za-z0-9_-]+):\s*$")


def main() -> int:
    path = sys.argv[1]
    lines = open(path, encoding="utf-8").read().split("\n")
    out, skipping, removed = [], False, []
    in_jobs = False
    for line in lines:
        if line.rstrip() == "jobs:":
            in_jobs = True
        m = JOB_LINE.match(line) if in_jobs else None
        if m:
            skipping = m.group(1) in REMOVE
            if skipping:
                removed.append(m.group(1))
        elif in_jobs and line and not line.startswith(" ") and not line.startswith("#"):
            skipping = False  # saiu do bloco jobs
        if not skipping:
            out.append(line)
    text = "\n".join(out)
    open(path, "w", encoding="utf-8").write(text)

    jobs = yaml.safe_load(text)["jobs"]
    for name, job in jobs.items():
        needs = job.get("needs") or []
        needs = [needs] if isinstance(needs, str) else needs
        missing = [n for n in needs if n not in jobs]
        if missing:
            print(f"prune-jobs: {name} depende de {missing}, que foi removido", file=sys.stderr)
            return 1
    print(f"prune-jobs: removidos {removed}; ficaram {list(jobs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
