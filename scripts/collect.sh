#!/bin/bash
#
# Собирает результаты сборки в каталог для релиза:
#
#   ax50-openwrt-<версия>-squashfs-sysupgrade.bin  обновление из работающей системы
#   ax50-openwrt-<версия>-squashfs-fullimage.img    заливка из U-Boot (TFTP)
#   ax50-openwrt-<версия>-initramfs-kernel.bin      загрузка в ОЗУ без записи во флеш
#   ax50-openwrt-<версия>.manifest                  состав образа
#   ax50-openwrt-<версия>-buildinfo.tar.gz          config/feeds/version.buildinfo
#   ax50-openwrt-<версия>-sdk.tar.xz                SDK для сборки фида (workflow 2)
#   ax50-openwrt-<версия>-packages.tar.gz           пакеты этой сборки: модули ядра
#                                                   (targets/…) и bin/packages
#   sha256sums
#
#   scripts/collect.sh <версия> <каталог>
#
set -euo pipefail
. "$(dirname "$0")/lib.sh"

VER="${1:?версия}"
OUT="$(mkdir -p "${2:?каталог}" && cd "$2" && pwd)"
BIN="$TREE/bin"
TGT="$BIN/targets/intel_mips/xrx500"
NAME="ax50-openwrt-$VER"

[ -d "$TGT" ] || die "нет $TGT — сборка не завершилась"

for f in "$TGT"/*TPLINK_AX50*; do
	[ -f "$f" ] || continue
	case "$f" in
	*-squashfs-sysupgrade.bin) cp "$f" "$OUT/$NAME-squashfs-sysupgrade.bin" ;;
	*-squashfs-fullimage.img)  cp "$f" "$OUT/$NAME-squashfs-fullimage.img" ;;
	*-initramfs-kernel.bin)    cp "$f" "$OUT/$NAME-initramfs-kernel.bin" ;;
	esac
done
[ -f "$OUT/$NAME-squashfs-sysupgrade.bin" ] || die "нет sysupgrade-образа"

manifest="$(ls "$TGT"/*.manifest 2>/dev/null | head -n1 || true)"
[ -n "$manifest" ] && cp "$manifest" "$OUT/$NAME.manifest"

binfo=()
for f in config.buildinfo feeds.buildinfo version.buildinfo; do
	[ -f "$TGT/$f" ] && binfo+=("$f")
done
[ ${#binfo[@]} -gt 0 ] && tar -czf "$OUT/$NAME-buildinfo.tar.gz" -C "$TGT" "${binfo[@]}"

sdk="$(ls "$TGT"/openwrt-sdk-*.tar.xz 2>/dev/null | head -n1 || true)"
[ -n "$sdk" ] && cp "$sdk" "$OUT/$NAME-sdk.tar.xz"

# Пакеты: структура как на downloads.openwrt.org, чтобы workflow фида
# просто разложил архив в корень релиза фида.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/targets/intel_mips/xrx500"
[ -d "$TGT/packages" ] && cp -a "$TGT/packages" "$stage/targets/intel_mips/xrx500/"
[ -d "$BIN/packages" ] && cp -a "$BIN/packages" "$stage/"
tar -czf "$OUT/$NAME-packages.tar.gz" -C "$stage" .

( cd "$OUT" && sha256sum -- * > sha256sums )
log "Артефакты: $OUT"
ls -la "$OUT"
