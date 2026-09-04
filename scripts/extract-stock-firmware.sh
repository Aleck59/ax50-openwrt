#!/usr/bin/env python3
"""
Разбор официальной прошивки TP-Link Archer AX50 v1.

Умеет:
  * разложить TP-Link Totalimage на составные uImage (U-Boot, GPHY FW, RootFS, ядро);
  * распаковать ядро (LZMA) и вытащить из него DTB;
  * при наличии unsquashfs — распаковать rootfs.

Именно этим скриптом получены факты в docs/01-hardware.md и файлы в reference/.

Использование:
    ./scripts/extract-stock-firmware.sh <firmware.bin> [выходной каталог]

Прошивка качается со страницы поддержки TP-Link:
    https://www.tp-link.com/us/support/download/archer-ax50/v1/
"""
import lzma
import os
import re
import struct
import subprocess
import sys
import time

UIMAGE_MAGIC = 0x27051956
OS = {5: "linux"}
ARCH = {4: "mips", 5: "mips64"}
TYPE = {1: "standalone", 2: "kernel", 3: "ramdisk", 4: "multi",
        5: "firmware", 6: "script", 7: "filesystem", 8: "flat_dt"}
COMP = {0: "none", 1: "gzip", 2: "bzip2", 3: "lzma", 4: "lzo", 5: "lz4"}


def parse_uimage(data, off):
    hdr = data[off:off + 64]
    if len(hdr) < 64:
        return None
    magic, hcrc, ts, size, load, ep, dcrc, os_, arch, typ, comp = \
        struct.unpack(">IIIIIIIBBBB", hdr[:32])
    if magic != UIMAGE_MAGIC:
        return None
    return {
        "off": off, "size": size, "load": load, "ep": ep,
        "os": OS.get(os_, os_), "arch": ARCH.get(arch, arch),
        "type": TYPE.get(typ, typ), "comp": COMP.get(comp, comp),
        "name": hdr[32:64].split(b"\0")[0].decode("ascii", "replace"),
        "date": time.strftime("%Y-%m-%d", time.gmtime(ts)),
    }


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    path = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "stock-extracted"
    os.makedirs(out, exist_ok=True)
    data = open(path, "rb").read()
    print(f"файл: {path} ({len(data)} байт)\n")

    # шапка TP-Link: support-list / soft-version / fw_id
    for m in re.finditer(rb"\{product_name:[^}]*\}|soft_ver:[0-9A-Za-z. ]{0,40}|fw_id:[0-9A-F]{32}",
                         data[:8192]):
        print("  ", m.group().decode("ascii", "replace"))
    print()

    images = []
    off = 0
    while True:
        i = data.find(struct.pack(">I", UIMAGE_MAGIC), off)
        if i < 0:
            break
        img = parse_uimage(data, i)
        if img:
            images.append(img)
        off = i + 1

    print(f"{'смещение':>10} {'размер':>10} {'тип':>11} {'сжатие':>7}  имя")
    for img in images:
        print(f"{img['off']:>10} {img['size']:>10} {img['type']:>11} "
              f"{img['comp']:>7}  {img['name']}  ({img['date']})")
    print()

    kernel = None
    rootfs = None
    for img in images:
        if img["type"] == "multi" and img["name"].startswith("TP-Link"):
            continue                      # контейнер целиком
        blob = data[img["off"] + 64: img["off"] + 64 + img["size"]]
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", img["name"]) or f"img_{img['off']}"
        dst = os.path.join(out, safe + ".bin")
        open(dst, "wb").write(blob)
        print(f"записан {dst} ({len(blob)} байт)")
        if img["type"] == "kernel":
            kernel = dst
        if img["type"] == "filesystem":
            rootfs = dst

    if kernel:
        raw = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(
            open(kernel, "rb").read())
        vm = os.path.join(out, "vmlinux.bin")
        open(vm, "wb").write(raw)
        print(f"\nядро распаковано: {vm} ({len(raw)} байт)")
        m = re.search(rb"Linux version [0-9][^\x00]{0,200}", raw)
        if m:
            print("  ", m.group().decode("ascii", "replace"))
        i = raw.find(b"\xd0\x0d\xfe\xed")
        if i >= 0:
            total = struct.unpack(">I", raw[i + 4:i + 8])[0]
            dtb = os.path.join(out, "board.dtb")
            open(dtb, "wb").write(raw[i:i + total])
            print(f"   DTB найден на смещении {i}, записан: {dtb} ({total} байт)")
            try:
                subprocess.run(["dtc", "-I", "dtb", "-O", "dts",
                                "-o", os.path.join(out, "board.dts"), dtb],
                               check=True, stderr=subprocess.DEVNULL)
                print(f"   декомпилирован: {os.path.join(out, 'board.dts')}")
            except (FileNotFoundError, subprocess.CalledProcessError):
                print("   dtc не найден — поставьте device-tree-compiler")

    if rootfs:
        try:
            subprocess.run(["unsquashfs", "-d", os.path.join(out, "rootfs"), rootfs],
                           check=True, stdout=subprocess.DEVNULL)
            print(f"\nrootfs распакован: {os.path.join(out, 'rootfs')}")
            print("  Wi-Fi-стек лежит в rootfs/opt/lantiq, прошивки радио — в rootfs/lib/firmware")
        except (FileNotFoundError, subprocess.CalledProcessError):
            print("\nunsquashfs не найден — поставьте squashfs-tools, чтобы распаковать rootfs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
