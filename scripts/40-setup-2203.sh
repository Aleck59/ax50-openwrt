#!/bin/bash
#
# ЭКСПЕРИМЕНТ: prplWrt на базе OpenWrt 22.03 (userspace 22.03 + вендорское ядро 4.9).
#
# Смысл затеи. Полный порт BSP на ядро 5.10 нереален в одиночку: вендорский форк
# содержит 1183 новых файла и 437 изменённых относительно ванильного 4.9.206,
# из них arch/mips/lantiq — 44 новых файла (поддержки GRX500 в mainline нет
# вообще: в 5.10 из Lantiq только Amazon SE, XWAY и FALCON), а
# drivers/net/ethernet/lantiq — 113 новых файлов, весь GSWIP-3.1 и датапат.
#
# Но есть обходной путь, которым живёт сам prplWrt на 19.07: взять свежий
# userspace и оставить вендорское ядро. Этот скрипт делает то же самое с 22.03 —
# musl 1.2, GCC 11.2, современные пакеты, при этом ядро 4.9.206 от MaxLinear.
#
# Что пришлось выяснить опытным путём (иначе таргет молча не работает):
#
#   1. В 22.03 есть только include/kernel-5.10. Таргет intel_mips объявляет
#      KERNEL_PATCHVER 4.4 на верхнем уровне и 4.9 в субтаргете xrx500, поэтому
#      без файлов include/kernel-4.4 и include/kernel-4.9 его Makefile падает
#      с "Missing kernel version/hash file", таргет НЕ попадает в .targetinfo,
#      а make defconfig молча скатывается на ath79. Никакой ошибки не видно.
#
#   2. В 22.03 нет target/linux/generic/{config,backport,hack,pending}-4.9.
#      Без generic-конфига ядро получает почти пустую конфигурацию и kconfig
#      начинает спрашивать тип машины MIPS из 46 вариантов.
#
#   3. Дальше всплывают новые символы конфигурации без умолчаний — их надо
#      гасить итеративно, как это делает scripts/lib/fix-kernel-build.sh.
#
# Статус эксперимента — см. docs/09-openwrt-2203.md
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build}"
TREE_1907="$BUILD_DIR/prplwrt"
TREE="$BUILD_DIR/openwrt-2203"

OPENWRT_URL="${OPENWRT_URL:-https://git.openwrt.org/openwrt/openwrt.git}"
OPENWRT_BRANCH="${OPENWRT_BRANCH:-openwrt-22.03}"

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!!! %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" != 0 ] || die "не запускайте сборку от root"
[ -d "$TREE_1907" ] || die "сначала соберите ветку 19.07: ./scripts/10-setup-tree.sh
Из неё берутся таргет intel_mips и generic-слой ядра 4.9."

mkdir -p "$BUILD_DIR"

log "1/5 База OpenWrt 22.03"
[ -d "$TREE/.git" ] || git clone --depth 1 -b "$OPENWRT_BRANCH" "$OPENWRT_URL" "$TREE"
git -C "$TREE" log --oneline -1

log "2/5 Файлы описания ядер 4.4 и 4.9 (без них таргет молча выпадает)"
# Ядро берётся из git по CONFIG_KERNEL_GIT_REF, поэтому хеш тарболла не важен —
# важно само наличие файла, иначе include/kernel-version.mk обрывает разбор.
printf 'LINUX_VERSION-4.4 = .302\nLINUX_KERNEL_HASH-4.4.302 = %s\n' "$(printf '0%.0s' {1..64})" \
	> "$TREE/include/kernel-4.4"
printf 'LINUX_VERSION-4.9 = .206\nLINUX_KERNEL_HASH-4.9.206 = %s\n' "$(printf '0%.0s' {1..64})" \
	> "$TREE/include/kernel-4.9"

log "3/5 Таргет intel_mips из дерева 19.07"
rm -rf "$TREE/target/linux/intel_mips"
cp -a "$TREE_1907/feeds/feed_target_mips/intel_mips" "$TREE/target/linux/intel_mips"

log "4/5 generic-слой ядра 4.9"
for d in config-4.9 backport-4.9 hack-4.9 pending-4.9; do
	[ -e "$TREE_1907/target/linux/generic/$d" ] || continue
	rm -rf "$TREE/target/linux/generic/$d"
	cp -a "$TREE_1907/target/linux/generic/$d" "$TREE/target/linux/generic/"
	echo "  перенесён $d"
done

log "5/5 Конфигурация"
cat > "$TREE/.config" <<CFG
CONFIG_TARGET_intel_mips=y
CONFIG_TARGET_intel_mips_xrx500=y
CONFIG_TARGET_intel_mips_xrx500_DEVICE_TPLINK_AX50=y
CONFIG_DEVEL=y
CONFIG_KERNEL_GIT_CLONE_URI="https://gitlab.com/prpl-foundation/intel/linux.git"
CONFIG_KERNEL_GIT_DEPTH="1000"
CONFIG_KERNEL_GIT_REF="727acdb060410a936330a2456f641b9473bf5121"
CFG

# наше устройство
cp "$REPO_ROOT/device/dts/tplink_ax50.dts" "$TREE/target/linux/intel_mips/dts/"
cp "$REPO_ROOT/device/image/ax50.mk" "$TREE/target/linux/intel_mips/image/"
grep -q '^-include ax50.mk' "$TREE/target/linux/intel_mips/image/Makefile" \
	|| printf -- '-include ax50.mk\n' >> "$TREE/target/linux/intel_mips/image/Makefile"

# переиспользуем уже скачанное вендорское ядро, чтобы не клонировать 1 ГБ заново
mkdir -p "$TREE/dl"
cp -n "$TREE_1907"/dl/linux-gitlab_com_prpl*.tar.xz "$TREE/dl/" 2>/dev/null || true

cd "$TREE"
rm -rf tmp
make defconfig >/dev/null

grep -q '^CONFIG_TARGET_BOARD="intel_mips"' .config \
	&& echo "таргет intel_mips выбран" \
	|| die "таргет не выбрался — проверьте include/kernel-4.4 и include/kernel-4.9"

cat <<MSG

Дерево 22.03 готово: $TREE

Дальше:
  cd $TREE && make -j\$(nproc) toolchain/install
  cd $TREE && make -j\$(nproc) target/linux/compile

Новые символы конфигурации ядра гасятся так же, как в ветке 19.07 —
см. scripts/lib/fix-kernel-build.sh и docs/09-openwrt-2203.md
MSG
