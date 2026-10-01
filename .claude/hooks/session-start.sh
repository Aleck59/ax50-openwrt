#!/bin/bash
# SessionStart (Claude Code on the web): инструменты для проверок и сборки.
#  - shellcheck, device-tree-compiler — для scripts/lint.sh
#  - dockerd — сборка прошивки идёт в контейнере Ubuntu 20.04 (scripts/docker.sh)
set -euo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

need=()
command -v shellcheck >/dev/null || need+=(shellcheck)
command -v dtc >/dev/null || need+=(device-tree-compiler)
if [ ${#need[@]} -gt 0 ]; then
	export DEBIAN_FRONTEND=noninteractive
	apt-get install -y -qq "${need[@]}" >/dev/null 2>&1 || {
		apt-get update -qq >/dev/null 2>&1
		apt-get install -y -qq "${need[@]}" >/dev/null
	}
fi

# Docker-демон (в веб-сессии он не запущен)
if command -v dockerd >/dev/null && ! docker info >/dev/null 2>&1; then
	nohup dockerd >/tmp/dockerd.log 2>&1 &
	for _ in $(seq 1 20); do docker info >/dev/null 2>&1 && break; sleep 1; done
fi

echo "session-start: shellcheck $(shellcheck --version | sed -n 2p | cut -d' ' -f2), dtc $(dtc --version | cut -d' ' -f3), docker: $(docker info >/dev/null 2>&1 && echo ok || echo нет)"
