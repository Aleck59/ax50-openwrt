# Сборка

## Коротко

```bash
git clone https://github.com/Aleck59/ax50-openwrt.git && cd ax50-openwrt
scripts/docker.sh              # prepare + configure + build, результат в build/prplwrt/bin/
```

Нужны Docker, ~40 ГБ диска, 8+ ГБ ОЗУ. Первая сборка — 1.5–3 часа на 4 ядрах
(тулчейн GCC 7.5, ядро 4.9, пакеты), повторные — минуты.

## Почему Docker

База prplWrt — OpenWrt 19.07: её `prereq-build.mk` требует Python 2 и не распознаёт GCC
новее 9. Контейнер Ubuntu 20.04 (`docker/Dockerfile`) даёт ровно это. OpenWrt не
собирается от root, поэтому в контейнере сборка идёт от пользователя с вашим UID.

За TLS-прокси: `EXTRA_CA=/путь/к/ca.crt scripts/docker.sh ...` — сертификат встраивается в образ.

## Этапы

| Скрипт | Что делает |
|---|---|
| `scripts/prepare.sh` | клонирует prplWrt на коммите из `config/versions.env`, ставит фиды из `config/feeds.conf` (каждый на коммите), откатывает прошлые правки, накладывает `patches/`, копирует `target/` во внешний таргет `intel_mips`, `files/` — в оверлей rootfs |
| `scripts/configure.sh` | `.config` из `config/image.config` (+ `kmods.config`, SDK), версия и адрес фида; проверяет, что каждый запрошенный пакет выбран |
| `scripts/build.sh` | `make download` и `make -jN`; при ошибке — повтор `-j1 V=s`. С аргументами — произвольные цели make |
| `scripts/collect.sh` | образы с понятными именами, манифест, SDK, архив пакетов, `sha256sums` |
| `scripts/feed-build.sh` | фид пакетов через SDK (workflow 2) |

```bash
scripts/docker.sh scripts/prepare.sh
WITH_KMODS=1 WITH_SDK=1 scripts/docker.sh scripts/configure.sh
scripts/docker.sh scripts/build.sh
scripts/docker.sh scripts/build.sh package/zapret/{clean,compile} V=s   # один пакет
scripts/docker.sh shell                                                  # оболочка в окружении
```

## Устройство репозитория

```
config/          версии исходников, фиды, состав образа, модули и пакеты фида
target/linux/intel_mips/
  dts/           DTS Archer AX50 v1
  image/         рецепт образа (TPLINK_AX50)
patches/
  prplwrt/       дерево prplWrt (подписанная wireless-regdb)
  feed_target_mips/  подключение рецепта образа
  feed_wlan_6x/  hostapd: возможности для LuCI (WPA3); без MAC-хака RAX40
package/         свой фид «ax50»
  ax50-base-files      MAC, порты, светодиоды, WPS, Wi-Fi по умолчанию, ax50-backup
  adguardhome          + luci-app-adguardhome
  zapret               + luci-app-zapret
  luci-theme-footstrap порт темы на LuCI 19.07
scripts/         сборка, CI, вспомогательные утилиты
tools/luci-bench/  стенд LuCI 19.07 для проверки веб-интерфейса
docker/          окружение сборки
```

## Что закреплено

| Компонент | Версия |
|---|---|
| prplWrt | `gitlab.com/aparcar/prplwrt` @ `2377bf9` (OpenWrt 19.07-SNAPSHOT) |
| Ядро | `gitlab.com/prpl-foundation/intel/linux` @ `727acdb` = Linux 4.9.206 |
| BSP Intel | фиды `prpl-foundation/intel/*`, ветка `ugw-8.4.1-cleanup` |
| packages / luci / routing / telephony | финальные коммиты ветки `openwrt-19.07` |

Это комбинация, которую prpl Foundation использует для Netgear RAX40. Более новые ветки
BSP (`ugw-8.4.2/8.5.2-cleanup`) существуют, но меняют раскладку `feed_target_mips` —
переход требует отдельной работы.

## Изменения во внешнем коде

Только патчами: `patches/<prplwrt|имя фида>/NNNN-описание.patch` (unified diff, путь от
корня фида, `-p1`). `prepare.sh` каждый раз возвращает фиды к закреплённому коммиту и
накладывает патчи заново, так что дерево сборки можно не беречь.

## Проверки перед коммитом

```bash
scripts/lint.sh                   # shellcheck, JSON/JS/Python, формат патчей
tools/luci-bench/run.sh start     # стенд LuCI 19.07 (Docker) — для страниц и темы
```
