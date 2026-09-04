#!/bin/sh
#
# Полный бэкап NAND роутера ПЕРЕД любыми экспериментами.
# Требует доступ по SSH/telnet с root на устройстве (стоковая прошивка TP-Link
# такого доступа не даёт — снимайте дамп из U-Boot или программатором,
# см. docs/04-flashing.md).
#
# Использование: ./scripts/backup-router.sh root@192.168.0.1 [каталог]
#
set -eu

HOST="${1:-}"
[ -n "$HOST" ] || { echo "использование: $0 root@IP [каталог]" >&2; exit 1; }
DEST="${2:-backups/ax50-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$DEST"

echo "==> Таблица разделов"
ssh "$HOST" cat /proc/mtd | tee "$DEST/mtd.txt"

echo "==> Снимаем разделы"
# КРИТИЧНО: uboot, ubootconfigA/B, calibration, gphyfirmware.
# calibration содержит калибровку Wi-Fi и MAC-адреса — без неё роутер
# теряет радио и заводские MAC безвозвратно.
awk -F'[:"]' '/^mtd/ {print $1" "$3}' "$DEST/mtd.txt" | while read -r dev name; do
	num="${dev#mtd}"
	echo "  $dev ($name)"
	ssh "$HOST" "cat /dev/mtd$num" > "$DEST/${num}_${name}.bin" || \
		echo "    !! не удалось прочитать $dev"
done

echo "==> Конфигурация и окружение"
ssh "$HOST" "cat /proc/cpuinfo; echo; cat /proc/meminfo; echo; dmesg" \
	> "$DEST/sysinfo.txt" 2>/dev/null || true
ssh "$HOST" "fw_printenv" > "$DEST/uboot-env.txt" 2>/dev/null || \
	echo "fw_printenv недоступен — окружение U-Boot снимите из консоли (printenv)"

echo "==> Контрольные суммы"
( cd "$DEST" && sha256sum ./*.bin > SHA256SUMS )

echo
echo "Бэкап готов: $DEST"
echo "Храните его вне роутера. Без раздела calibration восстановить Wi-Fi нельзя."
