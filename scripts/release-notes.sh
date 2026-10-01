#!/bin/bash
#
# Текст релиза GitHub: что внутри, как прошить, адрес фида, изменения.
#   scripts/release-notes.sh <тег> <каталог с артефактами>
#
set -euo pipefail

TAG="${1:?тег}"
DIR="${2:?каталог}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OWNER="${GITHUB_REPOSITORY_OWNER:-Aleck59}"
REPO="${GITHUB_REPOSITORY:-Aleck59/ax50-openwrt}"
PAGES="https://$(echo "$OWNER" | tr 'A-Z' 'a-z').github.io/${REPO#*/}"

prev="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 "$TAG^" 2>/dev/null || true)"

manifest="$(ls "$DIR"/*.manifest 2>/dev/null | head -n1 || true)"
pkgver() { [ -n "$manifest" ] && awk -v p="$1" '$1 == p { print $3; exit }' "$manifest"; }

cat <<EOF
Прошивка для **TP-Link Archer AX50 v1** на базе prplWrt (OpenWrt 19.07 + ядро Intel/MaxLinear 4.9).

| Файл | Назначение |
|---|---|
| \`ax50-openwrt-$TAG-squashfs-sysupgrade.bin\` | обновление уже установленной прошивки (LuCI → Система → Восстановление/обновление, или \`sysupgrade\`) |
| \`ax50-openwrt-$TAG-squashfs-fullimage.img\` | первая установка из U-Boot по TFTP (см. [docs/flashing.md](https://github.com/$REPO/blob/$TAG/docs/flashing.md)) |
| \`ax50-openwrt-$TAG-initramfs-kernel.bin\` | загрузка в ОЗУ без записи во флеш — для проверки |
| \`ax50-openwrt-$TAG-sdk.tar.xz\` | SDK для сборки пакетов |
| \`ax50-openwrt-$TAG-packages.tar.gz\` | модули ядра и пакеты этой сборки |

**Версии:** AdGuard Home $(pkgver adguardhome || echo "—"), zapret $(pkgver zapret || echo "—"), LuCI тема footstrap $(pkgver luci-theme-footstrap || echo "—").

**Фид пакетов** собирается отдельным workflow и публикуется по адресу
$PAGES/releases/$TAG/ — он уже прописан в прошивке (\`/etc/opkg/distfeeds.conf\`),
так что \`opkg update && opkg install <пакет>\` работает сразу.

> ⚠️ Не стирайте MTD-разделы \`calibration\`, \`uboot\`, \`ubootconfigA/B\` — в них калибровка Wi-Fi и загрузчик.
> Перед первой установкой сделайте резервную копию (\`ax50-backup\` после установки, или из U-Boot).

EOF

if [ -n "$prev" ]; then
	echo "### Изменения с $prev"
	echo
	git -C "$REPO_ROOT" log --no-merges --format='- %s' "$prev..$TAG" 2>/dev/null || true
else
	echo "### Первый релиз"
fi

echo
echo "SHA-256 — в файле \`sha256sums\`."
