#!/bin/bash
# Быстрые проверки репозитория (те же, что job «Проверки» в CI):
#   статический анализ shell, синтаксис JSON/Python/JS, формат патчей.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== shellcheck (скрипты сборки)"
shellcheck -S warning scripts/*.sh .claude/hooks/*.sh tools/*/*.sh

echo "== shellcheck (скрипты роутера, ash)"
find package -type f \( -path '*/files/*' -o -path '*/root/*' \) | while read -r f; do
	if head -1 "$f" | grep -q '^#!/bin/sh'; then echo "$f"; fi
done | xargs -r shellcheck -s sh -S error -e SC2034,SC3043,SC1091

echo "== JSON / Python / JavaScript"
find package -name '*.json' -print0 | xargs -0 -n1 python3 -m json.tool >/dev/null
python3 -m py_compile scripts/usign-pubkey.py scripts/stock-totalimage.py
find package -name '*.js' -print0 | xargs -0 -n1 node --check

echo "== патчи"
for p in patches/*/*.patch; do
	grep -q '^+++ ' "$p" || { echo "не патч: $p"; exit 1; }
done
echo "OK"
