# Установка, обновление, восстановление

> ⚠️ Прошивка экспериментальная. Каждый шаг ниже построен так, чтобы оставалась дорога
> назад, — не пропускайте резервную копию и загрузку в ОЗУ.

Стоковые прошивки TP-Link подписаны, а веб-интерфейс стока проверяет подпись, поэтому
первая установка — только из загрузчика U-Boot через последовательную консоль (UART) и
TFTP. U-Boot AX50 подпись не проверяет: команда `upgrade` принимает любой uImage multi
(«ядро + rootfs»), именно такой у нас `*-squashfs-fullimage.img`.

## Что понадобится

- USB-UART адаптер **3.3 В** (CP2102, CH340, FT232 и т.п.), 115200 8N1, без управления потоком;
- компьютер с TFTP-сервером (Linux: `tftpd-hpa`/`dnsmasq`, Windows: Tftpd64) и
  статическим адресом **192.168.1.2/24**, кабель в любой LAN-порт роутера;
- файлы из [релиза](https://github.com/Aleck59/ax50-openwrt/releases): `*-initramfs-kernel.bin`,
  `*-squashfs-fullimage.img`.

Разъём UART на плате — четыре контакта (GND, TX, RX, VCC). Определите GND прозвонкой,
TX — по выводу лога при включении. **VCC не подключайте.** Сразу после подачи питания
нажимайте любую клавишу, чтобы остановить автозагрузку.

## 1. Резервная копия заводских данных

Раздел `calibration` (калибровка радио) уникален для каждого роутера и не
восстанавливается ниоткуда. Из U-Boot его можно снять в ОЗУ и сохранить по TFTP, если в
вашей версии загрузчика есть `tftpput`; иначе — сразу после шага 2 из Linux в ОЗУ:

```sh
ax50-backup /tmp
# с компьютера:
scp root@192.168.1.1:/tmp/ax50-backup-*.tar.gz .
```

В архив попадают `uboot`, `ubootconfigA/B`, `gphyfirmware`, `calibration`, `res` и
содержимое UBI-тома `data_vol`. Заодно сохраните вывод `printenv` из консоли U-Boot.

## 2. Проверка без записи — загрузка в ОЗУ

```
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.2
tftpboot 0x86000000 ax50-openwrt-vX.Y.Z-initramfs-kernel.bin
run ramargs addmisc
bootm 0x86000000
```

Адрес `0x86000000`, а не `$(loadaddr)` (`0x80800000`): ядро распаковывается с
`0x80020000`, и образ с initramfs (~17 МБ, в распакованном виде больше) затирает
архив, лежащий на `loadaddr` — U-Boot останавливается с
`LZMA: uncompress or overwrite error 1`. ОЗУ у U-Boot 224 МБ (до `0x8E000000`).

(`addmisc` добавляет `mtdparts` и `mem=256M@512M` из окружения стока.) Система
полностью работает в памяти; после перезагрузки снова стартует сток. Проверьте:

```sh
cat /proc/mtd                     # разделы как в docs/hardware.md
logread | grep ax50               # откуда взят MAC
ls /tmp/wlanconfig                # cal_wlan0.bin, cal_wlan2.bin — калибровка прочитана
iw dev                            # интерфейсы Wi-Fi
ip link                           # eth0_1..eth0_4, eth1
```

LuCI доступна на http://192.168.1.1. Сделайте резервную копию (шаг 1), если ещё нет.

## 3. Установка во флеш

Из консоли U-Boot:

```
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.2
setenv fullimage ax50-openwrt-vX.Y.Z-squashfs-fullimage.img
run update_fullimage
reset
```

`update_fullimage` — штатный макрос стока: записывает образ в банки B и A тома
`system_sw`. Прошивка работает из банка A (`kernelA/rootfsA`, переменная `active_bank=A`).
Тома `data_vol` (данные TP-Link) и разделы `uboot`, `calibration` не затрагиваются.

Что нормально увидеть в консоли при первой установке поверх стока:

- `UBI error: ubi_create_volume: cannot create volume 3, error -17` и
  `kernelB volume not found` (то же для `rootfsB`): номера томов в окружении U-Boot
  (`kernelB_id=3`, `rootfsB_id=4`) заняты стоковыми `rootfsB` и `data_vol`, поэтому банк
  B не создаётся. Старые `kernelB/rootfsB` при этом удаляются — освобождается место.
  Банк A записывается (`Volume "kernelA" found ...`), этого достаточно.
- `Erasing Nand... Writing to Nand... done` и `Erasing redundant Nand...` — это сохранение
  окружения U-Boot (обе копии), а не запись образа в сырую флеш.

При первой загрузке создаётся том `rootfs_data` (настройки) на всё свободное место
`system_sw` — так же его создаёт `sysupgrade`.

## 4. Обновление установленной прошивки

LuCI: «Система → Восстановить / обновить» → `*-squashfs-sysupgrade.bin`. Или в консоли:

```sh
sysupgrade -v /tmp/ax50-openwrt-vX.Y.Z-squashfs-sysupgrade.bin
```

Настройки AdGuard Home, zapret, темы и кэш MAC сохраняются (списки в `/lib/upgrade/keep.d/`).

## Возврат на стоковую прошивку

Файл с сайта TP-Link (`*_sign.bin`) начинается с заголовка подписи — сначала вырежьте
из него образ для загрузчика:

```bash
scripts/stock-totalimage.py ax50v1_intel-up-...-sign.bin totalimage.img
```

и залейте его из U-Boot:

```
setenv totalimage totalimage.img
run update_totalimage
reset
```

«TP-Link Totalimage» содержит ядро, rootfs, прошивку GPHY и U-Boot — система
восстанавливается целиком.

## Если что-то пошло не так

- **Есть консоль U-Boot** — всё поправимо: повторите шаг 2 или 3. Если OpenWrt уже
  стоял, `rootfs_data` занимает всё свободное место и новый образ большего размера не
  поместится — сначала удалите этот том (настройки сбросятся):
  ```
  run ubi_init
  ubi remove rootfs_data
  run update_fullimage
  ```
- **Не поднимается Wi-Fi** — `logread | grep -i -E 'mtlk|wlan|hostapd'`, `ls /tmp/wlanconfig`;
  пришлите вывод в issues.
- **Неверные MAC-адреса** — `logread | grep ax50`; адрес можно задать вручную в
  «Сеть → Интерфейсы» и «Беспроводная сеть».
- **Загрузчик молчит** — повреждён `uboot`, нужен программатор NAND и резервная копия.
