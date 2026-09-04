#!/bin/bash
#
# Быстрая проверка device/dts/tplink_ax50.dts без полного дерева prplWrt.
# Подставляет заглушку вместо базового DTS референс-платы (ci/dts-stub/base.dts),
# прогоняет cpp + dtc и показывает получившуюся разметку NAND.
#
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v dtc >/dev/null || { echo "нужен dtc (пакет device-tree-compiler)" >&2; exit 1; }

# наш DTS без include базовой платы
sed '/#include "easy350_anywan_axepoint_rt.dts"/d' \
	"$REPO_ROOT/device/dts/tplink_ax50.dts" > "$WORK/ours.dtsi"
cat "$REPO_ROOT/ci/dts-stub/base.dts" "$WORK/ours.dtsi" > "$WORK/combined.dts"

cpp -nostdinc -I "$REPO_ROOT/ci/dts-stub" -undef -x assembler-with-cpp \
	"$WORK/combined.dts" -o "$WORK/pp.dts"
dtc -I dts -O dtb -o "$WORK/out.dtb" "$WORK/pp.dts" 2>"$WORK/dtc.log"

echo "DTS компилируется."
echo
echo "Итоговая разметка NAND:"
dtc -I dtb -O dts "$WORK/out.dtb" 2>/dev/null | sed -n '/nand-parts@0/,/^\t\t\t};/p'

if grep -q 'system_sw' <(dtc -I dtb -O dts "$WORK/out.dtb" 2>/dev/null) &&
   ! grep -q 'Bootcore' <(dtc -I dtb -O dts "$WORK/out.dtb" 2>/dev/null); then
	echo
	echo "Разделы референс-платы вытеснены нашими — как и задумано."
else
	echo "ОШИБКА: разметка NAND получилась не той, что ожидалась" >&2
	exit 1
fi
