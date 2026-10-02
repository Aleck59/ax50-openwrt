# Железо TP-Link Archer AX50 v1

Всё ниже установлено по двум первоисточникам:

- GPL-архив TP-Link [`ax50v1_GPL_3.tar.gz`](https://static.tp-link.com/upload/gpl-code/2022/202211/20221107/ax50v1_GPL_3.tar.gz)
  (SDK UGW-7.5.1.50, конфиг продукта `Iplatform/build/product_configs/ax50v1/`);
- прошивка 1.1.2 Build 20251022 (`ax50v1_intel-up-ver1-1-2-P1[20251022-rel69668]_sign.bin`):
  DTB из ядра, rootfs, U-Boot.

## Платформа

| | |
|---|---|
| SoC | Intel/MaxLinear GRX350 (xRX500), MIPS interAptiv, **big-endian** |
| ОЗУ | 256 МБ DDR3 (`CONFIG_UBOOT_CONFIG_DDR_256M`, ядру — `mem=256M@512M`) |
| Флеш | **128 МБ NAND** (`CONFIG_UBOOT_CONFIG_NAND_FLASH_128M`), страница 2 КБ, блок 128 КБ, BCH |
| Wi-Fi | MaxLinear WAV654 (WAV600), 2×2 2.4 ГГц + 2×2 5 ГГц, PCIe |
| Ethernet | GSWIP-3.1, 5 внутренних GPHY, прошивка GPHY в разделе `gphyfirmware` |
| Референс | EASY350 ANYWAN AxePoint (профиль SDK `easy350_anywan_axepoint`) |

Пакеты собираются под архитектуру `mips_24kc_nomips16` (big-endian, soft-float).

## Разметка NAND

U-Boot стока передаёт ядру (`mtdparts` в `addmisc`):

```
mtdparts=17c00000.nand-parts:1m(uboot),256k(ubootconfigA),256k(ubootconfigB),
         256k(gphyfirmware),1m(calibration),124m(system_sw),-(res)
```

| Раздел | Смещение | Размер | Содержимое |
|---|---|---|---|
| `uboot` | 0x0000000 | 1 МБ | загрузчик — **не трогать** |
| `ubootconfigA/B` | 0x0100000 | 2×256 КБ | окружение U-Boot (две копии) |
| `gphyfirmware` | 0x0180000 | 256 КБ | прошивка встроенных PHY |
| `calibration` | 0x01C0000 | 1 МБ | **калибровка Wi-Fi — уникальна, не трогать** |
| `system_sw` | 0x02C0000 | 124 МБ | UBI: `kernelA/rootfsA`, `kernelB/rootfsB`, `data_vol`, `rootfs_data` |
| `res` | 0x7EC0000 | 1.25 МБ | резерв |

У референс-платы AxePoint вместо начала `system_sw` есть `Bootcore` (16 МБ) — у AX50
его нет. В нашем DTS разметка совпадает со стоком, служебные разделы — только чтение.

## Калибровка Wi-Fi

Формат одинаков в стоке (UGW, `/usr/sbin/vol_mgmt read_calibration`) и в prplWrt
(`/lib/preinit/91_wireless_calib` из пакета `iwlwav-driver-uci`):

```
MTD calibration  =  tar.gz
                     └── wlanconfig.gz  =  tar.gz
                          ├── cal_wlan0.bin   2.4 ГГц
                          └── cal_wlan2.bin   5 ГГц
```

При загрузке файлы распаковываются в `/tmp/wlanconfig/`, `/lib/firmware/cal_wlan*.bin` —
ссылки на них, драйвер `mtlk.ko` читает их через загрузчик прошивок. Сток дополнительно
хранит резервную копию в `data_vol:/rftest/eeprom_backup.tar.gz`; утилита `ax50-backup`
сохраняет и раздел, и `data_vol`.

## MAC-адреса

Сток (`/sbin/network_get_firm`) выводит все адреса из одного базового:

| Интерфейс | Адрес |
|---|---|
| LAN, br-lan | base |
| WAN | base + 1 |
| Wi-Fi 2.4 ГГц | base − 1 |
| Wi-Fi 5 ГГц | base − 2 |

Базовый — строка `MAC:XX-XX-XX-XX-XX-XX` раздела `default-mac`, которую читает
проприетарный `nvrammanager` (в GPL его нет). На платформе Intel эти данные TP-Link
лежат в UBI-томе `data_vol`; переменная `ethaddr` в окружении U-Boot — заглушка
`00:E0:92:00:01:40` из конфига SDK.

`/lib/functions/ax50.sh` (пакет `ax50-base-files`) ищет базовый адрес по порядку:
`data_vol` (только чтение) → `ethaddr` U-Boot, если это не заглушка → строка `MAC:` в
`res`/`calibration` → стабильный локально администрируемый адрес из хеша калибровки.
Результат кэшируется в `/etc/ax50/base-mac`, источник пишется в журнал (`logread | grep ax50`).

## Порты

Из `lib/network/network_arch.sh` стока:

| На корпусе | Интерфейс |
|---|---|
| LAN1 | `eth0_4` |
| LAN2 | `eth0_3` |
| LAN3 | `eth0_2` |
| LAN4 | `eth0_1` |
| WAN | `eth1` |

## Кнопки и светодиоды

| | GPIO | |
|---|---|---|
| Reset | gpio0 22 | active-low, `KEY_RESTART` |
| WPS/Wi-Fi | gpio0 8 | active-low: короче 2 с — WPS PBC, от 2 с — вкл/выкл Wi-Fi (как в стоке) |
| LED | gpio1 4 | active-low, `KEY_LIGHTS_TOGGLE`: вкл/выкл всех светодиодов (в стоковом DTB подписана «wifi») |

| Светодиод | GPIO (gpio0, active-high) | Поведение в прошивке |
|---|---|---|
| power | 21 | горит; мигает при загрузке/failsafe |
| wlan2g / wlan5g | 1 / 4 | активность `wlan0.0` / `wlan2.0` |
| lan | 9 | активность `br-lan` |
| wan (синий) / wan (оранжевый) | 7 / 6 | WAN поднят / нет связи |
| usb | 11 | подключено USB-устройство |

## Прочие отличия от референс-платы (DTS)

- SSO-контроллер светодиодов выключен: его pinctrl занимает пины 4/5/6, на которых у AX50
  обычные светодиоды; в стоковом DTB у SSO нет потребителей.
- VBUS USB — прямые GPIO `gpio0 14` и `gpio0 2` (у AxePoint — через SSO).
- Сброс PCIe: `gpio1 11`, `gpio1 29`; у третьего контроллера линия сброса убрана —
  у референса это `gpio0 7`, а на AX50 там светодиод WAN.
- Память ограничена 256 МБ.

## Wi-Fi-стек

Драйвер `iwlwav` (`mtlk.ko`, бэкпорт cfg80211/mac80211) и hostapd от MaxLinear 2.8
(собран с `CONFIG_SAE`, `CONFIG_OWE`, `CONFIG_IEEE80211W`, `CONFIG_IEEE80211AX`).
Конфигурация — обычный `/etc/config/wireless`, скрипты netifd из пакета `swpal`.
Схема драйвера: служебный «главный» VAP (`wlan0`, `wlan2`, скрытый) и точки доступа
`wlan0.0`, `wlan2.0`, … Подробнее о WPA3 — [packages.md](packages.md).
