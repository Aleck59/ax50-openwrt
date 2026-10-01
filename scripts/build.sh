#!/bin/bash
#
# Сборка. Без аргументов — вся прошивка; с аргументами — цели make, например:
#   scripts/build.sh package/zapret/{clean,compile}
#
set -euo pipefail
. "$(dirname "$0")/lib.sh"

require_non_root
require_tree
cd "$TREE"

if [ $# -gt 0 ]; then
	exec make -j"$JOBS" "$@"
fi

log "Загрузка исходников"
make -j"$JOBS" download || make -j1 download V=s

log "Сборка (-j$JOBS)"
if ! make -j"$JOBS"; then
	warn "параллельная сборка упала — повтор в один поток с подробным выводом"
	make -j1 V=s
fi

OUT="$TREE/bin/targets/intel_mips/xrx500"
log "Готово: $OUT"
ls -la "$OUT"/*AX50* 2>/dev/null || die "образы не появились"
