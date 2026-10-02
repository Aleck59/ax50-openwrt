# Возможности прошивки

## Подключение к провайдеру (PPPoE)

LuCI → «Сеть → Интерфейсы → WAN → Изменить» → протокол **PPPoE** → логин и пароль
провайдера. В образе: `ppp`, `ppp-mod-pppoe`, `kmod-pppoe`, `luci-proto-ppp`, а также
IPv6 (`luci-proto-ipv6`, odhcp6c). Аппаратное ускорение NAT (PPA) работает и для PPPoE.

## Wi-Fi и WPA3

Wi-Fi выключен до первой настройки (как принято в OpenWrt): «Сеть → Беспроводная сеть» →
у точек `AX50-XXXX` и `AX50-XXXX-5G` задайте пароль и нажмите «Включить».

Шифрование по умолчанию — **WPA2-PSK/WPA3-SAE (смешанный)**, доступен и чистый
**WPA3-SAE**, OWE, 802.11w. Как это устроено:

- hostapd MaxLinear собран с `CONFIG_SAE`, `CONFIG_OWE`, `CONFIG_IEEE80211W`;
- скрипты netifd из `swpal` переводят `encryption sae` / `sae-mixed` в
  `wpa_key_mgmt=SAE` / `WPA-PSK SAE` и включают PMF;
- LuCI узнаёт возможности hostapd вызовом `hostapd -vsae` — эту функцию в hostapd
  MaxLinear добавляет патч `patches/feed_wlan_6x/0001-...` (иначе LuCI скрывает WPA3);
- база регуляторики — актуальная официальная `regulatory.db` + `regulatory.db.p7s`
  (пакет `wireless-regdb`). cfg80211 драйвера требует подпись и знал только старые
  ключи (sforshee, iwlwav), поэтому патч `patches/feed_wlan_6x/0003-...` добавляет
  ключ нынешнего сопровождающего (wens), а устаревшую базу из пакета WAVE убирает.
  Страна по умолчанию — RU.

## AdGuard Home

«Службы → AdGuard Home». Официальная сборка `AdGuardHome_linux_mips_softfloat`
(версия — в `package/adguardhome/Makefile`, контрольная сумма из релиза AdGuard).

1. Откройте веб-интерфейс AdGuard Home: http://192.168.1.1:3000 и пройдите мастер.
   Для DNS укажите порт **5353** (на 53 работает dnsmasq), веб-интерфейс — 3000.
2. В LuCI включите «Фильтровать DNS всей сети»: dnsmasq начнёт пересылать все запросы в
   AdGuard Home (`server=127.0.0.1#5353`, `noresolv`), а локальные имена DHCP-клиентов
   продолжат работать. При остановке AdGuard Home пересылка снимается автоматически.

Данные: `/etc/adguardhome.yaml`, `/etc/adguardhome/` — сохраняются при sysupgrade.
Обновление — пакетом из фида (самообновление отключено: бинарник лежит в squashfs).

## zapret (обход DPI)

«Службы → zapret». [bol-van/zapret](https://github.com/bol-van/zapret) собран из
исходников и установлен так же, как это делает установщик автора (`/opt/zapret`,
служба `/etc/init.d/zapret`, правила через include fw3).

- Режим по умолчанию — **autohostlist**: обрабатываются домены из списка «Домены»
  (YouTube, Discord — как пример) и домены, которые nfqws сам распознал как
  заблокированные. Остальной трафик не трогается.
- Стратегия (`NFQWS_OPT`) — стандартная из `config.default`. Под своего провайдера её
  лучше подобрать: `/opt/zapret/blockcheck.sh` в консоли, результат — во вкладку
  «Конфигурация».
- Если что-то стало работать хуже — очистите «Найдены автоматически».

OpenWrt 19.07 работает на iptables (fw3), поэтому используется режим iptables: NFQUEUE,
connbytes, ipset — модули ядра входят в образ.

## Мониторинг

- **Статус → Трафик** (`luci-app-traffic`) — трафик WAN за сегодня, вчера, месяц,
  график за 30 дней, по часам и текущая скорость. Данные — `vnstat` (учёт `eth1`, при
  PPPoE — `pppoe-wan`), база в `/etc/vnstat` сохраняется раз в 30 минут и переживает
  перезагрузку. Порт [luci-app-traffic](https://github.com/HanHan666666/luci-app-traffic)
  на LuCI 19.07.
- **Статус → Netdata** (`luci-app-netdata`) — панель Netdata 1.30 (порт 19999) во
  фрейме, кнопки запуска и остановки. Netdata занимает около 30 МБ ОЗУ.

HomeProxy (sing-box) в прошивку не входит: ему нужны OpenWrt 23.05+, firewall4/nftables,
ucode и ядро не старше 4.18 с `nft_tproxy` — в prplWrt 19.07 с ядром 4.9 этого нет.

## Сеть и удалённый доступ

- **SQM** (`luci-app-sqm`, «Сеть → SQM QoS») — борьба с ростом задержек под нагрузкой
  (cake). Ограничиваемый трафик идёт через процессор, мимо аппаратного ускорения PPA,
  поэтому скорость выше ~300–400 Мбит/с с SQM не получить.
- **WireGuard** (`luci-proto-wireguard`, `luci-app-wireguard`) — VPN: интерфейс
  создаётся в «Сеть → Интерфейсы» (протокол WireGuard VPN).
- **DDNS** (`luci-app-ddns`, «Службы → Динамический DNS») — доступ по имени при
  меняющемся внешнем IP.
- **ZeroTier** (`zerotier`) — доступ к домашней сети без белого IP. Страницы LuCI
  для него в 19.07 нет, настройка в `/etc/config/zerotier`:
  ```sh
  uci set zerotier.sample_config.enabled=1
  uci add_list zerotier.sample_config.join=<ID сети>
  uci commit zerotier && /etc/init.d/zerotier restart
  ```

## Фид пакетов

`opkg update && opkg install <пакет>` работает сразу — адрес фида встроен в прошивку
(см. [release.md](release.md)). Что собирается — `config/feed-packages.txt`: все
приложения LuCI с русским переводом, VPN (OpenVPN, WireGuard, strongSwan, ZeroTier),
Samba/ksmbd, DLNA, Transmission, aria2, SQM, mwan3, DDNS, модемы 3G/4G, диагностика,
утилиты командной строки, а также модули ядра (USB-модемы, файловые системы, туннели).

Пакеты из официальных репозиториев OpenWrt (21.02+) **не подходят**: другая версия
libc и ядра. Ставьте только из встроенного фида.

## Прочее

- `ax50-backup` — архив заводских разделов и `data_vol` в `/tmp`.
- Подкачка в сжатой памяти (`zram-swap`), USB-накопители (ext4, FAT, NTFS через фид).
- Кнопка WPS/Wi-Fi: короткое нажатие — WPS на всех точках доступа, удержание от 2 с —
  включить/выключить Wi-Fi. Кнопка LED выключает и включает все светодиоды (выбор
  сохраняется после перезагрузки).
- «Статус → Обзор» показывает температуру процессора и радиомодулей Wi-Fi и нагрузку
  каждого из 4 потоков процессора (доля прерываний — во всплывающей подсказке).
- Обработка трафика на всех 4 потоках: RPS для `eth*`/`wlan*` и irqbalance.
- Светодиод «Интернет»: нет кабеля в WAN — не горит, кабель есть, но нет подключения —
  оранжевый, есть подключение (маршрут по умолчанию через PPPoE, L2TP, DHCP или static) —
  синий; при передаче данных светодиод мигает (триггер netdev).
- Аппаратное ускорение маршрутизации LAN↔WAN (PPA) пока **выключено**: сессии не
  попадают в аппаратный PAE, и с PPA маршрутизация медленнее (~230 против ~330 Мбит/с).
  Для экспериментов: `/etc/init.d/ax50-ppa enable && /etc/init.d/ax50-ppa start`;
  состояние — `ppacmd summary`, `ppacmd getwansessions`.
