#!/bin/bash
#
# Готовит дерево к сборке ВСЕХ пакетов на вендорском ядре 4.9.
#
# Зачем. При CONFIG_ALL в сборку попадают все kmod-пакеты OpenWrt, рассчитанные
# на ядро с generic-патчами OpenWrt. У нас ядро Intel/MaxLinear со своим набором
# патчей, поэтому часть kmod ломается. Беда в том, что ломается не отдельный
# пакет, а целые шаги target/linux/compile и package/kernel/linux/compile —
# один сбойный kmod обрывает сборку всех остальных, и IGNORE_ERRORS=m тут
# не помогает: он покрывает только сборку обычных пакетов.
#
# Скрипт крутит цикл «собрать → разобрать ошибку → отключить виновника → собрать
# снова» и умеет четыре известных случая:
#
#   1. Новый символ конфигурации ядра без умолчания:
#        "Atmel WILC1000 SDIO (WILC1000_SDIO) [N/m/?] (NEW) aborted!"
#      → дописываем "# CONFIG_<символ> is not set" в конфиг ядра таргета.
#
#   2. kmod требует исходник, которого в вендорском ядре нет:
#        "No rule to make target 'drivers/misc/owl-loader.c'"
#      → находим по имени файла, какой KernelPackage его тянет, и отключаем.
#
#   3. kmod не находит символы другого модуля:
#        "Package kmod-video-videobuf2 is missing dependencies for the following
#         libraries: dma-shared-buffer.ko"
#      → отключаем этот kmod.
#
#   4. Падение на сборке конкретного .ipk — имя пакета берём из пути.
#
set -uo pipefail

TREE="${1:?использование: fix-kernel-build.sh <путь к дереву prplwrt> [макс. итераций]}"
MAX="${2:-120}"

cd "$TREE"
KCFG="feeds/feed_target_mips/intel_mips/config-4.9"
LOG="$(mktemp)"
DISABLED="$TREE/.packages-disabled"
trap 'rm -f "$LOG"' EXIT

[ -f "$KCFG" ] || { echo "не найден конфиг ядра таргета: $KCFG" >&2; exit 1; }
: > "$DISABLED"

# Отключить пакет вместе со всеми, кто от него зависит.
#
# Просто убрать пакет из .config недостаточно: OpenWrt превращает зависимость
# вида "+foo" в "select PACKAGE_foo", поэтому любой оставшийся зависимый пакет
# тут же включает его обратно, и цикл починки крутится вечно на одном месте.
# Поэтому вместе с виновником гасим и всех, кто на него ссылается, транзитивно.
disable_pkg() {
	local pkg="$1" list p n=0
	[ -n "$pkg" ] || return 1

	list=$(python3 - "$pkg" <<'PYEOF'
import os, sys
root = sys.argv[1]
info = "tmp/.packageinfo"
deps = {}
if os.path.exists(info):
    cur = None
    for line in open(info, errors="replace"):
        if line.startswith("Package:"):
            parts = line.split(None, 1)
            cur = parts[1].strip() if len(parts) > 1 else None
        elif line.startswith("Depends:") and cur:
            parts = line.split(None, 1)
            if len(parts) < 2:
                continue
            for d in parts[1].split():
                d = d.lstrip("+@").split(":")[-1]
                if d:
                    deps.setdefault(d, set()).add(cur)
out, queue = set(), [root]
while queue:
    p = queue.pop()
    if p in out:
        continue
    out.add(p)
    queue.extend(deps.get(p, ()))
print("\n".join(sorted(out)))
PYEOF
)
	# защита от зацикливания: если пакет уже гасили, а он опять всплыл —
	# значит наш способ на него не действует, дальше крутить бессмысленно
	if grep -qx "$pkg" "$DISABLED" 2>/dev/null; then
		echo "пакет $pkg уже отключался, но снова всплыл — прекращаю" >&2
		return 1
	fi

	for p in $list; do
		sed -i "/^CONFIG_PACKAGE_${p}=/d" .config
		grep -q "^# CONFIG_PACKAGE_${p} is not set$" .config \
			|| echo "# CONFIG_PACKAGE_${p} is not set" >> .config
		echo "$p" >> "$DISABLED"
		n=$((n+1))
	done
	[ "$n" -gt 1 ] && echo "      вместе с зависимыми, всего $n"
	rm -rf tmp
	make defconfig >/dev/null 2>&1
}

# по имени файла ядра находим KernelPackage, который его тянет
kmod_for_file() {
	python3 - "$1" <<'PY'
import glob, re, sys
base = sys.argv[1]
for f in glob.glob("package/kernel/linux/modules/*.mk"):
    cur = None
    for line in open(f, errors="replace"):
        m = re.match(r'define KernelPackage/([\w.+-]+)', line)
        if m:
            cur = m.group(1)
        if cur and base in line:
            print("kmod-" + cur)
            raise SystemExit
PY
}

for step in target/linux/compile package/kernel/linux/compile; do
	echo "=== $step ==="
	for i in $(seq 1 "$MAX"); do
		# IGNORE_ERRORS=m — чтобы посторонние сбои (например, недоступная
		# загрузка прошивок ath10k) не выдавали себя за поломку kmod.
		if make -j1 V=s IGNORE_ERRORS=m "$step" > "$LOG" 2>&1; then
			echo "[$i] $step: ок"
			break
		fi

		sym=$(grep -oE '\(([A-Z0-9_]+)\) \[[^]]*\] \(NEW\)' "$LOG" | head -1 \
			| sed -n 's/^(\([A-Z0-9_]*\)).*/\1/p')
		if [ -n "$sym" ]; then
			echo "[$i] новый символ ядра $sym — отключаю"
			grep -q "^# CONFIG_$sym is not set$" "$KCFG" || echo "# CONFIG_$sym is not set" >> "$KCFG"
			rm -rf tmp; make defconfig >/dev/null 2>&1
			continue
		fi

		missing=$(grep -oE "No rule to make target '[^']+'" "$LOG" | head -1 | sed "s/.*'\(.*\)'/\1/")
		if [ -n "$missing" ]; then
			base=$(basename "$missing" | sed 's/\.[co]$//')
			pkg=$(kmod_for_file "$base")
			if [ -n "$pkg" ]; then
				echo "[$i] $missing нет в ядре — отключаю $pkg"
				disable_pkg "$pkg"; continue
			fi
			echo "[$i] не нашёл, какой kmod тянет $missing" >&2
			tail -20 "$LOG" >&2; exit 1
		fi

		pkg=$(grep -oE 'Package [A-Za-z0-9._+-]+ is missing dependencies' "$LOG" | head -1 | awk '{print $2}')
		if [ -n "$pkg" ]; then
			echo "[$i] $pkg не находит зависимостей в вендорском ядре — отключаю"
			disable_pkg "$pkg"; continue
		fi

		pkg=$(grep -oE "\*\*\* \[[^]]*/packages/[A-Za-z0-9._+-]+_[^]]*\.ipk\] Error" "$LOG" | head -1 \
			| sed 's|.*/packages/||; s/_.*//')
		if [ -n "$pkg" ]; then
			echo "[$i] сборка $pkg упала — отключаю"
			disable_pkg "$pkg"; continue
		fi

		# сбой скачивания исходников постороннего пакета
		dl=$(grep -oE '\*\*\* \[[^]]*: [^]]*/dl/[^]]+\] Error' "$LOG" | head -1)
		if [ -n "$dl" ]; then
			pkgdir=$(grep -oE 'package/[a-z0-9_/-]+/compile\] Error' "$LOG" | head -1 \
				| sed 's|/compile.*||; s|.*/||')
			if [ -n "$pkgdir" ]; then
				echo "[$i] не качается источник для $pkgdir — отключаю"
				disable_pkg "$pkgdir"; continue
			fi
		fi

		echo "[$i] $step упал по неизвестной причине:" >&2
		grep -nE 'Error [0-9]|error:' "$LOG" | head -10 >&2
		exit 1
	done
done

if [ -s "$DISABLED" ]; then
	echo
	echo "Отключено пакетов: $(wc -l < "$DISABLED") (список в $DISABLED)"
	sort "$DISABLED" | sed 's/^/  /'
fi
