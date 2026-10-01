#!/usr/bin/env python3
"""Выводит открытый ключ usign, соответствующий приватному.

Приватный ключ usign (Ed25519) хранит 64-байтовый ключ в формате NaCl,
последние 32 байта которого — открытый ключ. Поэтому в секретах CI достаточно
одного приватного ключа: открытый для прошивки получается из него.

Формат приватного ключа: "Ed" | "BK" | kdfrounds[4] | salt[16] |
                         checksum[8] | fingerprint[8] | seckey[64]
Формат открытого ключа:  "Ed" | fingerprint[8] | pubkey[32]
"""
import base64
import sys


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "-"
    data = sys.stdin.read() if path == "-" else open(path).read()
    lines = [line for line in data.splitlines() if line.strip()]
    if len(lines) < 2 or not lines[0].startswith("untrusted comment:"):
        sys.exit("не похоже на ключ usign")
    raw = base64.b64decode(lines[1])
    if len(raw) != 104 or raw[:2] != b"Ed":
        sys.exit("неожиданный размер или алгоритм ключа usign")
    if raw[4:8] != b"\0\0\0\0":
        sys.exit("ключ зашифрован паролем — нужен ключ без пароля (usign -G)")
    fingerprint = raw[32:40]
    pubkey = raw[72:104]
    comment = lines[0].replace("secret key", "public key")
    print(comment)
    print(base64.b64encode(b"Ed" + fingerprint + pubkey).decode())
    return 0


if __name__ == "__main__":
    sys.exit(main())
