#!/bin/bash
#
# Рекомендуемый способ сборки: всё внутри Ubuntu 20.04.
#
# На современных дистрибутивах (Ubuntu 22.04/24.04, Fedora, Arch) сборка
# prplWrt/OpenWrt 19.07 не проходит проверку зависимостей: нужен Python 2.x
# (в Ubuntu 24.04 его уже нет) и GCC не новее 9.x. Контейнер снимает вопрос.
#
# Использование:
#   ./scripts/docker-build.sh            # подготовка дерева + полная сборка
#   ./scripts/docker-build.sh setup      # только подготовка дерева
#   ./scripts/docker-build.sh shell      # интерактивная оболочка в окружении
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:-ax50-build}"
ACTION="${1:-all}"

command -v docker >/dev/null || { echo "нужен docker" >&2; exit 1; }

echo "==> Сборка образа $IMAGE (Ubuntu 20.04)"
docker build -t "$IMAGE" \
	--build-arg UID="$(id -u)" --build-arg GID="$(id -g)" \
	"$REPO_ROOT/docker"

run() {
	docker run --rm -it \
		-v "$REPO_ROOT:/work" \
		-e BUILD_DIR=/work/build \
		-e JOBS="${JOBS:-$(nproc)}" \
		"$IMAGE" "$@"
}

case "$ACTION" in
	setup) run bash /work/scripts/10-setup-tree.sh ;;
	build) run bash /work/scripts/20-build.sh ;;
	shell) run bash ;;
	all)
		run bash /work/scripts/10-setup-tree.sh
		run bash /work/scripts/20-build.sh
		;;
	*) echo "использование: $0 [all|setup|build|shell]" >&2; exit 1 ;;
esac
