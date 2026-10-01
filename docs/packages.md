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
- база регуляторики — официальная подписанная `regulatory.db` + `regulatory.db.p7s`
  (cfg80211 драйвера требует подпись), страна по умолчанию — RU.

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
- Кнопка WPS запускает WPS на всех точках доступа; кнопка Wi-Fi включает/выключает радио.
