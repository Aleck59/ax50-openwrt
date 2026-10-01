#!/bin/bash
#
# Готовит дерево сборки prplWrt с поддержкой TP-Link Archer AX50 v1.
#
#   1. клонирует prplWrt на закреплённом коммите (config/versions.env);
#   2. формирует feeds.conf (config/feeds.conf), обновляет фиды;
#   3. возвращает дерево и фиды в чистое состояние и накладывает patches/;
#   4. копирует поддержку платы (target/) во внешний таргет intel_mips;
#   5. ставит пакеты фидов и внешний таргет intel_mips;
#   6. копирует оверлей rootfs (files/).
#
# Скрипт идемпотентный: повторный запуск откатывает прошлые правки и
# применяет текущие, скачанное (dl/) и собранное (build_dir/) не трогает.
#
set -euo pipefail
. "$(dirname "$0")/lib.sh"

require_non_root
mkdir -p "$BUILD_DIR"

# Вернуть git-каталог к закреплённому состоянию, удалив свои правки
git_pristine() {
	git -C "$1" reset -q --hard
	git -C "$1" clean -q -fdx -e dl -e build_dir -e staging_dir -e bin \
		-e tmp -e logs -e feeds -e .config -e files -e package/feeds \
		-e target/linux/intel_mips -e .ccache
}

log "1/6 База prplWrt @ ${PRPLWRT_COMMIT:0:12}"
# init + fetch, а не clone: каталог может уже существовать — CI восстанавливает
# в него кэш загрузок (dl/) до подготовки дерева
if [ ! -d "$TREE/.git" ]; then
	mkdir -p "$TREE"
	git -C "$TREE" init -q
	git -C "$TREE" remote add origin "$PRPLWRT_URL"
	git -C "$TREE" fetch -q origin "$PRPLWRT_BRANCH"
else
	git -C "$TREE" fetch -q origin "$PRPLWRT_BRANCH" 2>/dev/null || true
fi
git -C "$TREE" checkout -q -f "$PRPLWRT_COMMIT"
git_pristine "$TREE"
git -C "$TREE" log --oneline -1

log "2/6 Фиды"
sed "s|@REPO_ROOT@|$REPO_ROOT|g" "$REPO_ROOT/config/feeds.conf" > "$TREE/feeds.conf"
cd "$TREE"
# Сначала вернуть фиды к чистому состоянию: update не переключает коммит,
# если в рабочей копии есть наши правки.
for d in feeds/*/; do
	[ -d "$d/.git" ] && git -C "$d" reset -q --hard && git -C "$d" clean -q -fdx
done
./scripts/feeds update -a

log "3/6 Патчи"
apply_patches prplwrt "$TREE"
while read -r type name _; do
	# src-link (свой фид) не патчится: это рабочая копия репозитория
	[ "$type" = src-git ] || continue
	[ -d "feeds/$name" ] && apply_patches "$name" "feeds/$name"
done < feeds.conf

log "4/6 Поддержка платы в таргете intel_mips"
TARGET_SRC="$TREE/feeds/feed_target_mips/intel_mips"
[ -d "$TARGET_SRC" ] || die "в фиде feed_target_mips нет каталога intel_mips"
cp -a "$REPO_ROOT/target/linux/intel_mips/." "$TARGET_SRC/"

log "5/6 Установка пакетов и внешнего таргета"
# Индексы надо перестроить: патчи и оверлей меняют Makefile пакетов и таргета
./scripts/feeds update -i
./scripts/feeds install -a -p packages >/dev/null
./scripts/feeds install -a -p luci >/dev/null
./scripts/feeds install -a -p routing >/dev/null
./scripts/feeds install -a -p telephony >/dev/null
# Фиды Intel и свой фид ставятся с -f: они переопределяют одноимённые пакеты
for f in feed_target_mips feed_datapath feed_ppa feed_gphy_firmware \
	feed_switch_api feed_wlan_6x feed_opensource_apps feed_pending ax50; do
	./scripts/feeds install -a -f -p "$f" >/dev/null
done
./scripts/feeds install intel_mips
[ -L target/linux/intel_mips ] || die "внешний таргет intel_mips не установился"
# Кэш метаданных (tmp/) собран до появления ссылки target/linux/intel_mips:
# kmod-ы из её modules.mk (kmod-usb-dwc3-grx500 и др.) в него не попали, а
# по времени изменения make кэш не обновит. Сбрасываем — make пересканирует.
rm -rf tmp

log "6/6 Оверлей rootfs"
rm -rf "$TREE/files"
if [ -d "$REPO_ROOT/files" ]; then
	cp -a "$REPO_ROOT/files" "$TREE/files"
fi

log "Дерево готово: $TREE"
echo "Дальше: scripts/configure.sh && scripts/build.sh"
