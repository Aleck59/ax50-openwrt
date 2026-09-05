# Откуда Archer AX50 берёт MAC-адреса

Разобрано по GPL-коду TP-Link (`ax50v1_GPL_3.tar.gz`) и по распакованной
стоковой прошивке 1.1.2 Build 20251022.

## Короткий ответ

Все адреса устройства выводятся из **одного базового MAC** арифметикой ±1:

| Интерфейс | Адрес |
|---|---|
| LAN (и мост br-lan) | `base` |
| WAN | `base + 1` |
| Wi-Fi 2.4 ГГц | `base − 1` |
| Wi-Fi 5 ГГц | `base − 2` |

Базовый MAC лежит в программном разделе TP-Link с именем **`default-mac`**
в виде текстовой строки `MAC:XX-XX-XX-XX-XX-XX`.

## Цепочка вызовов в стоке (всё это есть в GPL)

`Iplatform/packages/opensource/base-filesystem/filesystem/sbin/getfirm` — тот же
файл, что лежит в прошивке как `/sbin/getfirm`:

```sh
MAC)
mac_file="/tmp/default-mac-"$$
nvrammanager -r $mac_file -p default-mac >/dev/null 2>&1
if [ -s $mac_file ];then
        echo $(grep 'MAC'  $mac_file | cut -d : -f 2-)
else
        ...
        echo  $factoryLanMac        # запасной адрес 00-0A-EB-13-7B-00
fi
```

`/sbin/network_get_firm` — из базового делает адреса интерфейсов:

```sh
local mac=$(getfirm MAC)

if   [ "$1" == "lan" ];          then echo $mac
elif [ "$1" == "wan" ];          then mac=$(inc_mac $mac); echo $mac
elif [ "$1" == "wireless_2.4" ]; then mac=$(dec_mac $mac); echo $mac
elif [ "$1" == "wireless_5" ];   then mac=$(dec_mac $mac); mac=$(dec_mac $mac); echo $mac
```

`inc_mac`/`dec_mac` меняют только младшие три байта (в awk-цикле условие `i>3`),
то есть OUI не трогается.

Дальше `/sbin/network_firm` (Lua) раскладывает это по UCI, а `/sbin/ifmac`
применяет `macaddr` из `/etc/config/network` к интерфейсу через `ifconfig hw ether`.
Wi-Fi берёт свой адрес в `/lib/wifi/tplink_intel.sh` тем же `network_get_firm`.

## Где физически лежит `default-mac`

Здесь GPL заканчивается. `nvrammanager` — **проприетарный**: в его же пакетном
описании из прошивки указано
`Source: /home/jenkins/workspace/Router/Archer_AX50_1.0/Iplatform/packages/private/nvrammanager`,
а в GPL-архиве опубликован только каталог `Iplatform/packages/opensource/`.
Каталога `private/` там нет, как нет и драйвера `/dev/flash_chrdev`, через который
`nvrammanager` работает с флеш-памятью.

Что удалось установить по бинарнику `usr/bin/nvrammanager` (MIPS ELF):

- он ведёт **собственную программную таблицу разделов** поверх MTD: в строках
  видны `partition-table`, `default-mac`, `pin`, `device-id`, `product-info`,
  `soft-version`, `support-list`, `user-config`, `ap-config`, `router-config`,
  `radio`, `radio_bk`;
- работает и через `/proc/mtd` + `/dev/mtd%d`, и через `/dev/flash_chrdev`;
- умеет `--derive=FILE` — вытаскивать таблицу разделов из файла прошивки;
- сама таблица читается из флеша (`nvrammanager_readPtnFromNvram`), а не из rootfs.

Файл `/etc/partition_config/partition-table` в прошивке есть, но это **шаблон
для 16 МБ NOR** (в шапке прямо написано `total=25,  flash=16M`, разделы идут по
смещениям `0x00e80000`…). У AX50 флеш-память — 256 МиБ NAND с совсем другой
разметкой, так что этот файл к нему не относится: он используется на этапе
сборки заводского образа, а не в рантайме.

В самом файле прошивки таблицы тоже нет: AX50 использует формат Intel/Lantiq
(`TP-Link Totalimage` = uImage multi), а не старый TP-Link-формат с секциями
`fwup-ptn` — поиск по образу строк `fwup-ptn`, `partition-table` и `default-mac`
не даёт ничего.

**Вывод:** по открытым исходникам определить, в каком именно MTD-разделе AX50
хранит `default-mac`, невозможно. Наиболее вероятные кандидаты по разметке —
`res` (`0xfcc0000`, 3.25 МиБ, «резерв») и `calibration` (`0x1c0000`, 1 МиБ).
Это проверяется на устройстве за минуту.

## Как проверить на своём роутере

Из работающей системы (или по дампам, снятым `scripts/backup-router.sh`):

```bash
./scripts/find-mac.sh                      # на устройстве, все /dev/mtd*
./scripts/find-mac.sh backups/ax50-.../    # на компьютере, по бэкапу
```

Скрипт ищет строку `MAC:XX-XX-...` (формат `default-mac`), переменную `ethaddr`
из окружения U-Boot и просто похожие на MAC последовательности. Найденный
базовый адрес должен совпасть с MAC LAN на наклейке корпуса.

## Как это учтено в нашей прошивке

`device/files/etc/board.d/03_ax50_network` перебирает источники по порядку:

1. `mtd_get_mac_ascii ubootconfigA ethaddr` — окружение U-Boot; так же поступает
   штатный `02_network` таргета для плат EASY350, а загрузчик у AX50 из той же
   линейки Intel;
2. поиск строки `MAC:XX-XX-…` в разделах `res`, затем `calibration`.

Что сработало — пишется в системный журнал с тегом `ax50`, смотреть через
`logread | grep ax50`. WAN получает `base + 1`, как в стоке.

Адреса Wi-Fi (`base − 1` и `base − 2`) здесь не выставляются: драйвер `iwlwav`
берёт их из своих данных, и как именно он это делает на AX50 — вопрос,
требующий проверки на железе. Если адреса окажутся не те, их можно задать
вручную в `/etc/config/wireless`.

> Раздел `calibration` содержит калибровку радио и заводские адреса.
> Он уникален для каждого экземпляра и не восстанавливается ниоткуда —
> не стирайте его и снимите дамп до любых экспериментов.
