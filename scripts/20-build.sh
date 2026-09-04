#!/bin/bash
# Сборка образа. Первый прогон — часы (toolchain + ядро + пакеты).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build}"
TREE="$BUILD_DIR/prplwrt"
JOBS="${JOBS:-$(nproc)}"

[ -d "$TREE" ] || { echo "нет дерева $TREE — сначала ./scripts/10-setup-tree.sh" >&2; exit 1; }
[ "$(id -u)" != 0 ] || { echo "не собирайте от root" >&2; exit 1; }

cd "$TREE"

echo "==> make download"
make -j"$JOBS" download

echo "==> make -j$JOBS"
if ! make -j"$JOBS"; then
	echo
	echo "Параллельная сборка упала. Повторяем однопоточно с V=s, чтобы увидеть ошибку."
	make -j1 V=s
fi

OUT="$TREE/bin/targets/intel_mips/xrx500"
echo
echo "==> Готовые образы:"
ls -la "$OUT" 2>/dev/null || echo "каталог $OUT пуст — сборка не дошла до образов"
