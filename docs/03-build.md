# Сборка

## Требования

- Linux, **не** WSL на диске `/mnt/c` — нужна нативная ext4
- ~40 ГБ свободного места, 8+ ГБ ОЗУ
- сборка **не от root** (OpenWrt намеренно это запрещает)
- доступ к `gitlab.com` и `git.openwrt.org`
- **дистрибутив с Python 2.x и GCC не новее 9.x** — см. ниже

## Про версию дистрибутива (важно)

База prplWrt — это OpenWrt 19.07, и её `include/prereq-build.mk`:

- требует **Python 2.x** (`python2.7 -V | grep 'Python 2.7'`);
- принимает GCC только по маске `4.8-9.x` — GCC 10 и новее не распознаётся.

Проверено на Ubuntu 24.04: подготовка дерева падает на
`Build dependency: Please install Python 2.x` и
`Please install the GNU C Compiler (gcc) 4.8 or later` (при установленном GCC 13).
Причём падение коварное: сначала молча получаются **пустые индексы фидов**,
внешний таргет не устанавливается, и `make defconfig` тихо скатывается на ath79.

Поэтому рекомендуемый путь — контейнер Ubuntu 20.04:

```bash
./scripts/docker-build.sh setup   # подготовка дерева
./scripts/docker-build.sh build   # сборка
# или сразу всё: ./scripts/docker-build.sh
```

Нативно (Ubuntu 20.04 или другой дистрибутив с python2 и GCC ≤ 9):

```bash
./scripts/00-deps.sh        # зависимости хоста
./scripts/10-setup-tree.sh  # дерево prplWrt + фиды Intel + поддержка AX50
./scripts/20-build.sh       # сборка
```

`10-setup-tree.sh` проверяет пригодность хоста до начала работы и отказывается
продолжать, если чего-то не хватает (обойти: `SKIP_PREFLIGHT=1`, но толку от этого мало).

Первая сборка: 2–4 часа на 8 ядрах (тулчейн gcc + ядро 4.9 + пакеты).
Повторная — минуты.

## Что именно делает `10-setup-tree.sh`

1. Клонирует базу prplWrt в `build/prplwrt`
   (`gitlab.com/aparcar/prplwrt`, ветка `prplwrt` — зеркало `git.prpl.dev/prplwrt/prplwrt`,
   OpenWrt 19.07-SNAPSHOT с сохранённой поддержкой ядра 4.9).
2. Кладёт `device/profiles/ax50.yml` в `build/prplwrt/profiles/`.
3. Запускает штатный `./scripts/gen_config.py ax50`. Этот скрипт prplWrt:
   - формирует `feeds.conf` из списка в профиле,
   - `./scripts/feeds update`, `install -a -p <feed>` по каждому фиду,
   - `./scripts/feeds install intel_mips` — установка **внешнего таргета**
     (появляется `target/linux/intel_mips` → симлинк в `feeds/feed_target_mips/intel_mips`),
   - пишет `.config` и запускает `make defconfig`.
4. **Переиндексирует фиды** (`./scripts/feeds update -i`), доустанавливает их и
   ставит внешний таргет (`./scripts/feeds install intel_mips`), после чего проверяет,
   что появился симлинк `target/linux/intel_mips`. Шаг не лишний: генерация индексов
   идёт через `make`, а тот сперва прогоняет проверку хостовых зависимостей — если
   она провалилась, индексы остаются пустыми и таргет молча не ставится.
5. Копирует `device/dts/tplink_ax50.dts` и `device/image/ax50.mk` в установленный таргет
   и добавляет `-include ax50.mk` в `intel_mips/image/Makefile`.
6. Дописывает `CONFIG_TARGET_intel_mips_xrx500_DEVICE_TPLINK_AX50=y`, снова `make defconfig`
   и **проверяет, что символ пережил defconfig** — если нет, скрипт падает с объяснением
   (это значит, что `ax50.mk` не подхватился или в DTS ошибка). Заодно печатает,
   выбрались ли ключевые пакеты (`kmod-iwlwav-driver-uci`, `ltq-wlan-wave_6x-uci` и т.д.).

Порядок именно такой, потому что `gen_config.py` на шаге 3 ещё не знает про наше
устройство и вычистил бы его символ из `.config`.

## Результат

```
build/prplwrt/bin/targets/intel_mips/xrx500/
  TPLINK_AX50-squashfs-sysupgrade.bin   # обновление уже работающей prplWrt
  TPLINK_AX50-squashfs-fullimage.img    # полный образ для заливки из U-Boot по TFTP
```

**Заводского (factory) образа для веб-интерфейса TP-Link здесь нет и не будет.**
Прошивки AX50 подписаны (в архиве файл называется `..._sign.bin`, в шапке
`soft-version`/`fw_id`/`support-list`), ключа у нас нет. Единственный путь установки —
U-Boot + TFTP через UART, см. [`04-flashing.md`](04-flashing.md).

## Настройка набора пакетов

```bash
cd build/prplwrt
make menuconfig      # Target intel_mips / xrx500 / Device TP-Link Archer AX50 v1
make -j$(nproc)
```

## Обновление до более свежего BSP

По умолчанию всё зафиксировано на комбинации, которую использует апстримный
профиль prplWrt (проверенно согласованной):

| Компонент | Пин |
|---|---|
| фиды Intel | ветка `ugw-8.4.1-cleanup` |
| ядро | `gitlab.com/prpl-foundation/intel/linux` @ `727acdb0604…` = **Linux 4.9.206** |
| таргет | `LINUX_VERSION:=4.9.206` в `intel_mips/xrx500/target.mk` — совпадает |

Есть более новые ветки: `ugw-8.4.2-cleanup` (ядро 4.9.218) и `ugw-8.5.2-cleanup`.
Чтобы попробовать их, поправьте `branch:` в `device/profiles/ax50.yml` и
`CONFIG_KERNEL_GIT_REF`. Учтите: в ветках `8.4.2`/`8.5.2` **изменилась раскладка
репозитория** `feed_target_mips` — таргет лежит в корне, а не в подкаталоге
`intel_mips/`, поэтому `feeds install intel_mips` и путь внедрения наших файлов
в `10-setup-tree.sh` придётся поправить. Это осознанная задача, а не «поменять строчку».

## Типичные проблемы

**`gen_config.py` падает на клонировании фида.** Проверьте сеть до gitlab.com.
Инфраструктура `git.prpl.dev`/`intel.prpl.dev` из многих сетей недоступна — именно
поэтому в профиле стоят зеркала.

**`make` падает на пакете.** Пересоберите его отдельно с логом:
```bash
cd build/prplwrt
make package/<имя>/{clean,compile} V=s
```

**Символ `TPLINK_AX50` не выживает после `defconfig`.** Значит `ax50.mk` не подключился.
Проверьте, что в `build/prplwrt/feeds/feed_target_mips/intel_mips/image/Makefile`
есть строка `-include ax50.mk`, а рядом лежит сам `ax50.mk`.

**Собирается, но образ больше `IMAGE_SIZE`.** Уменьшите набор пакетов или поднимите
`IMAGE_SIZE` в `device/image/ax50.mk` (раздел `system_sw` — 250 МиБ на два банка).

**Сборка в контейнере / за прокси.** OpenWrt отказывается собираться от root, поэтому
в контейнерах заводите отдельного пользователя. Учтите, что `su` не переносит
переменные окружения: если в системе настроен HTTPS-прокси и свой CA-бандл, их надо
передать явно и положить сертификат туда, куда сборочный пользователь имеет доступ:

```bash
useradd -m builder
cp /path/to/ca-bundle.crt /home/builder/ca.crt && chmod 644 /home/builder/ca.crt
su builder -c "env HTTPS_PROXY=$HTTPS_PROXY GIT_SSL_CAINFO=/home/builder/ca.crt \
    bash /path/to/scripts/10-setup-tree.sh"
```

Симптом непереданного CA — `fatal: unable to access ...: Problem with the SSL CA cert`
на первом же `git clone`.
