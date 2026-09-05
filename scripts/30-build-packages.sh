#!/bin/bash
#
# Сборка ВСЕХ доступных пакетов в .ipk и формирование opkg-репозитория.
#
# Зачем отдельно от 20-build.sh: образ прошивки должен оставаться компактным,
# поэтому в нём только необходимое. А пакеты собираются как модули (=m) —
# они не попадают в образ, но складываются в bin/packages/, откуда их можно
# ставить через opkg.
#
# Механика: в OpenWrt каждый пакет объявлен как `default m if ALL`, поэтому
# CONFIG_ALL=y переводит всё дерево пакетов в режим "собрать .ipk, в образ не класть".
# CONFIG_ALL_KMODS=y делает то же для модулей ядра.
#
# IGNORE_ERRORS=m — чтобы один сломанный пакет (а в фидах 19.07 такие есть)
# не обрушивал сборку остальных.
#
# Осторожно: это долго (много часов) и требует заметно больше места на диске,
# чем сборка одного образа.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build}"
TREE="$BUILD_DIR/prplwrt"
JOBS="${JOBS:-$(nproc)}"

[ -d "$TREE" ] || { echo "нет дерева $TREE — сначала ./scripts/10-setup-tree.sh" >&2; exit 1; }
[ "$(id -u)" != 0 ] || { echo "не собирайте от root" >&2; exit 1; }

cd "$TREE"

# сохраняем конфигурацию «только образ», чтобы можно было вернуться
[ -f .config.image-only ] || cp .config .config.image-only

echo "==> Включаем сборку всех пакетов"
for sym in CONFIG_ALL CONFIG_ALL_KMODS; do
	sed -i "/^# ${sym} is not set\$/d; /^${sym}=/d" .config
	echo "${sym}=y" >> .config
done

# Ключевой момент: `make defconfig` не пересматривает символы, у которых в
# .config уже стоит явное значение, а после сборки образа там на каждый
# невыбранный пакет записано "# CONFIG_PACKAGE_xxx is not set". Умолчание
# `default m if ALL` в такой ситуации не срабатывает, и включение CONFIG_ALL
# не даёт ничего. Поэтому сначала убираем эти строки — тогда defconfig
# проставит пакетам m. Строки CONFIG_PACKAGE_xxx=y (то, что идёт в образ)
# не трогаем: они должны остаться в образе.
sed -i '/^# CONFIG_PACKAGE_.* is not set$/d' .config

rm -rf tmp
make defconfig >/dev/null

sel=$(grep -c '^CONFIG_PACKAGE_.*=m$' .config || true)
echo "    пакетов выбрано как модули: $sel"
[ "$sel" -gt 100 ] || { echo "подозрительно мало пакетов выбрано — проверьте .config" >&2; exit 1; }

# Часть kmod-пакетов OpenWrt не собирается на вендорском ядре 4.9 и валит
# весь шаг target/linux/compile (IGNORE_ERRORS=m его не покрывает). Чиним заранее.
echo "==> Подготовка ядра к сборке всех kmod"
"$REPO_ROOT/scripts/lib/fix-kernel-build.sh" "$TREE" || {
	echo "не удалось подготовить сборку модулей ядра — смотрите вывод выше" >&2
	exit 1
}

echo "==> make download"
make -j"$JOBS" download IGNORE_ERRORS=m || true

echo "==> Сборка пакетов (это надолго)"
make -j"$JOBS" IGNORE_ERRORS=m || {
	echo "Параллельная сборка завершилась с ошибкой, добираем однопоточно."
	make -j1 IGNORE_ERRORS=m V=s || true
}

echo "==> Индексы opkg"
make package/index

ARCH_DIR=$(find "$TREE/bin/packages" -maxdepth 1 -mindepth 1 -type d | head -1)
echo
echo "==> Репозиторий готов: $ARCH_DIR"
find "$TREE/bin/packages" -name '*.ipk' | wc -l | xargs echo "    пакетов собрано:"
find "$TREE/bin/packages" -name 'Packages.gz' | sed "s|$TREE/||" | sed 's/^/    индекс: /'
echo
echo "Вернуть конфигурацию «только образ»:  cp .config.image-only .config && make defconfig"
