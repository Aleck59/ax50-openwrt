#!/bin/bash
# Хостовые зависимости для сборки prplWrt (база OpenWrt 19.07, ядро 4.9).
#
# ВНИМАНИЕ: этот путь работает только на достаточно старом дистрибутиве.
# OpenWrt 19.07 требует Python 2.x и не распознаёт GCC новее 9.x. Проверено:
# на Ubuntu 24.04 сборка падает на проверке зависимостей ещё до конфигурации.
# Подходит Ubuntu 20.04 (GCC 9 + python2). На всём остальном используйте
# контейнер: ./scripts/docker-build.sh
set -eu

if [ "$(id -u)" = 0 ]; then SUDO=""; else SUDO="sudo"; fi

$SUDO apt-get update
$SUDO apt-get install -y \
	build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
	gettext git libncurses-dev libssl-dev python3 python3-setuptools \
	python3-yaml rsync unzip zlib1g-dev file wget quilt subversion \
	swig time device-tree-compiler libelf-dev ccache xsltproc

# Python 2.x — обязателен для prereq-проверки OpenWrt 19.07
if ! $SUDO apt-get install -y python2 2>/dev/null; then
	echo
	echo "!!! Пакет python2 в этом дистрибутиве недоступен."
	echo "!!! Собирайте в контейнере: ./scripts/docker-build.sh"
fi
command -v python >/dev/null || {
	if command -v python2 >/dev/null; then
		$SUDO ln -sf "$(command -v python2)" /usr/bin/python
	fi
}

gccver="$(gcc -dumpversion 2>/dev/null || echo 0)"
case "$gccver" in
	4.[89]*|[5-9]|[5-9].*) ;;
	*)
		echo
		echo "!!! GCC $gccver новее, чем понимает OpenWrt 19.07 (4.8-9.x)."
		echo "!!! Собирайте в контейнере: ./scripts/docker-build.sh"
		;;
esac

cat <<'MSG'

Готово.

Помните:
 * сборка НЕ от root — OpenWrt на это ругается и падает;
 * файловая система ext4/btrfs/xfs (в WSL — не /mnt/c);
 * нужно ~40 ГБ свободного места и 8+ ГБ ОЗУ.

Дальше: ./scripts/10-setup-tree.sh
MSG
