#!/bin/bash
#
# Готовит дерево к сборке ВСЕХ пакетов на вендорском ядре 4.9.
#
# Зачем это нужно. Когда включается CONFIG_ALL, в сборку попадают все kmod-пакеты
# OpenWrt. Часть из них рассчитана на ядро, собранное с generic-патчами OpenWrt,
# а у нас ядро Intel/MaxLinear со своим набором патчей. Возникают два вида поломок,
# и обе валят сборку целиком, потому что происходят на шаге target/linux/compile,
# который IGNORE_ERRORS=m не покрывает:
#
#   1. Новый символ конфигурации ядра без умолчания. kmod включает подсистему,
#      внутри неё появляется символ, о котором конфиг таргета ничего не знает,
#      и silentoldconfig упирается в вопрос при перенаправленном вводе:
#         "Atmel WILC1000 SDIO (WILC1000_SDIO) [N/m/?] (NEW) aborted!"
#      Лечится дописыванием "# CONFIG_<СИМВОЛ> is not set" в конфиг таргета.
#
#   2. kmod ссылается на исходник, которого в вендорском ядре нет:
#         "No rule to make target 'drivers/misc/owl-loader.c'"
#      Лечится отключением самого пакета kmod.
#
# Скрипт крутит цикл: собрать -> разобрать ошибку -> починить -> собрать снова.
#
set -uo pipefail

TREE="${1:?использование: fix-kernel-build.sh <путь к дереву prplwrt> [макс. итераций]}"
MAX="${2:-40}"

cd "$TREE"
KCFG="feeds/feed_target_mips/intel_mips/config-4.9"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

[ -f "$KCFG" ] || { echo "не найден конфиг ядра таргета: $KCFG" >&2; exit 1; }

for i in $(seq 1 "$MAX"); do
	if make -j1 V=s target/linux/compile > "$LOG" 2>&1; then
		echo "[$i] модули ядра собираются"
		exit 0
	fi

	# случай 1: новый символ конфигурации ядра
	sym=$(grep -oE '\(([A-Z0-9_]+)\) \[[^]]*\] \(NEW\)' "$LOG" | head -1 | sed -n 's/^(\([A-Z0-9_]*\)).*/\1/p')
	if [ -n "$sym" ]; then
		echo "[$i] новый символ ядра $sym — отключаю"
		grep -q "^# CONFIG_$sym is not set$" "$KCFG" || echo "# CONFIG_$sym is not set" >> "$KCFG"
		rm -rf tmp; make defconfig >/dev/null 2>&1
		continue
	fi

	# случай 2: kmod требует отсутствующий в вендорском ядре исходник
	missing=$(grep -oE "No rule to make target '[^']+'" "$LOG" | head -1 | sed "s/.*'\(.*\)'/\1/")
	if [ -n "$missing" ]; then
		base=$(basename "$missing" | sed 's/\.[co]$//')
		pkg=$(python3 - "$base" <<'PY'
import glob, re, sys
base = sys.argv[1]
best = None
for f in glob.glob("package/kernel/linux/modules/*.mk"):
    cur = None
    for line in open(f, errors="replace"):
        m = re.match(r'define KernelPackage/([\w.+-]+)', line)
        if m:
            cur = m.group(1)
        if cur and base in line:
            best = cur
            break
    if best:
        break
print(best or "")
PY
)
		if [ -n "$pkg" ]; then
			echo "[$i] $missing отсутствует в ядре — отключаю пакет kmod-$pkg"
			sed -i "/^CONFIG_PACKAGE_kmod-$pkg=/d" .config
			echo "# CONFIG_PACKAGE_kmod-$pkg is not set" >> .config
			rm -rf tmp; make defconfig >/dev/null 2>&1
			continue
		fi
		echo "[$i] не нашёл, какой kmod тянет $missing — разбирайтесь вручную" >&2
		tail -30 "$LOG" >&2
		exit 1
	fi

	echo "[$i] сборка модулей ядра упала по неизвестной причине:" >&2
	grep -nE 'Error [0-9]|error:' "$LOG" | head -10 >&2
	exit 1
done

echo "не уложились в $MAX итераций" >&2
exit 1
