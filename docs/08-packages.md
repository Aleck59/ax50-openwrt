# Репозиторий пакетов

Образ прошивки намеренно компактный — в нём только то, без чего роутер не роутер.
Всё остальное ставится через `opkg` из собранного репозитория пакетов.

## Сборка

```bash
./scripts/10-setup-tree.sh      # если дерева ещё нет
./scripts/20-build.sh           # образ
./scripts/30-build-packages.sh  # ВСЕ пакеты как .ipk
```

В контейнере:

```bash
./scripts/docker-build.sh setup
./scripts/docker-build.sh build
docker run --rm -v "$PWD:/work" -e BUILD_DIR=/work/build ax50-build \
    bash /work/scripts/30-build-packages.sh
```

Результат — два дерева, оба нужны:

```
build/prplwrt/bin/packages/mips_24kc_nomips16/   # userspace, по фидам
    base/ packages/ luci/ routing/ telephony/ feed_wlan_6x/ feed_ppa/ ...
build/prplwrt/bin/targets/intel_mips/xrx500/packages/   # модули ядра
```

Архитектура пакетов для AX50 — **`mips_24kc_nomips16`**.

## Что реально собирается

Проверено полным прогоном на 4 ядрах (Ubuntu 20.04):

| Фид | Собрано |
|---|---:|
| `packages` | 3735 |
| `luci` | 2112 |
| модули ядра | 693 |
| `base` | 414 |
| `telephony` | 361 |
| `routing` | 90 |
| фиды Intel (Wi-Fi, PPA, GPHY, switch) | 20 |
| **всего** | **7425** |

Объём — 714 МБ. Полный список с версиями:
[`reference/build/packages-list.txt`](../reference/build/packages-list.txt).

Не собралось 52 пакета из ~8280 выбранных (0.6%). Из них важных для этого
роутера нет ни одного: `mac80211`, `mt76`, `ath10k-ct`, `ath10k-firmware`,
`linux-firmware` — чужие Wi-Fi-стеки (у нас `iwlwav` со своим backport),
`swconfig` — вместо него вендорский `switch_cli`, `ltq-xrx500-bootcore` —
требует приватного SDK. Остальное — модули Perl, `golang`, `ruby`, `postfix`,
`openvswitch`, `freeradius3` и подобное: фиды 19.07 датированы 2019-2021
годами, часть исходников по исходным URL уже недоступна, часть не дружит
со старым тулчейном.

## Как это работает

В OpenWrt каждый пакет объявлен в конфигурации как `default m if ALL`.
Поэтому `30-build-packages.sh` просто включает `CONFIG_ALL=y` и `CONFIG_ALL_KMODS=y`
и пересобирает дерево: всё становится модулями (`=m`), то есть собирается
в `.ipk`, но **в образ не попадает** — образ остаётся прежнего размера.

Сборка идёт с `IGNORE_ERRORS=m`: в фидах OpenWrt 19.07 часть пакетов давно
не чинилась, и без этого один сломанный пакет обрушил бы всю сборку.
Что не собралось — просто не появится в репозитории.

Предыдущая конфигурация сохраняется в `build/prplwrt/.config.image-only`,
вернуться к сборке «только образ»:

```bash
cd build/prplwrt && cp .config.image-only .config && make defconfig
```

## Почему без подготовки ядра не собирается

При включении всех пакетов в сборку попадают все kmod-пакеты OpenWrt. Они
рассчитаны на ядро, собранное с generic-патчами OpenWrt, а у нас ядро
Intel/MaxLinear 4.9 со своим набором патчей. Часть kmod ломается, и ломается
неудачно: не отдельный пакет, а целые шаги `target/linux/compile` и
`package/kernel/linux/compile`. `IGNORE_ERRORS=m` их не покрывает — он про
сборку обычных пакетов, — поэтому один сбойный kmod обрывает сборку всех
остальных. Именно так первый прогон дал 228 пакетов вместо 1192.

`scripts/lib/fix-kernel-build.sh` (вызывается из `30-build-packages.sh`)
крутит цикл «собрать → разобрать ошибку → отключить виновника → собрать снова»
и знает четыре случая:

| Симптом | Что делает |
|---|---|
| `(WILC1000_SDIO) [N/m/?] (NEW) aborted!` — новый символ ядра без умолчания | дописывает `# CONFIG_<символ> is not set` в конфиг ядра таргета |
| `No rule to make target 'drivers/misc/owl-loader.c'` | находит, какой `KernelPackage` тянет этот файл, и отключает пакет |
| `Package kmod-video-videobuf2 is missing dependencies ... dma-shared-buffer.ko` | отключает пакет |
| падение на конкретном `.ipk` | берёт имя пакета из пути и отключает |

Важная деталь: просто убрать пакет из `.config` мало. OpenWrt превращает
зависимость `+foo` в `select PACKAGE_foo`, поэтому любой оставшийся зависимый
пакет включает его обратно, и цикл крутится вечно на одном месте (проверено —
именно это и произошло). Поэтому вместе с виновником гасятся все, кто на него
ссылается, транзитивно: например, отключение `kmod-video-videobuf2` уводит с
собой 37 kmod для USB-веб-камер, которые роутеру всё равно не нужны.

Список отключённого остаётся в `build/prplwrt/.packages-disabled`.

## Сколько это занимает

Заметно дольше и прожорливее, чем один образ: часы работы и десятки гигабайт
на диске. На бесплатных раннерах GitHub задача упирается и в лимит времени
(6 часов на job), и в объём диска, поэтому в CI она вынесена в отдельный job
`packages`, который запускается только вручную — Actions → build → Run workflow →
галочка «Дополнительно собрать ВСЕ пакеты». Надёжнее собирать пакеты локально
или на своём раннере.

## Как подключить репозиторий к роутеру

### Вариант 1: локальный HTTP-сервер

Сложите оба дерева в один каталог — модули ядра удобно положить в `kmods/`:

```bash
mkdir -p /srv/ax50 && cd /srv/ax50
cp -a .../bin/packages/mips_24kc_nomips16/. .
mkdir -p kmods && cp -a .../bin/targets/intel_mips/xrx500/packages/. kmods/
python3 -m http.server 8080
```

На роутере — источники в `/etc/opkg/customfeeds.conf`
(IP компьютера подставьте свой):

```
src/gz ax50_base      http://192.168.1.100:8080/base
src/gz ax50_kmods     http://192.168.1.100:8080/kmods
src/gz ax50_packages  http://192.168.1.100:8080/packages
src/gz ax50_luci      http://192.168.1.100:8080/luci
src/gz ax50_routing   http://192.168.1.100:8080/routing
src/gz ax50_telephony http://192.168.1.100:8080/telephony
src/gz ax50_wave      http://192.168.1.100:8080/feed_wlan_6x
```

Затем:

```sh
opkg update
opkg install <пакет>
```

### Вариант 2: с USB-флешки

Скопировать каталог с пакетами на флешку, смонтировать её на роутере и указать
`src/gz ax50_base file:///mnt/sda1/packages/base` — `opkg` умеет `file://`.

### Подпись

Наши пакеты не подписаны, поэтому `opkg` будет ругаться на отсутствие подписи.
Либо добавьте `option check_signature 0` в `/etc/opkg.conf`, либо подпишите
репозиторий своим ключом (`CONFIG_SIGNED_PACKAGES` в конфигурации сборки).

## Важное ограничение

Пакеты собраны под **ядро 4.9.206 и userspace OpenWrt 19.07**. Пакеты из
официальных репозиториев OpenWrt (23.05, 24.10 и новее) сюда не подойдут:
другая libc, другой ABI ядра, другие версии библиотек. Всё, что нужно,
собирается только из этого дерева.
