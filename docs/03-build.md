# Сборка

## Требования

- Linux (Debian/Ubuntu проверены), **не** WSL на диске `/mnt/c` — нужна нативная ext4
- ~40 ГБ свободного места, 8+ ГБ ОЗУ
- сборка **не от root** (OpenWrt намеренно это запрещает)
- доступ к `gitlab.com` и `git.openwrt.org`

## Три команды

```bash
./scripts/00-deps.sh        # зависимости хоста
./scripts/10-setup-tree.sh  # дерево prplWrt + фиды Intel + поддержка AX50
./scripts/20-build.sh       # сборка
```

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
4. Копирует `device/dts/tplink_ax50.dts` и `device/image/ax50.mk` в установленный таргет
   и добавляет `-include ax50.mk` в `intel_mips/image/Makefile`.
5. Дописывает `CONFIG_TARGET_intel_mips_xrx500_DEVICE_TPLINK_AX50=y`, снова `make defconfig`
   и **проверяет, что символ пережил defconfig** — если нет, скрипт падает с объяснением
   (это значит, что `ax50.mk` не подхватился или в DTS ошибка).

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
