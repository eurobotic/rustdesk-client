#!/usr/bin/env python3
"""Monta um .icns do macOS a partir de PNGs já redimensionados, sem depender de icnsutils.

Uso: make-icns.py saida.icns 16=icon-16.png 32=icon-32.png ... 1024=icon-1024.png
Cada entrada vira o chunk do tamanho correspondente (PNG embutido, aceito desde o macOS 10.7).
"""
import struct
import sys

# tamanho em pixels -> tipo do chunk (os @2x apontam para o mesmo PNG do tamanho dobrado)
TYPES = {
    16: [b"icp4"],
    32: [b"icp5", b"ic11"],
    64: [b"icp6", b"ic12"],
    128: [b"ic07"],
    256: [b"ic08", b"ic13"],
    512: [b"ic09", b"ic14"],
    1024: [b"ic10"],
}


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    out = sys.argv[1]
    chunks = b""
    for arg in sys.argv[2:]:
        size, path = arg.split("=", 1)
        size = int(size)
        if size not in TYPES:
            print(f"make-icns: tamanho {size} não tem chunk ICNS", file=sys.stderr)
            return 1
        data = open(path, "rb").read()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            print(f"make-icns: {path} não é PNG", file=sys.stderr)
            return 1
        for t in TYPES[size]:
            chunks += t + struct.pack(">I", 8 + len(data)) + data
    with open(out, "wb") as f:
        f.write(b"icns" + struct.pack(">I", 8 + len(chunks)) + chunks)
    return 0


if __name__ == "__main__":
    sys.exit(main())
