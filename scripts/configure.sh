#!/bin/bash
#
# Собирает .config из фрагментов config/*.config и проверяет результат.
#
# Переменные окружения:
#   VERSION=v1.2.3   номер версии прошивки (по умолчанию — из git describe)
#   WITH_KMODS=1     дополнительно собрать модули ядра для фида (config/kmods.config)
#   WITH_SDK=1       собрать SDK — его использует workflow фида пакетов
#   USIGN_KEY_FILE=… приватный ключ usign: подписывать индексы пакетов, а в
#                    прошивку положить открытый ключ и включить проверку подписи
#   FEED_URL=…       адрес фида opkg для этой прошивки; по умолчанию
#                    https://aleck59.github.io/ax50-openwrt/releases/<версия>
#
set -euo pipefail
. "$(dirname "$0")/lib.sh"

require_non_root
require_tree
cd "$TREE"

VERSION="${VERSION:-$(git -C "$REPO_ROOT" describe --tags --always --dirty 2>/dev/null || echo dev)}"
FEED_URL="${FEED_URL:-https://aleck59.github.io/ax50-openwrt/releases/$VERSION}"

log "Конфигурация: версия $VERSION, фид $FEED_URL"
{
	cat "$REPO_ROOT/config/image.config"
	[ "${WITH_KMODS:-0}" = 1 ] && cat "$REPO_ROOT/config/kmods.config"
	[ "${WITH_SDK:-0}" = 1 ] && echo "CONFIG_SDK=y"

	# Версия и адрес фида. Из CONFIG_VERSION_REPO base-files сам строит
	# /etc/opkg/distfeeds.conf по стандартной схеме OpenWrt:
	#   <repo>/targets/intel_mips/xrx500/packages  — модули ядра (workflow прошивки)
	#   <repo>/packages/<arch>/<фид>               — пакеты (workflow фида)
	cat <<-EOF
	CONFIG_IMAGEOPT=y
	CONFIG_VERSIONOPT=y
	CONFIG_VERSION_DIST="AX50-OpenWrt"
	CONFIG_VERSION_NUMBER="${VERSION#v}"
	CONFIG_VERSION_CODE="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
	CONFIG_VERSION_REPO="$FEED_URL"
	CONFIG_VERSION_MANUFACTURER="ax50-openwrt"
	CONFIG_VERSION_MANUFACTURER_URL="https://github.com/Aleck59/ax50-openwrt"
	CONFIG_VERSION_BUG_URL="https://github.com/Aleck59/ax50-openwrt/issues"
	CONFIG_VERSION_SUPPORT_URL="https://github.com/Aleck59/ax50-openwrt"
	CONFIG_VERSION_PRODUCT="Archer AX50 v1"
	CONFIG_VERSION_HWREV="v1"
	EOF

	if [ -n "${USIGN_KEY_FILE:-}" ]; then
		echo "CONFIG_SIGNED_PACKAGES=y"
	else
		echo "# CONFIG_SIGNED_PACKAGES is not set"
	fi
} > .config

# Ключ подписи: build system берёт key-build/key-build.pub из корня дерева
rm -f key-build key-build.pub
if [ -n "${USIGN_KEY_FILE:-}" ]; then
	install -m 600 "$USIGN_KEY_FILE" key-build
	python3 "$REPO_ROOT/scripts/usign-pubkey.py" key-build > key-build.pub
	echo "подпись пакетов включена, ключ $(sed -n 2p key-build.pub | cut -c1-16)…"
fi

make defconfig >/dev/null

# Всё, что явно запрошено как =y/=m, должно пережить defconfig: иначе пакет
# молча выпадает (опечатка, несобираемая зависимость, конфликт).
missing=0
while IFS= read -r line; do
	case "$line" in CONFIG_*=[ym]) ;; *) continue ;; esac
	if ! grep -qx "$line" .config; then
		# =m, превратившийся в =y, — это нормально (пакет нужен образу)
		[ "${line%=m}" != "$line" ] && grep -qx "${line%=m}=y" .config && continue
		warn "не выбрано: $line"
		missing=$((missing + 1))
	fi
done < <(cat "$REPO_ROOT/config/image.config"
	[ "${WITH_KMODS:-0}" = 1 ] && cat "$REPO_ROOT/config/kmods.config")

[ "$missing" = 0 ] || die "$missing символ(ов) конфигурации не выбрано — см. выше"

grep -q '^CONFIG_TARGET_intel_mips_xrx500_DEVICE_TPLINK_AX50=y' .config \
	|| die "устройство TPLINK_AX50 не выбрано (не подхватился tplink_ax50.mk?)"
log "Конфигурация готова: $(grep -c '^CONFIG_PACKAGE_.*=y' .config) пакетов в образе"
