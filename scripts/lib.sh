# shellcheck shell=bash
# Общие переменные и функции для скриптов сборки.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build}"
TREE="${TREE:-$BUILD_DIR/prplwrt}"
JOBS="${JOBS:-$(nproc)}"

# shellcheck source=../config/versions.env
. "$REPO_ROOT/config/versions.env"

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*" >&2; }
die()  { printf '\n\033[1;31m!!! %s\033[0m\n' "$*" >&2; exit 1; }

require_tree() {
	[ -f "$TREE/rules.mk" ] || die "нет дерева $TREE — сначала scripts/prepare.sh"
}

require_non_root() {
	[ "$(id -u)" != 0 ] || die "OpenWrt не собирается от root — запустите от обычного пользователя"
}

# Накладывает patches/<имя>/*.patch на каталог (дерево prplWrt или фид)
apply_patches() {
	local name="$1" dir="$2" p
	[ -d "$REPO_ROOT/patches/$name" ] || return 0
	for p in "$REPO_ROOT/patches/$name"/*.patch; do
		[ -e "$p" ] || continue
		echo "    $name: $(basename "$p")"
		patch -d "$dir" -p1 --forward --no-backup-if-mismatch -s < "$p" \
			|| die "патч $p не накладывается на $dir"
	done
}
