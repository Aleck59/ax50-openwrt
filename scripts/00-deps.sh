#!/bin/sh
# Хостовые зависимости для сборки prplWrt (OpenWrt 19.07 base, ядро 4.9).
# Debian/Ubuntu. Для других дистрибутивов см.
# https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem
set -eu

if [ "$(id -u)" = 0 ]; then SUDO=""; else SUDO="sudo"; fi

$SUDO apt-get update
$SUDO apt-get install -y \
	build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
	gettext git libncurses-dev libssl-dev python3-distutils python3-setuptools \
	python3-yaml rsync unzip zlib1g-dev file wget quilt subversion \
	swig time device-tree-compiler libelf-dev ccache

cat <<'MSG'

Зависимости установлены.

Важно:
 * сборка должна идти НЕ от root — OpenWrt на это ругается и падает;
 * файловая система должна быть ext4/btrfs/xfs (в WSL — не /mnt/c);
 * нужно ~40 ГБ свободного места и 8+ ГБ ОЗУ.

Дальше: ./scripts/10-setup-tree.sh
MSG
