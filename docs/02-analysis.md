# Разбор вариантов: почему prplWrt, а не «свежий OpenWrt»

Документ отвечает на вопрос «почему нельзя просто собрать OpenWrt 24.10/25.12».
Все утверждения — проверяемые.

## 1. Mainline OpenWrt: поддержки GRX350 нет вообще

Проверка по актуальному дереву `openwrt/openwrt` (master на момент работы —
после релиза 25.12):

```bash
git ls-tree --name-only HEAD target/linux/lantiq/
# ase base-files config-6.12 config-6.18 dts falcon files image
# modules.mk patches-6.12 patches-6.18 xrx200 xrx200_legacy xway xway_legacy

git log --all --oneline -- target/linux/intel_mips     # пусто
git grep -il 'grx350\|xrx500\|GRX500' HEAD             # пусто
```

Таргет `lantiq` в OpenWrt — это VR9/xRX200 и старше. **xRX500/GRX350 там не было никогда**,
ни в одной ветке, ни в одном коммите. Соответственно для AX50 в mainline отсутствует:

- драйвер коммутатора/датапата (GSWIP-3.1, CBM, TMU, MPE, PAE, PPA);
- драйвер NAND-контроллера этой ревизии, PCIe, USB-glue, clk/reset;
- загрузка firmware GPHY;
- Wi-Fi-драйвер для WAV654.

Это не «допилить», это **создать таргет с нуля** по вендорскому BSP для ядра 4.9 и
портировать его на 6.x. Объём — человеко-годы, и никто в мире этого не сделал.

Вывод: сборка «свежего OpenWrt» для AX50 даст в лучшем случае неработающий кирпич,
в худшем — не соберётся вовсе. Именно поэтому у вас «ядро загрузилось, но Wi-Fi не работал»:
любое ядро, собранное не из вендорского BSP, не содержит ни драйвера WAV654,
ни его прошивок, ни калибровки.

## 2. Сток TP-Link и его GPL: ядро 3.10.104 навсегда

Свежайшая официальная прошивка (1.1.2 Build 20251022, ноябрь 2025) содержит
`MIPS LTQCPE Linux-3.10.104` и userspace `OpenWrt Attitude Adjustment 12.09-rc1`.
TP-Link не переводил AX50 на новое ядро за 6 лет и не переведёт.

GPL-архивы TP-Link:

- `ax50v1_GPL_2.tar.gz` — SDK **UGW 7.1.1**, база OpenWrt `15.05_ltq`, ядро 3.10.104
- `ax50v1_GPL_3.tar.gz` (ноябрь 2022) — SDK **UGW-7.5.1.50**, то же ядро 3.10.104,
  плюс слой TP-Link `Iplatform/` с конфигом продукта `ax50v1`
  (`sdk.config`, `kernel.config`, профиль `grx350_1600_mr_axepoint_6x_wav600_eth_rt_74`)

Что важно про GPL_3:

- в `dl/` лежит **исходник Wi-Fi-драйвера**
  `lq-wave-300-06.00.08.00.87.00.07.d24084bd3447.gpl.wls.src.tar.bz2` (1109 файлов) —
  и его версия точно совпадает с версией в бинарном `mtlk.ko` из прошивки;
- но **фид `ugw/feeds_ugw/wlan` вырезан** — в архиве остались только
  `feeds/ugw_packages.tmp/info/.packageinfo-*` (метаданные) и `feeds_ugw/system`.
  То есть рецепта сборки (`Makefile` пакета `lq-wave-300_6x`) в GPL нет,
  как нет и `feeds_thirdparty`.

Итог: собрать из GPL TP-Link можно (это и делает
[`alexandr-mironov/ax50`](https://github.com/alexandr-mironov/ax50) на базе GPL_2),
но вы получите ядро 3.10 и userspace 2013 года, плюс придётся восстанавливать
вырезанные фиды. «Свежее» это не даёт по определению.

## 3. prplWrt / prplOS — то, что реально работает

prpl Foundation совместно с MaxLinear публикуют открытый BSP для AnyWAN.
Манифест открытого набора (ветка `ugw-8.5.2`,
[`prpl-foundation/intel/manifest`](https://gitlab.com/prpl-foundation/intel/manifest)) включает:

| Репозиторий | Что даёт |
|---|---|
| `linux` | ядро Intel/MaxLinear (ветки `intel-4.9.206/218/276`, `ugw-8.5.2`) |
| `feed_target_mips` | таргет OpenWrt `intel_mips`, субтаргет `xrx500`, DTS, image recipes |
| `iwlwav-dev` | **открытый Wi-Fi-драйвер WAV600/WAV654** |
| `iwlwav-hostap`, `iwlwav-iw`, `iwlwav-tools`, `dwpal`, `swpal` | userspace Wi-Fi |
| `wave_bin` | прошивки радиомодулей |
| `feed_ppa`, `feed_datapath`, `directconnect_dp`, `ppa_drv` | аппаратное ускорение сети |
| `feed_switch_api`, `switch_cli` | управление коммутатором |
| `feed_gphy_firmware` | прошивка GPHY |

Главное: в `feed_target_mips` **уже есть готовые устройства на этом же железе** —
`NETGEAR_RAX40` (`dts/netgear_rax40.dts`, `image/rax40.mk`) и семейство AxePoint
`AX3000_1600_ETH_11AX*` с `DEVICE_DTS := easy350_anywan_axepoint_rt` —
то есть **GRX350 1600 + WAV600 + Ethernet-роутер**, ровно класс AX50.

Официальная инструкция сборки (wiki prplOS,
[Build prplWrt manually for the Netgear RAX40](https://gitlab.com/prpl-foundation/prplos/prplos/-/wikis/Build-prplWrt-manually-for-the-Netgear-RAX40)):

```bash
git clone https://git.prpl.dev/prplwrt/prplwrt.git
cd prplwrt
./scripts/feeds setup "src-git,packages,...;openwrt-19.07" \
  "src-git,intel_feed,...feed-intel.git;intel-19.07" \
  "src-git,iwlwav,...iwlwav.git;iwlwav-19.07" ...
./scripts/feeds install intel_mips
./scripts/gen_config.sh rax40
make -j24
```

База prplWrt — OpenWrt **19.07-SNAPSHOT**, но, в отличие от апстрима 19.07,
она сохраняет поддержку ядра 4.9 (`target/linux/generic/{config,patches,backport,hack,pending}-4.9`),
что и требуется таргету `intel_mips` (`KERNEL_PATCHVER := 4.9`, `LINUX_VERSION := 4.9.218`).

### Про доступность репозиториев

`git.prpl.dev` и `intel.prpl.dev` — инфраструктура prpl, из части сетей недоступна
(в нашем окружении — `CONNECT tunnel failed 502`). Поэтому в этом репозитории
все URL заменены на **зеркала на gitlab.com**, которые доступны публично:

| В инструкции prpl | Используем |
|---|---|
| `intel.prpl.dev/intel/<repo>.git` | `gitlab.com/prpl-foundation/intel/<repo>.git` |
| `git.prpl.dev/prplwrt/prplwrt.git` | `gitlab.com/aparcar/prplwrt.git` (зеркало) |
| `git.prpl.dev/prplwrt/feed-prpl.git` | `gitlab.com/prpl-foundation/prplwrt/feed-prpl.git` |

Такая же замена есть в самом апстриме — ветка `hotfix/update_urls_to_gitlab`
зеркала prplwrt, где `profiles/intel_mips.yml` уже переписан на `gitlab.com`.
Наш профиль [`device/profiles/ax50.yml`](../device/profiles/ax50.yml) построен на нём.

## 4. Что было бы «ещё свежее» и почему это исследовательская задача

Ядро новее 4.9 для GRX350 публично не выпускалось: в `prpl-foundation/intel/linux`
есть только 4.9.x. Чтобы получить 5.4/6.x, нужно портировать:

1. `iwlwav` — драйвер на cfg80211; API cfg80211/mac80211 c 4.9 до 6.x изменился
   радикально (ключи, `struct wiphy`, offchannel, HE/EHT). Работа большая, но
   принципиально выполнимая, потому что **исходники открыты**.
2. Датапат (PPA/MPE/TMU/CBM/PAE) — вендорский код, сильно завязанный на 4.9;
   без него будет работать только программный форвардинг (потеря NAT-производительности).
3. GSWIP-3.1: в mainline есть `gswip` только для xRX200. Нужен новый драйвер.

Это единственный путь к «свежему ядру», и он открыт для развития в этом репозитории —
но начинать надо с рабочей 4.9-сборки, чтобы было с чем сравнивать.

## Итог

| Критерий | Сток | GPL TP-Link | **prplWrt (наш путь)** | OpenWrt 24.10+ |
|---|---|---|---|---|
| Ядро | 3.10.104 | 3.10.104 | **4.9.218** | 6.x |
| Userspace | OpenWrt 12.09 | 15.05_ltq | **19.07** | 24.10+ |
| Wi-Fi 6 | ✅ бинарь | ✅ бинарь | ✅ **из исходников** | ❌ |
| HW-ускорение сети | ✅ | ✅ | ✅ | ❌ |
| opkg/LuCI/uci | огрызок | частично | **да** | да |
| Реализуемо | — | да | **да** | нет |
