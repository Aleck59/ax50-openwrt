#!/bin/bash
#
# Готовит дерево prplWrt и добавляет в него поддержку TP-Link Archer AX50 v1.
#
# Что делает:
#   1. клонирует базу prplWrt (OpenWrt 19.07-SNAPSHOT с сохранённой поддержкой ядра 4.9);
#   2. кладёт наш профиль device/profiles/ax50.yml в prplwrt/profiles/;
#   3. запускает штатный prplWrt-механизм gen_config.py — он подтягивает фиды
#      Intel/MaxLinear (таргет intel_mips, датапат, PPA, Wi-Fi iwlwav) и ставит их;
#   4. внедряет наши DTS и image-рецепт в установленный таргет;
#   5. формирует .config под устройство TPLINK_AX50.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build}"
TREE="$BUILD_DIR/prplwrt"

PRPLWRT_URL="${PRPLWRT_URL:-https://gitlab.com/aparcar/prplwrt.git}"
PRPLWRT_BRANCH="${PRPLWRT_BRANCH:-prplwrt}"

PROFILE="ax50"
DEVICE_SYM="CONFIG_TARGET_intel_mips_xrx500_DEVICE_TPLINK_AX50"

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!!! %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" != 0 ] || die "не запускайте сборку от root — OpenWrt это не поддерживает"

preflight() {
	local bad=0

	command -v gawk >/dev/null || { echo "нет gawk"; bad=1; }
	command -v git  >/dev/null || { echo "нет git";  bad=1; }
	command -v make >/dev/null || { echo "нет make"; bad=1; }
	command -v perl >/dev/null || { echo "нет perl"; bad=1; }
	python3 -c "import yaml" 2>/dev/null || { echo "нет python3-yaml"; bad=1; }

	# OpenWrt 19.07 требует именно Python 2.x
	if ! { python2.7 -V 2>&1 | grep -q "Python 2.7"; } &&
	   ! { python2   -V 2>&1 | grep -q "Python 2";   } &&
	   ! { python    -V 2>&1 | grep -q "Python 2";   }; then
		echo "нет Python 2.x (в Ubuntu 24.04 его уже нет в репозиториях)"
		bad=1
	fi

	# prereq-build.mk из 19.07 распознаёт только GCC 4.8-9.x
	local gccver
	gccver="$(gcc -dumpversion 2>/dev/null || echo 0)"
	case "$gccver" in
		4.[89]*|[5-9]|[5-9].*) ;;
		*) echo "GCC $gccver не подходит: OpenWrt 19.07 понимает только 4.8-9.x"; bad=1 ;;
	esac

	if [ "$bad" != 0 ]; then
		cat >&2 <<'HINT'

Хост не подходит для сборки prplWrt (база OpenWrt 19.07).
Самый простой путь — собрать в контейнере Ubuntu 20.04:

    ./scripts/docker-build.sh setup
    ./scripts/docker-build.sh build

Либо доустановите недостающее вручную (см. docs/03-build.md).
Проверку можно пропустить на свой страх и риск: SKIP_PREFLIGHT=1
HINT
		exit 1
	fi
}

[ "${SKIP_PREFLIGHT:-0}" = 1 ] || preflight

mkdir -p "$BUILD_DIR"

log "1/5 База prplWrt"
if [ -d "$TREE/.git" ]; then
	echo "уже склонировано: $TREE"
else
	git clone --depth 1 -b "$PRPLWRT_BRANCH" "$PRPLWRT_URL" "$TREE"
fi
git -C "$TREE" log --oneline -1

log "2/5 Профиль сборки"
mkdir -p "$TREE/profiles"
cp -v "$REPO_ROOT/device/profiles/$PROFILE.yml" "$TREE/profiles/"

log "3/5 Фиды Intel/MaxLinear (gen_config.py) — это долго, идут клоны нескольких репозиториев"
cd "$TREE"
# gen_config.py на этом шаге ещё не знает про наше устройство: финальный
# make defconfig выкинет символ TPLINK_AX50. Это нормально, чиним на шаге 5.
./scripts/gen_config.py "$PROFILE" || die "gen_config.py упал — смотрите вывод выше"

# gen_config.py строит индексы фидов через make, а тот сначала прогоняет
# проверку хостовых зависимостей. Если она падает, индексы получаются пустыми,
# внешний таргет молча не устанавливается ("No feed for package 'intel_mips'"),
# и defconfig скатывается на дефолтный ath79. Поэтому переиндексируем явно
# и доустанавливаем — операция идемпотентная и быстрая.
log "3b/5 Переиндексация фидов и установка внешнего таргета"
./scripts/feeds update -i

for f in feed_target_mips feed_datapath feed_ppa feed_gphy_firmware \
         feed_switch_api feed_wlan_6x feed_opensource_apps feed_pending; do
	[ -d "feeds/$f" ] && ./scripts/feeds install -a -f -p "$f" >/dev/null
done
./scripts/feeds install intel_mips

TARGET_DIR="$TREE/feeds/feed_target_mips/intel_mips"
[ -d "$TARGET_DIR" ] || die "таргет intel_mips не установился: нет $TARGET_DIR"
[ -L "$TREE/target/linux/intel_mips" ] || \
	die "target/linux/intel_mips не создан — внешний таргет не установился"

log "4/5 Внедряем поддержку Archer AX50"
cp -v "$REPO_ROOT/device/dts/tplink_ax50.dts"  "$TARGET_DIR/dts/"
cp -v "$REPO_ROOT/device/image/ax50.mk"        "$TARGET_DIR/image/"

# подключаем ax50.mk из image/Makefile (идемпотентно)
if grep -q '^-\?include ax50.mk' "$TARGET_DIR/image/Makefile"; then
	echo "image/Makefile уже подключает ax50.mk"
else
	sed -i 's|^-include rax40.mk|-include rax40.mk\n-include ax50.mk|' "$TARGET_DIR/image/Makefile"
	grep -q '^-include ax50.mk' "$TARGET_DIR/image/Makefile" \
		|| printf -- '-include ax50.mk\n' >> "$TARGET_DIR/image/Makefile"
	echo "ax50.mk подключён"
fi

# файлы rootfs (uci-defaults и т.п.), если есть
if [ -d "$REPO_ROOT/device/files" ] && [ -n "$(ls -A "$REPO_ROOT/device/files" 2>/dev/null)" ]; then
	mkdir -p "$TREE/files"
	cp -a "$REPO_ROOT/device/files/." "$TREE/files/"
	echo "rootfs-оверлей скопирован в $TREE/files"
fi

log "5/5 Конфигурация под TPLINK_AX50"
cd "$TREE"
grep -q "^${DEVICE_SYM}=y" .config || echo "${DEVICE_SYM}=y" >> .config
rm -rf tmp
make defconfig >/dev/null

if grep -q "^${DEVICE_SYM}=y" .config; then
	echo "устройство TPLINK_AX50 выбрано"
	for p in kmod-iwlwav-driver-uci iwlwav-hostap-uci ltq-wlan-wave_6x-uci \
	         kmod-intel_eth_toe_drv_xrx500 ltq-gphy-fw-xrx5xx; do
		grep -q "^CONFIG_PACKAGE_$p=y" .config \
			&& echo "  пакет $p: ок" \
			|| echo "  ВНИМАНИЕ: пакет $p не выбран"
	done
else
	die "символ ${DEVICE_SYM} не пережил defconfig.
Обычно это значит, что ax50.mk не подхватился или в DTS ошибка.
Проверьте: $TARGET_DIR/image/Makefile и $TARGET_DIR/image/ax50.mk"
fi

cat <<MSG

Готово. Дерево: $TREE

Дальше:
  ./scripts/20-build.sh          # сборка
  (или вручную: cd $TREE && make -j\$(nproc) )

Поменять набор пакетов:  cd $TREE && make menuconfig
MSG
