# ax50-openwrt

Прошивка для TP-Link Archer AX50 v1 на базе prplWrt (OpenWrt 19.07 + ядро Intel/MaxLinear
4.9.206, таргет `intel_mips/xrx500`). Документация и сообщения коммитов — на русском.

## Навыки проекта (`.claude/skills/`)

- `ax50-build` — сборка в Docker, конвейер prepare/configure/build/collect, ошибки сборки
- `openwrt-package` — пакеты фида и LuCI 19.07 (menu.d, JS-представления), стенд LuCI
- `ax50-release` — теги, релизы, фид пакетов, GitHub Pages, подпись usign
- `ax50-hardware` — разметка NAND, калибровка, MAC, GPIO, порты, U-Boot

## Правила

- Не трогать в прошивке запись в MTD `uboot`, `ubootconfigA/B`, `gphyfirmware`, `calibration`.
- Версии исходников закреплены (`config/versions.env`, `config/feeds.conf`) — менять осознанно.
- Изменения во внешних фидах — патчами в `patches/<фид>/`, не правкой дерева сборки.
- Перед коммитом: `scripts/lint.sh`. Страницы LuCI проверять на `tools/luci-bench`.
- Сборка не от root (в облачной сессии: `BUILD_UID=1000 BUILD_GID=1000`).
