# Справочные артефакты, извлечённые из стоковой прошивки

## `ax50-stock.dts`

Device tree, извлечённый из ядра официальной прошивки
**Archer AX50 v1, версия 1.1.2 Build 20251022** (файл
`ax50v1_intel-up-ver1-1-2-P1[20251022-rel69668]_sign.bin`, релиз 21.11.2025).

Как получен:

```bash
./scripts/extract-stock-firmware.sh ax50v1_intel-up-...-_sign.bin out/
# out/board.dts
```

Цепочка: TP-Link Totalimage → uImage `MIPS LTQCPE Linux-3.10.104` → распаковка LZMA →
поиск сигнатуры FDT `d00dfeed` в vmlinux (смещение 1040) → `dtc -I dtb -O dts`.

Это первоисточник для всех значений в [`../docs/01-hardware.md`](../docs/01-hardware.md):
разметка NAND, GPIO кнопок и светодиодов, PCIe, GPHY.

Файл является частью исходного кода ядра Linux (GPLv2), опубликованного
TP-Link в составе прошивки, и приводится здесь как справочный материал.

## Что ещё полезно вытащить самому

Скрипт распаковывает и rootfs (нужен `squashfs-tools`). Оттуда стоит посмотреть:

| Путь в rootfs | Что это |
|---|---|
| `etc/wave_components.ver` | версии Wi-Fi-стека (драйвер, firmware, progmodel) |
| `opt/lantiq/lib/modules/3.10.104/net/mtlk.ko` | бинарный вендорский Wi-Fi-драйвер |
| `lib/firmware/*gen6*` | прошивки радио WAV600 |
| `lib/wifi/default_cal_wlan0*.bin` | калибровка по умолчанию |
| `lib/modules/3.10.104/` | датапат: `ltq_mpe_hal_drv`, `ltq_tmu_hal_drv`, `ppa_api`, `ltq_eth_drv_xrx500` |

В репозиторий бинарники вендора не кладутся: они проприетарные и большие,
а для нашей сборки не нужны — Wi-Fi собирается из открытого `iwlwav`.
