#!/bin/bash
#
# Сборка фида opkg через SDK — основа workflow 2 (packages.yml).
#
#   scripts/feed-build.sh <sdk.tar.xz> <packages.tar.gz> <тег> <каталог сайта>
#
# 1. Распаковывает SDK, собранный workflow 1 вместе с прошивкой: тот же
#    тулчейн, те же библиотеки — пакеты гарантированно совместимы с образом.
# 2. Ставит фиды на тех же коммитах, что и прошивка (feeds.conf.default SDK),
#    накладывает patches/, собирает пакеты из config/feed-packages.txt.
# 3. Раскладывает в <сайт>/releases/<тег>/ по схеме downloads.openwrt.org:
#      targets/intel_mips/xrx500/packages/  модули ядра и пакеты таргета
#      packages/<arch>/<фид>/              пакеты (поверх — собранные SDK)
#    и перестраивает индексы (с подписью usign, если задан USIGN_KEY_FILE).
#
set -euo pipefail
. "$(dirname "$0")/lib.sh"

SDK_TAR="$(readlink -f "${1:?sdk.tar.xz}")"
PKGS_TAR="$(readlink -f "${2:?packages.tar.gz}")"
TAG="${3:?тег}"
SITE="${4:?каталог сайта}"
SDK="$BUILD_DIR/sdk"
DEST="$SITE/releases/$TAG"

require_non_root

log "1/5 SDK"
rm -rf "$SDK"
mkdir -p "$SDK"
tar -xJf "$SDK_TAR" -C "$SDK" --strip-components=1
cd "$SDK"

# Фиды на коммитах сборки прошивки. Свой фид (src-link) указывает на
# /work/package — в контейнере сборки это и есть этот репозиторий.
cp feeds.conf.default feeds.conf
grep -q '^src-git base ' feeds.conf || \
	sed -i "1i src-git base $PRPLWRT_URL^$PRPLWRT_COMMIT" feeds.conf
grep -q '^src-link ax50 ' feeds.conf || echo "src-link ax50 $REPO_ROOT/package" >> feeds.conf
sed -i "s|^src-link ax50 .*|src-link ax50 $REPO_ROOT/package|" feeds.conf
cat feeds.conf

log "2/5 Фиды и патчи"
./scripts/feeds update -a
apply_patches prplwrt feeds/base
while read -r type name _; do
	[ "$type" = src-git ] && [ -d "feeds/$name" ] && apply_patches "$name" "feeds/$name"
done < feeds.conf
./scripts/feeds update -i
./scripts/feeds install -a >/dev/null
for f in feed_wlan_6x feed_opensource_apps ax50; do
	[ -d "feeds/$f" ] || [ -L "feeds/$f" ] && ./scripts/feeds install -a -f -p "$f" >/dev/null
done

log "3/5 Конфигурация"
cat > .config <<-EOF
	# CONFIG_ALL_NONSHARED is not set
	# CONFIG_ALL_KMODS is not set
	# CONFIG_ALL is not set
	CONFIG_LUCI_LANG_ru=y
	CONFIG_AUTOREMOVE=y
EOF
rm -f key-build key-build.pub
if [ -n "${USIGN_KEY_FILE:-}" ]; then
	install -m 600 "$USIGN_KEY_FILE" key-build
	python3 "$REPO_ROOT/scripts/usign-pubkey.py" key-build > key-build.pub
	echo "CONFIG_SIGNED_PACKAGES=y" >> .config
else
	echo "# CONFIG_SIGNED_PACKAGES is not set" >> .config
fi
make defconfig >/dev/null

# Раскрываем шаблоны ("luci-app-*") по списку доступных пакетов
avail="$(grep -h '^Package: ' tmp/.packageinfo | awk '{print $2}' | sort -u)"
want=0 missing=""
while read -r p _; do
	case "$p" in ''|'#'*) continue ;; esac
	if [ "${p%\*}" != "$p" ]; then
		list="$(echo "$avail" | grep "^${p%\*}" || true)"
	else
		list="$(echo "$avail" | grep -x "$p" || true)"
	fi
	[ -n "$list" ] || { missing="$missing $p"; continue; }
	for q in $list; do
		echo "CONFIG_PACKAGE_$q=m" >> .config
		want=$((want + 1))
	done
done < "$REPO_ROOT/config/feed-packages.txt"
[ -z "$missing" ] || warn "нет в фидах:$missing"
make defconfig >/dev/null
echo "запрошено пакетов: $want, выбрано с зависимостями: $(grep -c '^CONFIG_PACKAGE_.*=m' .config)"

log "4/5 Сборка пакетов"
make -j"$JOBS" download IGNORE_ERRORS="n m y" || true
make -j"$JOBS" package/compile IGNORE_ERRORS="n m y" || {
	warn "часть пакетов не собралась — повтор однопоточно для журнала"
	make -j1 package/compile IGNORE_ERRORS="n m y" || true
}

ARCH="$(ls bin/packages | head -n1)"
[ -n "$ARCH" ] || die "SDK ничего не собрал"

log "5/5 Фид: $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"
tar -xzf "$PKGS_TAR" -C "$DEST"
mkdir -p "$DEST/packages/$ARCH"
cp -a bin/packages/"$ARCH"/. "$DEST/packages/$ARCH/"

USIGN="$SDK/staging_dir/host/bin/usign"
for dir in $(find "$DEST" -name '*.ipk' -printf '%h\n' | sort -u); do
	(
		cd "$dir"
		rm -f Packages Packages.gz Packages.sig Packages.manifest
		"$SDK/scripts/ipkg-make-index.sh" . > Packages.manifest 2>/dev/null
		grep -vE '^(Maintainer|LicenseFiles|Source|SourceName|Require)' Packages.manifest > Packages
		gzip -9nc Packages > Packages.gz
		if [ -f "$SDK/key-build" ]; then
			"$USIGN" -S -m Packages -s "$SDK/key-build"
		fi
	)
	echo "  ${dir#"$DEST"/}: $(grep -c '^Package:' "$dir/Packages") пакетов"
done
[ -f "$SDK/key-build.pub" ] && cp "$SDK/key-build.pub" "$DEST/usign.pub"
rm -f "$SDK/key-build"

total="$(find "$DEST" -name '*.ipk' | wc -l)"
echo "Всего в фиде: $total пакетов, $(du -sh "$DEST" | cut -f1)"
