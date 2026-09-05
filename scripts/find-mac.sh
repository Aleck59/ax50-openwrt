#!/bin/sh
#
# Поиск заводского MAC-адреса Archer AX50 в дампах разделов NAND.
#
# Работает и на устройстве (по /dev/mtd*), и на компьютере — по бэкапу,
# снятому scripts/backup-router.sh.
#
# Использование:
#   ./scripts/find-mac.sh backups/ax50-20260101-120000     # каталог с дампами
#   ./scripts/find-mac.sh dump.bin                          # один файл
#   ./scripts/find-mac.sh                                   # на устройстве: все /dev/mtd*
#
# Что ищем: сток TP-Link хранит базовый MAC в программном разделе default-mac
# строкой вида "MAC:XX-XX-XX-XX-XX-XX" (её разбирает /sbin/getfirm через
# nvrammanager). Плюс проверяем окружение U-Boot на переменную ethaddr.
#
# Как из базового получаются остальные (логика /sbin/network_get_firm из стока):
#   LAN = base, WAN = base+1, Wi-Fi 2.4 = base-1, Wi-Fi 5 = base-2
#
set -eu

scan_file() {
	f="$1"
	[ -r "$f" ] || return 0

	tr -c '[:print:]' '\n' < "$f" 2>/dev/null | grep -o 'MAC:[0-9A-Fa-f][0-9A-Fa-f-]\{16\}' \
		| sort -u | while read -r m; do
			echo "  $f: default-mac -> ${m#MAC:}"
		done

	tr -c '[:print:]' '\n' < "$f" 2>/dev/null | grep -o 'ethaddr=[0-9A-Fa-f:]\{17\}' \
		| sort -u | while read -r m; do
			echo "  $f: U-Boot $m"
		done

	tr -c '[:print:]' '\n' < "$f" 2>/dev/null | grep -oE '\b[0-9A-F]{2}(-[0-9A-F]{2}){5}\b' \
		| sort -u | head -5 | while read -r m; do
			echo "  $f: похоже на MAC -> $m"
		done
}

targets=""
if [ $# -ge 1 ]; then
	if [ -d "$1" ]; then targets=$(find "$1" -type f -name '*.bin' | sort)
	else targets="$1"; fi
else
	targets=$(ls /dev/mtd[0-9]* 2>/dev/null | grep -v ro || true)
	[ -n "$targets" ] || { echo "нечего сканировать: укажите файл или каталог с дампами" >&2; exit 1; }
fi

echo "Сканирую:"
for t in $targets; do scan_file "$t"; done

cat <<'MSG'

Как читать результат:

  * "default-mac -> XX-XX-..." — это и есть базовый адрес, тот самый,
    что сток отдаёт по `getfirm MAC`. Раздел, в котором он нашёлся, и есть
    контейнер программной таблицы TP-Link.
  * Сверьте его с наклейкой на корпусе: на наклейке обычно указан MAC LAN,
    он должен совпасть с базовым.
  * Если базовый нашёлся, но не в ubootconfigA — впишите имя раздела первым
    в список кандидатов в device/files/etc/board.d/03_ax50_network.
MSG
