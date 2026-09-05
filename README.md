# ax50-openwrt — свободная прошивка для TP-Link Archer AX50 v1

Сборка прошивки на базе **prplWrt** (OpenWrt-форк prpl Foundation) для роутера
TP-Link Archer AX50 v1 — платформа **Intel/MaxLinear AnyWAN GRX350 + WAV654 (Wi-Fi 6)**.

Цель: рабочие **все** функции — Wi-Fi 6 (2.4 + 5 ГГц), 5×GbE с аппаратным ускорением
(PPA/MPE), USB 3.0, — при максимально свежем ядре и userspace, которые **реально
существуют** для этого железа.

---

## Главный вывод исследования (читать до начала работы)

Три факта, которые определяют всё остальное:

1. **В mainline OpenWrt поддержки этого SoC нет и не было.**
   Проверено по дереву `openwrt/openwrt` (master, 25.12): таргет `lantiq` содержит только
   `xway`/`xrx200`/`ase`/`falcon` (VR9 и старше). Ни `intel_mips`, ни `xrx500`, ни `grx350`
   в истории репозитория не встречаются вообще. Значит, «собрать свежий OpenWrt 24.10/25.12»
   для AX50 нельзя не потому, что «Wi-Fi не заведётся», а потому, что **нет драйверов
   вообще ничего**: ни Ethernet (GSWIP-3.1 + CBM/TMU/MPE datapath), ни NAND, ни PCIe.

2. **Стоковая прошивка TP-Link — это ядро 3.10.104.**
   Проверено распаковкой свежайшей официальной прошивки `1.1.2 Build 20251022` (релиз
   21.11.2025): внутри `MIPS LTQCPE Linux-3.10.104`, userspace помечен как
   `OpenWrt Attitude Adjustment 12.09-rc1`, target `model_intel_grx350`. То есть даже
   «свежая» заводская прошивка 2025 года — это ядро 2013 года.

3. **Есть третий путь, и он рабочий: prplWrt.**
   prpl Foundation вместе с MaxLinear публикуют открытый BSP для этой платформы:
   таргет `intel_mips/xrx500` (ядро **4.9.218**), **открытый** Wi-Fi-драйвер `iwlwav`
   для WAV600/WAV654, аппаратный datapath (PPA/MPE/DirectConnect), GPHY firmware.
   В этом BSP **уже есть готовое устройство-близнец — Netgear RAX40** (тот же GRX350 +
   WAV600), с полным рецептом сборки образа.

**Отсюда стратегия репозитория:** берём prplWrt + открытые фиды Intel/MaxLinear и
добавляем в них Archer AX50 v1 как новое устройство (DTS + image recipe + board.d).
Это даёт ядро 4.9.218 вместо 3.10.104, userspace OpenWrt 19.07 вместо 12.09,
нормальный `opkg`, LuCI, uci — и при этом **рабочий Wi-Fi 6**, потому что драйвер
`iwlwav` собирается из исходников под это ядро.

Подробный разбор всех вариантов и почему остальные отпадают — [`docs/02-analysis.md`](docs/02-analysis.md).

---

## Насколько «свежо» — честно

| Вариант | Ядро | Userspace | Wi-Fi | Ethernet | Реализуемость |
|---|---|---|---|---|---|
| Сток TP-Link | 3.10.104 | OpenWrt 12.09 | ✅ | ✅ | — |
| GPL-сборка TP-Link (UGW 7.5.1) | 3.10.104 | OpenWrt 15.05_ltq | ✅ | ✅ | средняя |
| **prplWrt + intel_mips (этот репозиторий)** | **4.9.218** | **OpenWrt 19.07** | ✅ `iwlwav` | ✅ | **основная цель** |
| OpenWrt 21.02/22.03 + порт BSP | 5.4/5.10 | свежий | ⚠️ порт драйвера | ⚠️ порт datapath | исследовательская |
| OpenWrt 24.10 / 25.12 | 6.6/6.12 | свежайший | ❌ | ❌ | нереализуемо в одиночку |

Ядра новее 4.9 для GRX350 публично не существует: в репозитории ядра MaxLinear
(`prpl-foundation/intel/linux`) ветки — `intel-4.9.206`, `intel-4.9.218`, `intel-4.9.276`,
`ugw-8.5.2`; ничего 5.x/6.x. Это потолок, и он не наш.

---

## Что уже сделано в этом репозитории

- [x] Полный технический разбор железа по стоковой прошивке — извлечён DTB, разделы
      NAND, GPIO кнопок и светодиодов, версии Wi-Fi-стека ([`docs/01-hardware.md`](docs/01-hardware.md),
      [`reference/`](reference/))
- [x] Доказательная база по всем вариантам сборки ([`docs/02-analysis.md`](docs/02-analysis.md))
- [x] Профиль сборки prplWrt с зеркалами на gitlab.com ([`device/profiles/ax50.yml`](device/profiles/ax50.yml))
- [x] DTS для Archer AX50 v1 ([`device/dts/tplink_ax50.dts`](device/dts/tplink_ax50.dts))
- [x] Image recipe ([`device/image/ax50.mk`](device/image/ax50.mk))
- [x] Скрипты подготовки дерева и сборки ([`scripts/`](scripts/)) — **подготовка дерева
      проверена на практике**: фиды ставятся, таргет `intel_mips` устанавливается,
      устройство `TPLINK_AX50` попадает в конфигурацию, все 70 пакетов профиля разрешаются
- [x] Окружение сборки в контейнере Ubuntu 20.04 ([`docker/`](docker/)) — на современных
      дистрибутивах OpenWrt 19.07 не собирается: нужен Python 2.x и GCC не новее 9.x
- [x] Инструкции по прошивке и восстановлению через U-Boot/TFTP ([`docs/04-flashing.md`](docs/04-flashing.md))
- [x] **Сборка доведена до готовых образов и проверена**: `initramfs-kernel.bin`
      (9.2 МБ, для безопасной загрузки в ОЗУ), `squashfs-fullimage.img` и
      `squashfs-sysupgrade.bin` (по 11.2 МБ). Внутри — ядро 4.9.206, 137 пакетов,
      Wi-Fi-драйвер `mtlk.ko` собран из исходников `iwlwav`, прошивки радио WAV600,
      наша разметка NAND и настройка портов. Разбор образа и состав —
      [`reference/build/`](reference/build/)
- [ ] Проверка на железе — **требуется устройство и UART**

> ⚠️ Прошивка **не проверена на устройстве**. До первой заливки в NAND обязательно
> сделайте бэкап и опробуйте загрузку по TFTP в RAM. См. [`docs/04-flashing.md`](docs/04-flashing.md).

---

## Быстрый старт

```bash
git clone https://github.com/Aleck59/ax50-openwrt.git
cd ax50-openwrt

./scripts/docker-build.sh   # подготовка дерева + сборка в Ubuntu 20.04 (первый раз 2-4 часа)
```

Через контейнер — потому что база prplWrt это OpenWrt 19.07: ей нужен Python 2.x
и GCC не новее 9.x, чего на современных дистрибутивах уже нет. Если у вас
подходящий хост (например, Ubuntu 20.04), можно и напрямую:

```bash
./scripts/00-deps.sh
./scripts/10-setup-tree.sh
./scripts/20-build.sh
```

Результат: `build/prplwrt/bin/targets/intel_mips/xrx500/`.

Полностью — [`docs/03-build.md`](docs/03-build.md).

---

## Структура

```
docker/         окружение сборки (Ubuntu 20.04)
docs/           технические документы (RU)
scripts/        подготовка окружения, сборка, работа с устройством
device/         всё, что добавляет поддержку AX50 в prplWrt
  profiles/     профиль сборки (фиды + список пакетов + diffconfig)
  dts/          device tree Archer AX50 v1
  image/        рецепт образа
  files/        board.d, uci-defaults
reference/      факты, извлечённые из стоковой прошивки (DTB, отчёт)
.github/        CI-сборка
```

## Ссылки

- [Инструкция prpl: сборка prplWrt для Netgear RAX40](https://gitlab.com/prpl-foundation/prplos/prplos/-/wikis/Build-prplWrt-manually-for-the-Netgear-RAX40)
- [Таргет `intel_mips` (feed_target_mips)](https://gitlab.com/prpl-foundation/intel/feed_target_mips)
- [Драйвер Wi-Fi `iwlwav`](https://gitlab.com/prpl-foundation/intel/iwlwav-dev)
- [Манифест открытого BSP UGW-8.5.2](https://gitlab.com/prpl-foundation/intel/manifest)
- [GPL-исходники TP-Link Archer AX50 v1](https://www.tp-link.com/us/support/download/archer-ax50/v1/)
- [Обсуждение AX50 на форуме OpenWrt](https://forum.openwrt.org/t/openwrt-support-for-tp-link-archer-ax50-v1/105076)
