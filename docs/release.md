# CI/CD, релизы и фид пакетов

## Workflow 1 — «Прошивка» (`.github/workflows/firmware.yml`)

| Событие | Что происходит |
|---|---|
| push в любую ветку, pull request | `scripts/lint.sh`, полная сборка; образы — артефактом в Actions |
| тег `v*` | то же + **GitHub Release** и запуск workflow 2 |

Сборка идёт на `ubuntu-24.04` в контейнере Ubuntu 20.04, с модулями ядра для фида и SDK.
Кэшируется только `dl/` (исходники). В релиз попадают:

- `ax50-openwrt-<тег>-squashfs-sysupgrade.bin`, `-squashfs-fullimage.img`, `-initramfs-kernel.bin`;
- `ax50-openwrt-<тег>.manifest`, `-buildinfo.tar.gz`, `sha256sums`;
- `ax50-openwrt-<тег>-sdk.tar.xz` — SDK, на котором workflow 2 собирает фид;
- `ax50-openwrt-<тег>-packages.tar.gz` — модули ядра и пакеты этой сборки.

## Workflow 2 — «Фид пакетов» (`.github/workflows/packages.yml`)

Запускается из workflow 1 после публикации релиза (или вручную: Actions → «Фид пакетов» →
Run workflow → тег). Шаги:

1. скачивает SDK и пакеты релиза;
2. `scripts/feed-build.sh`: фиды на тех же коммитах, патчи, сборка пакетов из
   `config/feed-packages.txt` (шаблоны вида `luci-app-*` раскрываются), индексы, подпись;
3. архив фида `ax50-openwrt-<тег>-feed.tar.gz` — в тот же релиз;
4. сайт для GitHub Pages: фид последнего релиза в `releases/dev/`, страница с инструкцией.

Структура — как у downloads.openwrt.org, поэтому прошивке ничего настраивать не нужно:
адрес задан при сборке (`CONFIG_VERSION_REPO`) и попадает в `/etc/opkg/distfeeds.conf`:

```
src/gz ax50-openwrt_core       https://aleck59.github.io/ax50-openwrt/releases/dev/targets/intel_mips/xrx500/packages
src/gz ax50-openwrt_base       https://aleck59.github.io/ax50-openwrt/releases/dev/packages/mips_24kc_nomips16/base
src/gz ax50-openwrt_packages   …/packages/mips_24kc_nomips16/packages
src/gz ax50-openwrt_luci       …/packages/mips_24kc_nomips16/luci
…
```

Адрес один для всех версий прошивки: каждый релиз перезаписывает `releases/dev`, так что
старые прошивки тоже получают свежие пакеты. Исключение — модули ядра (`kmod-*`): они
привязаны к сборке ядра, и если opkg откажется их ставить, обновите прошивку.

Пакеты, которым нужны модули ядра (uqmi, umbim, usbip, alsa-utils, cifsmount), SDK не
собирает — модулей в нём нет. Их собирает workflow 1 из `config/kmods.config`.

## Как выпустить версию

```bash
git tag -a v1.0.0 -m "AX50 OpenWrt v1.0.0"
git push origin v1.0.0
```

Или без локального git: Actions → «Прошивка» → Run workflow, ветка `main`, поле
`release_tag` = `v1.0.0`. Workflow соберёт прошивку, сам создаст тег на этом коммите и
релиз, затем запустит сборку фида.

Тег с дефисом (`v1.0.0-rc1`) публикуется как пререлиз.

## Однократная настройка репозитория (владелец)

1. **GitHub Pages:** Settings → Pages → Build and deployment → Source: **GitHub Actions**.
   Без этого фид доступен только архивом в релизе (job публикации выдаст предупреждение).
2. **Подпись фида (рекомендуется):**
   ```bash
   usign -G -s usign.key -p usign.pub -c "ax50-openwrt feed"
   ```
   Содержимое `usign.key` — в секрет репозитория **`USIGN_KEY`** (Settings → Secrets and
   variables → Actions). Открытый ключ CI выводит из приватного сам
   (`scripts/usign-pubkey.py`) и встраивает в прошивку, включая проверку подписи opkg.
   Без секрета фид не подписывается и прошивка его не проверяет (доставка — по HTTPS).
3. Workflow 2 запускается через `workflow_dispatch`, поэтому оба файла workflow должны
   быть в ветке по умолчанию (`main`).
