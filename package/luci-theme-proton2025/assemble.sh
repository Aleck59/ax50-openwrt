#!/bin/sh
#
# Собирает раскладку пакета LuCI (htdocs/, luasrc/, root/) темы Proton2025
# для LuCI 19.07 из исходников апстрима и слоя совместимости compat/.
#
#   assemble.sh <исходники апстрима> <compat> <результат>
#
# Используется в Build/Prepare пакета и тестовым стендом.
#
set -e

SRC="$1"
COMPAT="$2"
OUT="$3"

[ -f "$SRC/ucode/template/themes/proton2025/header.ut" ] || {
	echo "assemble: нет $SRC/ucode/template/themes/proton2025/header.ut" >&2
	exit 1
}

mkdir -p "$OUT"
cp -R "$SRC/htdocs" "$OUT/htdocs"
cp -R "$SRC/root" "$OUT/root"

# rpcd-модули апстрима — на ucode (нет в 19.07); их Lua-порты лежат в
# compat/root/usr/libexec/rpcd
rm -rf "$OUT/root/usr/share/rpcd/ucode"

# Шаблоны (Lua вместо ucode) и rpcd-плагины
cp -R "$COMPAT/." "$OUT/"

# Таблицы LuCI 19.07 — <div class="table|tr|td|th">, а CSS и скрипты темы
# адресуют <table>/<tr>/<td>/<th>: переписываем селекторы (см. divtables.py)
HERE="$(cd "$(dirname "$0")" && pwd)"
find "$OUT/htdocs" -name '*.css' -o -name '*.js' | grep -v '/i18n/' | \
	xargs python3 "$HERE/divtables.py" "$OUT/luasrc/view/themes/proton2025/header.htm"

# Лицензии апстрима — в пакет
mkdir -p "$OUT/root/usr/share/licenses/luci-theme-proton2025"
cp "$SRC/LICENSE" "$OUT/root/usr/share/licenses/luci-theme-proton2025/LICENSE"

echo "assemble: готово -> $OUT"
