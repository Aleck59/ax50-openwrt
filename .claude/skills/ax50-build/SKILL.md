---
name: ax50-build
description: Сборка прошивки TP-Link Archer AX50 (prplWrt/OpenWrt 19.07, intel_mips/xrx500) локально в Docker и разбор ошибок сборки. Использовать, когда нужно собрать образ, пакет или SDK, воспроизвести падение CI, поменять фиды/патчи/набор пакетов.
---

# Сборка прошивки AX50

База — prplWrt (OpenWrt 19.07 + ядро Intel/MaxLinear 4.9.206). Ей нужны Python 2 и
GCC <= 9, поэтому всё собирается в контейнере Ubuntu 20.04 (`docker/Dockerfile`).
OpenWrt не собирается от root.

## Конвейер (одинаковый локально и в CI)

```bash
scripts/docker.sh scripts/prepare.sh     # prplWrt + фиды на коммитах, patches/, target/, files/
scripts/docker.sh scripts/configure.sh   # .config из config/*.config + проверка выбора пакетов
scripts/docker.sh scripts/build.sh       # make download + make -jN (при падении -j1 V=s)
scripts/docker.sh scripts/collect.sh v1.2.3 /work/out   # переименование, sha256, SDK, пакеты
```

В облачной сессии Claude Code сессия идёт от root — запускайте с
`BUILD_UID=1000 BUILD_GID=1000`, а за TLS-прокси добавьте `EXTRA_CA=/root/.ccr/ca-bundle.crt`
(сертификат встраивается в образ). `build/` должен принадлежать UID 1000.

Переменные: `VERSION`, `WITH_KMODS=1` (модули ядра для фида, `config/kmods.config`),
`WITH_SDK=1`, `USIGN_KEY_FILE`, `FEED_URL`, `JOBS`.

Точечная сборка пакета: `scripts/docker.sh scripts/build.sh package/<имя>/{clean,compile} V=s`.

## Где что лежит

| Путь | Что |
|---|---|
| `config/versions.env`, `config/feeds.conf` | закреплённые коммиты prplWrt, ядра, фидов |
| `config/image.config` | пакеты образа; `config/kmods.config` — модули для фида |
| `target/linux/intel_mips/` | DTS и рецепт образа AX50 (копируются в feed_target_mips) |
| `patches/<prplwrt|имя_фида>/` | патчи дерева/фидов (unified diff, `-p1` от корня фида) |
| `package/` | свой фид `ax50` (src-link) |
| `files/` | оверлей rootfs |

## Типичные проблемы

- **Символ не пережил defconfig** — `configure.sh` перечисляет такие. Обычно пакет зависит
  от невыбранного родителя (`kmod-usb-net` для `kmod-usb-net-*`) или его нет в фидах.
  Смотрите `build/prplwrt/tmp/.config-package.in`.
- **`(NEW)` символ ядра без умолчания** при модулях — допишите `# CONFIG_X is not set`
  патчем к `feeds/feed_target_mips/intel_mips/config-4.9`.
- **Пакет с `PKG_MIRROR_HASH:=skip`** — получить хэш: `make package/<p>/download` и
  `make package/<p>/check FIXUP=1` в дереве.
- **WARNING ... dependency ... does not exist** у пакетов Intel — шум индексации, не ошибка.
- Логи пакетов: `build/prplwrt/logs/package/...`.

Перед пушем: `scripts/lint.sh`.
