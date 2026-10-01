#!/bin/sh
#
# Собирает раскладку пакета LuCI (htdocs/, luasrc/, root/) темы footstrap
# для LuCI 19.07 из исходников апстрима и слоя совместимости compat/.
#
#   assemble.sh <исходники апстрима> <compat> <результат> [версия]
#
# Используется в Build/Prepare пакета и тестовым стендом.
#
set -e

SRC="$1/luci-theme-footstrap"
COMPAT="$2"
OUT="$3"
VERSION="${4:-}"

[ -f "$SRC/build-css.sh" ] || { echo "assemble: нет $SRC/build-css.sh" >&2; exit 1; }

mkdir -p "$OUT"

# CSS: апстримный конкатенатор (cat + awk)
sh "$SRC/build-css.sh" "$OUT/htdocs/luci-static/footstrap/cascade.css"

cp -R "$SRC/htdocs/." "$OUT/htdocs/"
cp -R "$SRC/root" "$OUT/root"

# Шаблоны (Lua вместо ucode), контроллер и модуль совместимости
cp -R "$COMPAT/." "$OUT/"

# Модулям, использующим API LuCI 21.02+ (ui.RangeSlider, L.itemlist),
# сначала нужен fs-compat
for f in fs-appearance.js menu-footstrap-common.js menu-footstrap.js fs-overview.js; do
	js="$OUT/htdocs/luci-static/resources/$f"
	[ -f "$js" ] || continue
	grep -q "'require fs-compat'" "$js" && continue
	sed -i "0,/^'use strict';/s//'use strict';\n'require fs-compat';/" "$js"
done

# Версия в «Система → Footstrap» (по умолчанию тема показывает «dev»)
[ -n "$VERSION" ] && sed -i "s/'0\.0\.0-dev'/'$VERSION'/" \
	"$OUT/htdocs/luci-static/resources/fs-version.js"

echo "assemble: готово -> $OUT"
