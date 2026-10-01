#!/bin/sh
#
# TP-Link Archer AX50 v1: заводской («базовый») MAC-адрес.
#
# Сток выводит все адреса из одного базового (sbin/network_get_firm):
#   LAN = base, WAN = base + 1, Wi-Fi 2.4 ГГц = base - 1, Wi-Fi 5 ГГц = base - 2
# Базовый адрес сток читает проприетарным nvrammanager из раздела default-mac
# На платформе Intel этот слой TP-Link живёт в UBI-томе data_vol внутри
# system_sw: файл default-mac — 6 байт адреса в двоичном виде (рядом
# product-info, device-id, rftest/ — резервная копия калибровки). Заливка нашей прошивки из U-Boot перезаписывает только тома
# kernelA/rootfsA, поэтому data_vol обычно сохраняется — его и читаем первым.
#
# Порядок поиска:
#   1. UBI-том data_vol (только чтение), файл default-mac
#   2. окружение U-Boot (ubootconfigA/B), переменная ethaddr — если это не
#      заглушка 00:E0:92:00:01:40 из исходников U-Boot
#   3. строка "MAC:..." в сыром содержимом разделов res и calibration
#   4. запасной вариант: стабильный локально администрируемый адрес из
#      хеша калибровки — уникален для экземпляра и не меняется между загрузками
#
# Найденный адрес кэшируется в /etc/ax50/base-mac (сохраняется при sysupgrade).

. /lib/functions.sh
. /lib/functions/system.sh

AX50_MAC_CACHE=/etc/ax50/base-mac
AX50_UBOOT_DEFAULT_MAC="00:e0:92:00:01:40"

ax50_log() {
	logger -t ax50 "$*"
}

# Нормализует и проверяет адрес: unicast, не нули, не заглушка U-Boot
ax50_valid_mac() {
	local mac
	mac="$(echo "$1" | tr 'A-F-' 'a-f:')"
	echo "$mac" | grep -qE '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$' || return 1
	case "$mac" in
	00:00:00:00:00:00|ff:ff:ff:ff:ff:ff|"$AX50_UBOOT_DEFAULT_MAC") return 1 ;;
	esac
	# бит групповой рассылки в первом октете
	[ $((0x${mac%%:*} & 1)) -eq 0 ] || return 1
	echo "$mac"
}

# Ищет строку "MAC:XX-XX-XX-XX-XX-XX" (формат default-mac TP-Link) в потоке
ax50_grep_mac() {
	tr -c '[:print:]' '\n' | grep -m1 -oE 'MAC:[0-9A-Fa-f]{2}([-:][0-9A-Fa-f]{2}){5}' | cut -d: -f2-
}

ax50_mac_from_data_vol() {
	local vol dev name mnt mac

	for vol in /sys/class/ubi/ubi*_*; do
		[ -f "$vol/name" ] || continue
		name="$(cat "$vol/name")"
		[ "$name" = "data_vol" ] || continue
		dev="${vol##*/}"
		mnt="$(mktemp -d /tmp/ax50-data.XXXXXX)"
		if mount -t ubifs -o ro "${dev%_*}:data_vol" "$mnt" 2>/dev/null; then
			# default-mac — 6 байт адреса в двоичном виде (проверено на
			# роутере); на случай другого формата — поиск строки "MAC:"
			if [ -f "$mnt/default-mac" ]; then
				mac="$(hexdump -v -n 6 -e '5/1 "%02x:" 1/1 "%02x"' "$mnt/default-mac")"
				ax50_valid_mac "$mac" >/dev/null || mac=""
			fi
			[ -n "$mac" ] || mac="$(find "$mnt" -type f -size -64k 2>/dev/null \
				| while read -r f; do cat "$f"; done | ax50_grep_mac)"
			umount "$mnt"
		fi
		rmdir "$mnt"
		[ -n "$mac" ] && { echo "$mac"; return 0; }
	done
	return 1
}

ax50_mac_from_uboot_env() {
	local part dev mac
	for part in ubootconfigA ubootconfigB; do
		dev="$(find_mtd_part "$part")"
		[ -n "$dev" ] || continue
		mac="$(tr -c '[:print:]' '\n' < "$dev" 2>/dev/null | sed -n 's/^ethaddr=//p' | head -n1)"
		mac="$(ax50_valid_mac "$mac")" && { echo "$mac"; return 0; }
	done
	return 1
}

ax50_mac_from_raw() {
	local part dev mac
	for part in res calibration; do
		dev="$(find_mtd_part "$part")"
		[ -n "$dev" ] || continue
		mac="$(ax50_grep_mac < "$dev" 2>/dev/null)"
		[ -n "$mac" ] && { echo "$mac"; return 0; }
	done
	return 1
}

ax50_mac_from_fallback() {
	local dev hash
	dev="$(find_mtd_part calibration)"
	[ -n "$dev" ] || return 1
	hash="$(head -c 65536 "$dev" | md5sum | cut -c1-10)"
	# 02:... — локально администрируемый unicast
	echo "02:$(echo "$hash" | sed 's/\(..\)/\1:/g; s/:$//')"
}

# Печатает базовый MAC-адрес платы
ax50_base_mac() {
	local mac src

	if [ -s "$AX50_MAC_CACHE" ]; then
		mac="$(ax50_valid_mac "$(cat "$AX50_MAC_CACHE")")" && { echo "$mac"; return 0; }
	fi

	for src in data_vol uboot_env raw fallback; do
		mac="$(ax50_mac_from_$src)" || continue
		mac="$(ax50_valid_mac "$mac")" || continue
		ax50_log "базовый MAC $mac (источник: $src)"
		[ "$src" = fallback ] && \
			ax50_log "заводской MAC не найден — используется производный локальный адрес"
		mkdir -p "${AX50_MAC_CACHE%/*}"
		echo "$mac" > "$AX50_MAC_CACHE"
		echo "$mac"
		return 0
	done

	ax50_log "не удалось определить базовый MAC"
	return 1
}

# Сдвиг адреса в младших трёх байтах, как inc_mac/dec_mac в стоке
ax50_mac_offset() {
	macaddr_add "$1" "$2"
}
