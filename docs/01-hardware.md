# Железо TP-Link Archer AX50 v1

Всё в этом документе получено **прямым разбором официальной прошивки**
`Archer AX50_V1_251022` (версия 1.1.2 Build 20251022, релиз 21.11.2025), а не из
рекламных описаний. Скрипт, который это повторяет: [`scripts/extract-stock-firmware.sh`](../scripts/extract-stock-firmware.sh).

## SoC и платформа

| Параметр | Значение | Источник |
|---|---|---|
| SoC | Intel/Lantiq **GRX350** (AnyWAN), ныне MaxLinear | `compatible = "lantiq,grx500", "lantiq,xrx500"` в DTB |
| Ядро CPU | MIPS **interAptiv**, многоядерный (4 VPE) | `compatible = "mips,InterAptiv"` |
| Референс-плата | **EASY350 ANYWAN (GRX350) Router model** | `model` в DTB |
| Профиль вендора | `grx350_1600_mr_axepoint_6x_wav600_eth_rt` | строки сборки в `mtlk.ko` |
| Wi-Fi | Intel/MaxLinear **WAV654** (WAV600 gen6), 2×2 2.4 ГГц + 2×2 5 ГГц, 802.11ax | `wave600_progmodel`, `ProgModel_gen6_*` |
| Ethernet | GSWIP-3.1, 5 внутренних GPHY (`no_of_phys = <5>`), 11G-FW | `phy-xrx500` / `gphy-fw` в DTB |
| USB | 2 контроллера (`usb@300000`, `usb@500000`), xHCI | DTB + `xhci-hcd.ko` |
| PCIe | 3 контроллера `lantiq,pcie-xrx500` (радиомодули на PCIe) | DTB |
| Криптоускоритель | EIP97 | пакеты BSP |

RAM: узел `memory@0` в DTB объявляет `reg = <0x20000000 0x1e000000>` — 480 МиБ в верхней
области. Итоговый объём ОЗУ, который видит Linux, нужно подтвердить на устройстве
(`cat /proc/meminfo` или строка `Memory:` в UART-логе) — в DT на GRX500 нижняя область
описывается отдельно и в этот узел не входит.

## NAND flash — 256 МиБ

Точная разметка из DTB стоковой прошивки:

| Раздел | Смещение | Размер | Назначение |
|---|---|---|---|
| `uboot` | `0x0000000` | 1 МиБ | загрузчик — **не трогать** |
| `ubootconfigA` | `0x0100000` | 256 КиБ | окружение U-Boot, банк A |
| `ubootconfigB` | `0x0140000` | 256 КиБ | окружение U-Boot, банк B |
| `gphyfirmware` | `0x0180000` | 256 КиБ | прошивка встроенных GPHY |
| `calibration` | `0x01C0000` | 1 МиБ | **калибровка Wi-Fi + MAC-адреса — не трогать** |
| `system_sw` | `0x02C0000` | 250 МиБ | UBI: kernelA/rootfsA (+ банк B) |
| `res` | `0xFCC0000` | 3.25 МиБ | резерв |

Итого `0xFCC0000 + 0x340000 = 0x10000000` = **256 МиБ**.

Отличие от референс-платы AxePoint: там NAND 128 МиБ и есть отдельный раздел `Bootcore`
(16 МиБ) на `0x2c0000`. У AX50 раздела `Bootcore` **нет** — это учтено в нашем DTS и
влияет на сборку образа (см. [`docs/06-roadmap.md`](06-roadmap.md), открытый вопрос №1).

## Кнопки (gpio-keys-polled)

| Кнопка | GPIO | Полярность | linux,code |
|---|---|---|---|
| Wi-Fi on/off | `gpio1` 4 | active-low | `0xee` = 238 (`KEY_RFKILL`) |
| WPS | `gpio0` 8 | active-low | `0x211` = 529 (`KEY_WPS_BUTTON`) |
| Reset | `gpio0` 22 | active-low | `0x198` = 408 (`KEY_RESTART`) |

`gpio0` = `gpio@c00000`, `gpio1` = `gpio@c00100` (по `xrx500.dtsi`).

## Светодиоды (gpio-leds, все на gpio0, active-high)

| LED | GPIO |
|---|---|
| `blue:wlan_2g` | 1 |
| `blue:wlan_5g` | 4 |
| `orange:internet` | 6 |
| `blue:internet` | 7 |
| `blue:lan` | 9 |
| `blue:usb_2` | 11 |
| `blue:power` | 21 (default-state on) |

## Стоковая прошивка

- Формат файла: uImage `multi`, имя `TP-Link Totalimage`, внутри четыре образа:
  `U-Boot Img` (LZMA) → `gphyfw` → `LTQCPE RootFS` (squashfs4 + XZ, 27.2 МБ) →
  `MIPS LTQCPE Linux-3.10.104` (LZMA, load `0xa0020000`, entry `0xa002df00`).
- Заголовок содержит `support-list` с region-id: `55530000` (US), `45550000` (EU),
  `4A500000` (JP), `43410000` (CA), `41550000` (AU).
- Ядро: `Linux version 3.10.104 ... gcc 4.8.3 (OpenWrt/Linaro GCC 4.8-2014.04 15.05_ltq) #2 SMP`.
- `/etc/openwrt_release`: `OpenWrt Attitude Adjustment 12.09-rc1`, `DISTRIB_TARGET="model_intel_grx350/generic"`.

## Wi-Fi-стек стоковой прошивки

Весь Wi-Fi живёт в `/opt/lantiq` — это самодостаточный вендорский слой:

- `/opt/lantiq/lib/modules/3.10.104/net/mtlk.ko` (1.8 МБ) + `mtlkroot.ko`, `license=GPL`
- `/opt/lantiq/bin/hostapd`, `wpa_supplicant`, `mtlk_cli`, `drvhlpr`, `logserver`
- `/lib/firmware/`: `ap_ram_gen6_wrx_600_real_phy.bin` (1.5 МБ), `ProgModel_gen6*.bin`,
  `host_interface_gen6*.bin`, `rx_handler_gen6*.bin`, `tx_sender_gen6*`, `PSD.bin`
- `/lib/wifi/default_cal_wlan0*.bin` — калибровка по умолчанию (реальная — в MTD `calibration`)

Версии из `/etc/wave_components.ver`:

```
wave_release_minor = 06.00.08.212.1.14_AE_ugw-7.5.0
wave_driver_ver    = 06.00.08.00.87.00.07.d24084bd3447
wave_mac_ver       = FW_MR3-fw-212.1.x_20200108_102633
wave600_progmodel  = 1911181159
```

Строки внутри `mtlk.ko` раскрывают, чем и из чего он собран:

```
KERNELDIR=.../UGW-7.5.1.50/build_dir/target-mips_mips32_uClibc-0.9.33.2_
          grx350_1600_mr_axepoint_6x_wav600_eth_rt_74/linux-lantiq_xrx500/linux-3.10.104
CFLAGS=-Os -pipe -mips32r2 -mno-branch-likely -mtune=1004kc
...wireless/driver/linux/cfg80211.c
```

То есть: SDK **UGW-7.5.1.50**, uClibc 0.9.33.2, и драйвер использует **cfg80211** —
это тот же кодовый предок, что и открытый `iwlwav` из prpl/MaxLinear.

## Ключевые модули ядра стока

`ltq_eth_drv_xrx500`, `ltq_mpe_hal_drv`, `ltq_tmu_hal_drv`, `ltq_pae_hal`,
`ppa_api*`, `directconnect_datapath`, `dc_mode0-xrx500`, `mcast_helper`, `xhci-hcd`.
Все они имеют открытые аналоги в BSP prpl (`feed_ppa`, `feed_datapath`, `feed_target_mips`).

## Загрузчик

U-Boot линейки Intel/Lantiq (в образе — раздел `u-boot image`, load `0xa0400000`).
На родственных платах GRX350 (Netgear RAX40) в нём есть команды
`ubi_init`, `update_fullimage`, `switchbankA/B`, `upgrade` — они же ожидаются здесь.
Это основа процедуры восстановления, см. [`docs/04-flashing.md`](04-flashing.md).
