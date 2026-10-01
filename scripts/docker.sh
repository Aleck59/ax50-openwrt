#!/bin/bash
#
# Запуск сборки в контейнере Ubuntu 20.04 (база prplWrt — OpenWrt 19.07,
# ей нужны Python 2 и GCC <= 9, которых на свежих дистрибутивах нет).
#
#   scripts/docker.sh                 # prepare + configure + build
#   scripts/docker.sh shell           # оболочка в окружении сборки
#   scripts/docker.sh <команда...>    # произвольная команда, например:
#   scripts/docker.sh scripts/build.sh package/zapret/compile
#
# За TLS-прокси: EXTRA_CA=/путь/к/ca.crt — сертификат будет встроен в образ.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:-ax50-build}"

command -v docker >/dev/null || { echo "нужен docker" >&2; exit 1; }

ctx="$(mktemp -d)"
trap 'rm -rf "$ctx"' EXIT
cp "$REPO_ROOT/docker/Dockerfile" "$ctx/"
[ -n "${EXTRA_CA:-}" ] && cp "$EXTRA_CA" "$ctx/extra-ca.crt"
docker build -q -t "$IMAGE" --network host \
	--build-arg UID="${BUILD_UID:-$(id -u)}" --build-arg GID="${BUILD_GID:-$(id -g)}" \
	${HTTPS_PROXY:+--build-arg https_proxy="$HTTPS_PROXY"} \
	"$ctx" >/dev/null

mkdir -p "$REPO_ROOT/build"

# Переменные, которые понимают scripts/*.sh, пробрасываются в контейнер
passenv=()
for v in VERSION WITH_KMODS WITH_SDK USIGN_KEY_FILE FEED_URL FEED_REUSE_SDK; do
	[ -n "${!v:-}" ] && passenv+=(-e "$v=${!v}")
done

run() {
	local tty=()
	[ -t 0 ] && tty=(-t)
	docker run --rm -i "${tty[@]}" --network host \
		-u "${BUILD_UID:-$(id -u)}:${BUILD_GID:-$(id -g)}" \
		-v "$REPO_ROOT:/work" -w /work \
		-e JOBS="${JOBS:-$(nproc)}" \
		-e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*' \
		${HTTPS_PROXY:+-e https_proxy="$HTTPS_PROXY" -e HTTPS_PROXY="$HTTPS_PROXY"} \
		"${passenv[@]}" \
		"$IMAGE" "$@"
}

case "${1:-all}" in
	all)   run bash -c 'scripts/prepare.sh && scripts/configure.sh && scripts/build.sh' ;;
	shell) run bash ;;
	*)     run "$@" ;;
esac
