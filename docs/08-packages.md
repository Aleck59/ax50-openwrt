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

Результат:

```
build/prplwrt/bin/packages/mips_24kc_nomips16/
    base/            Packages  Packages.gz  *.ipk
    packages/        ...
    luci/            ...
    routing/  telephony/  feed_wlan_6x/  feed_ppa/  ...
```

Архитектура пакетов для AX50 — **`mips_24kc_nomips16`**.

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

## Сколько это занимает

Заметно дольше и прожорливее, чем один образ: часы работы и десятки гигабайт
на диске. На бесплатных раннерах GitHub задача упирается и в лимит времени
(6 часов на job), и в объём диска, поэтому в CI она вынесена в отдельный job
`packages`, который запускается только вручную — Actions → build → Run workflow →
галочка «Дополнительно собрать ВСЕ пакеты». Надёжнее собирать пакеты локально
или на своём раннере.

## Как подключить репозиторий к роутеру

### Вариант 1: локальный HTTP-сервер

На компьютере, где лежит сборка:

```bash
cd build/prplwrt/bin/packages/mips_24kc_nomips16
python3 -m http.server 8080
```

На роутере — добавить источники в `/etc/opkg/customfeeds.conf`
(IP компьютера подставьте свой):

```
src/gz ax50_base     http://192.168.1.100:8080/base
src/gz ax50_packages http://192.168.1.100:8080/packages
src/gz ax50_luci     http://192.168.1.100:8080/luci
src/gz ax50_routing  http://192.168.1.100:8080/routing
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
