#!/bin/bash
#
# Тестовый стенд LuCI 19.07: OpenWrt 19.07.10 x86_64 в Docker + Chromium.
# Нужен для проверки темы и LuCI-приложений без роутера.
#
#   tools/luci-bench/run.sh start            # поднять стенд на 127.0.0.1:8080
#   tools/luci-bench/run.sh theme            # поставить/обновить тему footstrap
#   tools/luci-bench/run.sh apps             # поставить luci-app-adguardhome/zapret (с заглушками)
#   tools/luci-bench/run.sh shot <путь> <png>   # скриншот страницы
#   tools/luci-bench/run.sh nav <путь...>       # переход по меню + ошибки консоли
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
WORK="${BENCH_DIR:-/tmp/luci-bench}"
REL=https://downloads.openwrt.org/releases/19.07.10
CHROME="${CHROME:-$(ls -d /opt/pw-browsers/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)}"
mkdir -p "$WORK/ipk"

po2lmo() {
	if [ ! -x "$WORK/po2lmo" ]; then
		local src="$REPO/build/prplwrt/feeds/luci/modules/luci-base/src"
		[ -d "$src" ] || { echo "нужно дерево сборки (scripts/prepare.sh) для po2lmo" >&2; exit 1; }
		rm -rf "$WORK/p2l" && cp -r "$src" "$WORK/p2l" && make -s -C "$WORK/p2l" po2lmo
		cp "$WORK/p2l/po2lmo" "$WORK/po2lmo"
	fi
	"$WORK/po2lmo" "$@"
}

node_deps() {
	[ -d "$WORK/node_modules/playwright" ] || \
		(cd "$WORK" && npm init -y >/dev/null && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install -s playwright@1.56)
	cp "$HERE"/shot.js "$HERE"/nav.js "$WORK/"
}

case "${1:-}" in
start)
	cd "$WORK"
	[ -f rootfs.tar.gz ] || curl -sS -o rootfs.tar.gz "$REL/targets/x86/64/openwrt-19.07.10-x86-64-generic-rootfs.tar.gz"
	for f in base luci packages; do
		[ -f "Packages-$f" ] || curl -sS -o "Packages-$f" "$REL/packages/x86_64/$f/Packages"
	done
	[ -f Packages-core ] || curl -sS -o Packages-core "$REL/targets/x86/64/packages/Packages"
	mkdir -p rootfs && tar xzf rootfs.tar.gz -C rootfs 2>/dev/null || true
	find rootfs/usr/lib/opkg/info -name "*.control" -exec basename {} .control \; > installed.txt
	python3 "$HERE/resolve.py" luci-compat luci-i18n-base-ru uhttpd-mod-ubus >/dev/null
	docker image inspect owrt1907 >/dev/null 2>&1 || docker import rootfs.tar.gz owrt1907 >/dev/null
	docker rm -f luci-bench >/dev/null 2>&1 || true
	docker run -d --name luci-bench --network host -v "$WORK/ipk:/ipk" -v "$HERE:/bench" owrt1907 \
		/bin/sh -c 'mkdir -p /var/run /var/lock; opkg install /ipk/*.ipk >/tmp/opkg.log 2>&1;
			cp /bench/rpcd-system /usr/libexec/rpcd/system; ubusd & sleep 1; rpcd & sleep 1;
			uci set luci.main.lang=ru; uci commit luci;
			exec uhttpd -f -p 127.0.0.1:8080 -h /www -x /cgi-bin -u /ubus -t 60 -T 30 -A 1 -n 3 -N 100 -R' >/dev/null
	sleep 6
	echo "стенд: http://127.0.0.1:8080/cgi-bin/luci/ (root без пароля)"
	;;
theme)
	out="$WORK/theme"; rm -rf "$out" "$WORK/fsout"
	src="$WORK/footstrap"
	ver="$(sed -n 's/^PKG_SOURCE_VERSION:=//p' "$REPO/package/luci-theme-footstrap/Makefile")"
	[ -d "$src/.git" ] || git clone -q https://github.com/VizzleTF/luci-theme-footstrap.git "$src"
	git -C "$src" fetch -q origin && git -C "$src" checkout -q "$ver"
	sh "$REPO/package/luci-theme-footstrap/assemble.sh" "$src" "$REPO/package/luci-theme-footstrap/compat" "$WORK/fsout" bench >/dev/null
	mkdir -p "$out/www" "$out/usr/lib/lua/luci/i18n"
	cp -R "$WORK/fsout/htdocs/." "$out/www/"
	cp -R "$WORK/fsout/luasrc/." "$out/usr/lib/lua/luci/"
	cp -R "$WORK/fsout/root/." "$out/"
	po2lmo "$REPO/package/luci-theme-footstrap/po/ru/footstrap.po" "$out/usr/lib/lua/luci/i18n/footstrap.ru.lmo"
	docker cp "$out/." luci-bench:/
	docker exec luci-bench sh -c 'sh /etc/uci-defaults/30_luci-theme-footstrap; uci set luci.main.mediaurlbase=/luci-static/footstrap; uci commit luci; rm -rf /tmp/luci-*'
	echo "тема установлена"
	;;
apps)
	out="$WORK/apps"; rm -rf "$out"
	mkdir -p "$out/www/luci-static/resources/view" "$out/usr/lib/lua/luci/i18n" "$out/etc/config" \
		"$out/etc/init.d" "$out/opt/zapret/ipset" "$out/usr/bin" "$out/usr/share"
	for a in luci-app-adguardhome luci-app-zapret; do
		cp -R "$REPO/package/$a/htdocs/." "$out/www/"
		cp -R "$REPO/package/$a/root/usr/share/." "$out/usr/share/"
		for po in "$REPO/package/$a"/po/ru/*.po; do
			po2lmo "$po" "$out/usr/lib/lua/luci/i18n/$(basename "$po" .po).ru.lmo"
		done
	done
	cp "$REPO/package/adguardhome/files/adguardhome.config" "$out/etc/config/adguardhome"
	cp "$REPO/package/zapret/files/config" "$out/opt/zapret/config"
	cp "$REPO/package/zapret/files/zapret-hosts-user.txt" "$out/opt/zapret/ipset/"
	printf '#!/bin/sh\necho "AdGuard Home, version v0.0.0-bench"\n' > "$out/usr/bin/AdGuardHome"
	printf '#!/bin/sh\ncase "$1" in enabled) exit 0;; *) echo "$0 $1";; esac\n' > "$out/etc/init.d/zapret"
	cp "$out/etc/init.d/zapret" "$out/etc/init.d/adguardhome"
	chmod +x "$out/usr/bin/AdGuardHome" "$out"/etc/init.d/*
	docker cp "$out/." luci-bench:/
	docker exec luci-bench sh -c 'killall rpcd; rpcd & sleep 1; rm -rf /tmp/luci-*'
	echo "приложения установлены"
	;;
shot)
	node_deps; shift; (cd "$WORK" && CHROME="$CHROME" node shot.js "$@") ;;
nav)
	node_deps; shift; (cd "$WORK" && CHROME="$CHROME" node nav.js "$@") ;;
*)
	sed -n '3,13p' "$0"; exit 1 ;;
esac
