# Эталон успешной сборки

Здесь лежат артефакты первой успешной сборки — по ним можно сверять свою.

Собрано в чистом окружении Ubuntu 20.04 (GCC 9, Python 2.7.18) на 4 ядрах.

## Что получилось

| Файл | Размер | Назначение |
|---|---|---|
| `TPLINK_AX50-initramfs-kernel.bin` | 9.2 МБ | загрузка в ОЗУ по TFTP — безопасная проверка без записи во flash |
| `TPLINK_AX50-squashfs-fullimage.img` | 11.2 МБ | полный образ для заливки из U-Boot |
| `TPLINK_AX50-squashfs-sysupgrade.bin` | 11.2 МБ | обновление уже работающей системы |

Контрольные суммы этой сборки — в [`sha256sums`](sha256sums). Совпадать с вашими
они не обязаны: сборка не побитово воспроизводима.

## Проверка образа

`fullimage.img` разбирается тем же скриптом, что и стоковая прошивка:

```
$ ./scripts/extract-stock-firmware.sh TPLINK_AX50-squashfs-fullimage.img out/

  смещение     размер         тип  сжатие  имя
         0   11191976       multi    none  OpenWrt fullimage
        72    2133456      kernel    lzma  MIPS OpenWrt Linux-...
   2133592    9058384  filesystem    lzma  LEDE RootFS

   Linux version 4.9.206 (gcc version 7.5.0 (OpenWrt GCC 7.5.0 r0-2377bf9))
   DTB найден, декомпилирован
```

Структура та же, что у заводской прошивки TP-Link (uImage multi: ядро + rootfs),
только ядро 4.9.206 вместо 3.10.104.

DTB внутри собранного ядра содержит:

- `model = "TP-Link Archer AX50 v1"`,
  `compatible = "tplink,archer-ax50-v1", "intel,easy350_anywan", "lantiq,grx500", "lantiq,xrx500"`
- разметку NAND один в один как в стоке: `uboot`, `ubootconfigA/B`, `gphyfirmware`,
  `calibration` (`0x1c0000`, 1 МиБ), `system_sw` (`0x2c0000`, 250 МиБ), `res` (`0xfcc0000`)
- алиасы `led-wifi`/`led-usb`/`led-internet` и три кнопки

В rootfs присутствуют:

| Что | Где |
|---|---|
| Wi-Fi-драйвер, собранный **из исходников** | `lib/modules/4.9.206/mtlk.ko` (1.99 МБ) + `mtlkroot.ko` |
| стек 802.11 | `cfg80211.ko`, `mac80211.ko`, `compat.ko` |
| hostapd от MaxLinear | `usr/sbin/hostapd` (1.4 МБ) |
| прошивки радио WAV600 | `lib/firmware/PSD.bin`, `ProgModel_gen6*`, regulatory-базы |
| наша настройка портов | `etc/board.d/03_ax50_network` |
| Ethernet и ускорение | `dc_mode0-xrx500.ko`, `directconnect_datapath.ko`, `hw_litepath.ko`, PPA |

Всего 98 модулей ядра и 137 пакетов ([`packages.manifest`](packages.manifest)).

Для сравнения: в стоковой прошивке `mtlk.ko` — бинарь версии
`06.00.08.00.87.00.07.d24084bd3447`, намертво привязанный к ядру 3.10.104.
Здесь тот же драйвер собран из открытых исходников `iwlwav`
(коммит `b80447a3f728…`) под ядро 4.9.206.

## Важно

Образы **не проверены на живом устройстве**. Начинать нужно с загрузки
`initramfs-kernel.bin` в ОЗУ по TFTP — она ничего не пишет во flash.
См. [`../../docs/04-flashing.md`](../../docs/04-flashing.md).
