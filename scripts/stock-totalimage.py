#!/usr/bin/env python3
"""Вырезает из официальной прошивки TP-Link (*_sign.bin) образ для U-Boot.

Файл с сайта TP-Link начинается с заголовка подписи; U-Boot (`run update_totalimage`)
ждёт сам uImage «TP-Link Totalimage». Скрипт находит его и сохраняет отдельно:

    scripts/stock-totalimage.py ax50v1_intel-up-...-sign.bin totalimage.img
"""
import struct
import sys

MAGIC = b"\x27\x05\x19\x56"


def main() -> int:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    data = open(sys.argv[1], "rb").read()
    off = data.find(MAGIC)
    while off >= 0:
        name = data[off + 32:off + 64].rstrip(b"\0")
        size = struct.unpack(">I", data[off + 12:off + 16])[0]
        if name == b"TP-Link Totalimage" and off + 64 + size <= len(data):
            open(sys.argv[2], "wb").write(data[off:off + 64 + size])
            print(f"uImage «TP-Link Totalimage» по смещению {off}, {64 + size} байт -> {sys.argv[2]}")
            return 0
        off = data.find(MAGIC, off + 1)
    sys.exit("в файле не найден uImage «TP-Link Totalimage»")


if __name__ == "__main__":
    sys.exit(main())
