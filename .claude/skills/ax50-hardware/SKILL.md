---
name: ax50-hardware
description: Справочник по железу TP-Link Archer AX50 v1 (GRX350 + WAV654) — разметка NAND, калибровка Wi-Fi, MAC-адреса, GPIO, порты, U-Boot и восстановление. Использовать при правке DTS, board.d, сетевых и Wi-Fi настроек, инструкций по прошивке.
---

# TP-Link Archer AX50 v1 — факты

Источники: GPL `ax50v1_GPL_3.tar.gz` (UGW-7.5.1.50, `Iplatform/build/product_configs/ax50v1/sdk.config`)
и прошивка 1.1.2 Build 20251022 (DTB, rootfs, U-Boot). Подробно — `docs/hardware.md`.

- SoC Intel GRX350 (xRX500), MIPS interAptiv **big-endian**, пакеты `mips_24kc_nomips16`.
- 2 ядра × 2 VPE: CPU0–2 у Linux, CPU3 — прошивка MPE ("MPEFW", как в стоке). Отдать CPU3 Linux нельзя без своего таймера: в `xrx500.dtsi` clockevent GPTC есть только у CPU0–2, иначе RCU stall и зависание загрузки. Трафик по ядрам Linux: RPS (`hotplug.d/net/25-ax50-rps`). irqbalance ломает сеть: прерывания очередей CBM привязаны к ядрам.
- ОЗУ 256 МБ (`mem=256M@512M`), NAND **128 МБ**, страница 2 КБ, блок 128 КБ.
- `mtdparts=17c00000.nand-parts:1m(uboot),256k(ubootconfigA),256k(ubootconfigB),256k(gphyfirmware),1m(calibration),124m(system_sw),-(res)` — U-Boot передаёт это ядру.
- `system_sw` — UBI: `kernelA/rootfsA` (+B), `data_vol` (данные TP-Link), `rootfs_data` (оверлей OpenWrt).
- **calibration** — поток tar.gz → `wlanconfig.gz` (tar.gz) → `cal_wlan0.bin` (2.4 ГГц),
  `cal_wlan2.bin` (5 ГГц). Читает preinit `91_wireless_calib` (iwlwav) через
  `vol_mgmt read_calibration`. Уникальна для экземпляра — **никогда не писать**.
- MAC: база из `default-mac` TP-Link (строка `MAC:XX-XX-...`); LAN = base, WAN = +1,
  Wi-Fi 2.4 = −1, 5 = −2. Поиск: `data_vol` → `ethaddr` U-Boot (кроме заглушки
  00:E0:92:00:01:40) → `res`/`calibration` → производный LAA (`/lib/functions/ax50.sh`).
- Порты: LAN1→`eth0_4`, LAN2→`eth0_3`, LAN3→`eth0_2`, LAN4→`eth0_1`, WAN→`eth1`.
- Кнопки (active-low): reset gpio0 22; WPS/Wi-Fi gpio0 8 (короче 2 с — WPS, дольше — вкл/выкл Wi-Fi); LED gpio1 4 (KEY_LIGHTS_TOGGLE, в стоковом DTB подписана «wifi», но управляет светодиодами).
- LED (gpio0, active-high): wlan2g 1, wlan5g 4, orange:wan 6, blue:wan 7, lan 9, usb 11, power 21.
- USB VBUS gpio0 14 / gpio0 2; SSO-контроллер не используется (его pinctrl занимает пины 4/5/6).
- PCIe сброс: gpio1 11 / gpio1 29; у pcie2 сброс убран (gpio0 7 — светодиод).
- Wi-Fi: WAV654, драйвер iwlwav (mtlk.ko), hostapd MaxLinear 2.8 (SAE/OWE/11w), служебный
  VAP `wlan0`/`wlan2` + точки `wlan0.0`/`wlan2.0`; нужна подписанная `regulatory.db` + `.p7s`.
- U-Boot: `run update_fullimage` (tftp `fullimage.img` в оба банка), консоль 115200 8N1.
