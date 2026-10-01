---
name: openwrt-package
description: Добавление и правка пакетов в фиде репозитория ax50-openwrt (package/) под OpenWrt 19.07 и LuCI 19.07 — Makefile, procd-службы, LuCI-приложения на JS-представлениях и menu.d, переводы, проверка на стенде LuCI. Использовать при создании или изменении пакета или страницы LuCI.
---

# Пакеты фида ax50

Фид подключён как `src-link ax50 <репо>/package` и ставится с `-f` (переопределяет одноимённые).

## Makefile (OpenWrt 19.07)

- Исходники из git: `PKG_SOURCE_PROTO:=git`, `PKG_SOURCE_URL`, `PKG_SOURCE_VERSION:=<sha>`,
  `PKG_MIRROR_HASH` (архивы GitHub из облачной сессии закрыты, git-клон работает).
- Готовые бинарники — `PKG_SOURCE_URL_FILE` + `PKG_HASH` из официальных checksums.
- В `define Build/Compile`/`Package/install` переменные shell пишутся как `$$$$var`.
- Тулчейн GCC 7.5, musl: флаги вроде `-flto=auto` не поддерживаются — переопределяйте CFLAGS.
- Конфиги — `conffiles`; что сохранять при sysupgrade — `/lib/upgrade/keep.d/<пакет>`.
- Скрипты для роутера — `#!/bin/sh` (ash/busybox): без `find -exec +`, `local` допустим.

## LuCI 19.07 (финальная ветка)

- Меню — **только menu.d JSON** (`root/usr/share/luci/menu.d/*.json`); `dispatcher.lookup()`
  по Lua-дереву не работает. Зависимости: `acl`, `uci`, `fs` (`file`/`executable`/`directory`).
- Страницы — JS-представления (`'require view'`, `form`, `fs`, `rpc`, `ui`, `uci`).
  Нет `ui.RangeSlider`, `ui.Table`, `L.itemlist` (полифиллы в теме — `fs-compat.js`).
- `ui.tabs.initTabGroup(panes)` требует, чтобы у контейнера панелей был родитель.
- ACL — `root/usr/share/rpcd/acl.d/<пакет>.json`; root получает все группы.
- Переводы — `po/ru/<имя>.po`; `_()` поддерживает контекст (`msgctxt`).
- Makefile: `include $(TOPDIR)/feeds/luci/luci.mk`, `LUCI_PKGARCH:=all`.
- `luci.mk` сам вызывает `BuildPackage` и задаёт `Build/Prepare` и `PKG_BUILD_DIR` (без
  версии). Всё, что меняет правила пакета (`Hooks/Prepare/Post`, `PKG_UNPACK`,
  `CONFIG_LUCI_CSSTIDY`, `conffiles`), ставить **до** include — после него не действует.
  Пример — `package/luci-theme-footstrap/Makefile`. Проверять содержимое `.ipk`, а не только стенд.

## Проверка

```bash
tools/luci-bench/run.sh start   # OpenWrt 19.07.10 x86 + LuCI в Docker, 127.0.0.1:8080
tools/luci-bench/run.sh apps    # свои luci-app-* с заглушками служб
tools/luci-bench/run.sh theme   # тема footstrap
tools/luci-bench/run.sh nav admin/services/zapret     # клик по меню, ошибки консоли, скриншот /tmp/nav-*.png
```

Сборка пакета: навык `ax50-build`. Перед коммитом: `scripts/lint.sh`.
