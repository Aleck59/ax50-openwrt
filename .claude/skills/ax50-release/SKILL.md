---
name: ax50-release
description: Выпуск версии прошивки ax50-openwrt — тег, GitHub Release, сборка фида пакетов вторым workflow, публикация на GitHub Pages, подпись фида usign. Использовать, когда нужно выпустить релиз, перезапустить сборку фида или разобраться с CI/CD.
---

# Релизы и фид пакетов

## Два workflow

1. **`.github/workflows/firmware.yml` (Прошивка)** — на каждый push: `scripts/lint.sh` и
   полная сборка (артефакты в Actions). На тег `v*` дополнительно job «Релиз»:
   GitHub Release с образами, `*-sdk.tar.xz`, `*-packages.tar.gz` (модули ядра +
   пакеты образа), `sha256sums`, и запуск workflow 2 через `gh workflow run`.
2. **`.github/workflows/packages.yml` (Фид пакетов)** — `workflow_dispatch(release_tag)`:
   SDK релиза собирает `config/feed-packages.txt` (`scripts/feed-build.sh`), раскладывает
   по схеме downloads.openwrt.org в `releases/dev/` (один адрес для всех версий, каждый
   релиз его перезаписывает), кладёт `*-feed.tar.gz` в релиз и публикует сайт на GitHub
   Pages (`scripts/feed-site.sh`).

`workflow_dispatch` и запуск из job работают, только когда файл workflow есть в ветке по
умолчанию (`main`).

Фид в SDK: пакеты образа (`CONFIG_DEFAULT_*`) не пересобираются — они берутся из
`*-packages.tar.gz` и в фиде имеют приоритет (`cp -n`). `!пакет` в `feed-packages.txt`
исключает пакет. Локально:
`scripts/docker.sh scripts/feed-build.sh /work/out/<sdk> /work/out/<packages> <тег> /work/site`;
`FEED_REUSE_SDK=1` — только переиндексировать уже собранное в `build/sdk`.
Изменения только фида/документации (`paths-ignore`) не перезапускают сборку прошивки.

## Выпуск

```bash
git tag -a v1.2.0 -m "AX50 OpenWrt v1.2.0"
git push origin v1.2.0
```

Без права push тегов (сессия Claude): Actions → «Прошивка» → Run workflow на `main`,
`release_tag` = `v1.2.0` — workflow соберёт образ, сам создаст тег на этом коммите
(`gh release create --target`) и релиз, затем запустит фид. Запуск через API:
`actions_run_trigger run_workflow`, `workflow_id: firmware.yml`, `ref: main`.

Тег с дефисом (`v1.2.0-rc1`) — пререлиз. Адрес фида зашит в прошивку через
`CONFIG_VERSION_REPO`: `https://<owner>.github.io/<repo>/releases/dev` → `/etc/opkg/distfeeds.conf`
— у всех сборок, с тегом и без.

Пакеты, зависящие от модулей ядра (uqmi, usbip, alsa-utils…), SDK не соберёт — модулей
в нём нет. Такие пакеты — в `config/kmods.config` (=m, собирает workflow 1).

Перезапуск фида: Actions → «Фид пакетов» → Run workflow → тег.

## Настройка репозитория (однократно, делает владелец)

- Settings → Pages → Source: **GitHub Actions** (без этого job «Публикация» предупредит, а
  фид будет только архивом в релизе).
- Подпись фида: `usign -G -s usign.key -p usign.pub -c "ax50-openwrt feed"`, содержимое
  `usign.key` → секрет `USIGN_KEY`. Открытый ключ выводится из приватного
  (`scripts/usign-pubkey.py`), в прошивке включается `check_signature`. Без секрета фид
  не подписан, и прошивка его не проверяет (HTTPS остаётся).
