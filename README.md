# ax50-openwrt

Свободная прошивка для **TP-Link Archer AX50 v1** на базе **prplWrt** — форка OpenWrt
от prpl Foundation с открытым BSP Intel/MaxLinear (таргет `intel_mips/xrx500`, тот же,
что у Netgear RAX40 на GRX350 + WAV654).

| | |
|---|---|
| Платформа | Intel/MaxLinear GRX350 (MIPS interAptiv, big-endian), 256 МБ ОЗУ, 128 МБ NAND |
| Wi-Fi | WAV654, 802.11ax 2×2 2.4 ГГц + 2×2 5 ГГц, драйвер `iwlwav` из исходников |
| Система | OpenWrt 19.07 (prplWrt) + ядро Intel 4.9.206, аппаратное ускорение PPA |
| Веб-интерфейс | LuCI 19.07 с темой [footstrap](https://github.com/VizzleTF/luci-theme-footstrap), русский язык |

## Что в прошивке

- **Все функции роутера**: 4×LAN + WAN 1 Гбит/с (порты как на корпусе), Wi-Fi 2.4/5 ГГц,
  USB 3.0 (накопители), светодиоды, кнопки Reset/WPS/Wi-Fi, аппаратный NAT.
- **Калибровка Wi-Fi и MAC-адреса** берутся из заводских разделов так же, как в стоке
  ([как это устроено](docs/hardware.md)).
- **PPPoE** (и IPv6, DHCP, статика) — в LuCI «Сеть → Интерфейсы → WAN».
- **WPA3** (SAE и смешанный WPA2/WPA3) — по умолчанию для обеих сетей.
- **AdGuard Home** — блокировка рекламы и трекеров для всей сети («Службы → AdGuard Home»).
- **zapret** — обход DPI, режим autohostlist («Службы → zapret»).
- **Тема footstrap**, тёмный режим, настройки внешнего вида («Система → Footstrap»).
- **Фид пакетов** — `opkg install` работает сразу: OpenVPN, WireGuard, Samba, DLNA,
  торренты, SQM, модемы и ещё сотни пакетов, собранных под эту прошивку.

## Установка

Прошивки TP-Link подписаны, поэтому через веб-интерфейс стока не ставится:
нужен UART-кабель (3.3 В) и TFTP — пошагово в **[docs/flashing.md](docs/flashing.md)**.
Начните с загрузки `initramfs-kernel.bin` в ОЗУ — это ничего не записывает во флеш.

Готовые образы — в [релизах](https://github.com/Aleck59/ax50-openwrt/releases).

> ⚠️ Прошивка экспериментальная. Перед установкой сделайте резервную копию заводских
> разделов (`calibration` уникален для каждого роутера).

## Первый вход

- Адрес **http://192.168.1.1**, пользователь `root`, пароль не задан — задайте сразу.
- Wi-Fi выключен до настройки: «Сеть → Беспроводная сеть», задайте пароль и включите.
- Резервная копия заводских данных: `ax50-backup` в консоли (SSH).

## Сборка

```bash
scripts/docker.sh        # prepare + configure + build в контейнере Ubuntu 20.04
```

Подробно — [docs/build.md](docs/build.md). Выпуск версии — тег `v*`, дальше всё делает CI
([docs/release.md](docs/release.md)).

## Документация

| | |
|---|---|
| [docs/hardware.md](docs/hardware.md) | железо, разметка NAND, калибровка, MAC, GPIO, порты |
| [docs/flashing.md](docs/flashing.md) | UART, TFTP, установка, обновление, возврат на сток |
| [docs/build.md](docs/build.md) | сборка, устройство репозитория, патчи |
| [docs/release.md](docs/release.md) | CI/CD, релизы, фид пакетов, подпись |
| [docs/packages.md](docs/packages.md) | AdGuard Home, zapret, WPA3, PPPoE, фид |
| [docs/theme.md](docs/theme.md) | порт темы footstrap на LuCI 19.07 |

## Лицензия

GPL-2.0-only (как OpenWrt и prplWrt). Тема footstrap — Apache-2.0, zapret — MIT,
AdGuard Home — GPL-3.0; бинарные прошивки радио — по лицензиям Intel/MaxLinear.
