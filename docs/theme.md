# Тема footstrap на LuCI 19.07

[luci-theme-footstrap](https://github.com/VizzleTF/luci-theme-footstrap) написана для
LuCI 24.10+: шаблоны на ucode, клиентский роутер страниц, современный CSS. В прошивке
LuCI 19.07 (её требует база prplWrt), поэтому пакет `package/luci-theme-footstrap`
собирает тему из исходников апстрима на закреплённом коммите и добавляет слой
совместимости `compat/`.

## Что совпадает с апстримом

Финальная ветка LuCI 19.07 уже содержит клиентский фреймворк, на котором стоит тема:
`baseclass`, `dom`, `ui.menu`, `view`, `rpc`, `form`, меню из `menu.d` (JSON) и
контексты переводов (`msgctxt`). Поэтому без изменений используются:

- CSS (`build-css.sh` апстрима: `cat` + `awk`);
- все JS-модули, включая клиентский роутер страниц и поиск;
- страница настроек «Система → Footstrap» (`menu.d`), ACL, `/etc/config/footstrap`,
  загрузка фона и шрифтов, русский перевод.

## Что пришлось перенести

| Апстрим (24.10+) | Здесь (19.07) |
|---|---|
| `header.ut` + `partials/*.ut` (ucode) | `compat/luasrc/view/themes/footstrap/header.htm` (Lua): та же разметка и inline-скрипт, санитизация `/etc/config/footstrap` один в один |
| `footer.ut`, `sysauth.ut` | `footer.htm`, `sysauth.htm` |
| `ui.RangeSlider`, `ui.Table`, `L.itemlist` | полифиллы в `fs-compat.js` |
| `L.env.pathinfo` на корневом URL | `fs-compat.js` подставляет `''`, иначе роутер темы отключается |
| `dispatcher.lookup()` для кнопки «Выйти» | проверка сессии: в 19.07 lookup по старому дереву не видит узлы `menu.d` |

`csstidy`/`jsmin` LuCI 19.07 для пакета отключены — они портят современный CSS
(`:has()`, `color-mix()`) и JS темы (апстрим отключает их по той же причине).

## Проверка

Тема проверяется в Chromium на настоящей LuCI 19.07.10 (x86 в Docker):

```bash
tools/luci-bench/run.sh start
tools/luci-bench/run.sh theme
tools/luci-bench/run.sh nav admin/status/overview admin/network/network admin/system/footstrap
```

Проверено: вход (светлая/тёмная схема), обзор, интерфейсы, межсетевой экран, система,
пароль, opkg, обновление прошивки, настройки темы (слайдеры, палитры), русский язык,
переходы через клиентский роутер без ошибок в консоли.

## Обновление темы

1. Поменять `PKG_SOURCE_VERSION` (и `PKG_VERSION`) в `package/luci-theme-footstrap/Makefile`.
2. Сравнить ucode-шаблоны апстрима с `compat/luasrc/view/themes/footstrap/*.htm`
   (`git diff <старый>..<новый> -- luci-theme-footstrap/ucode`).
3. Обновить `po/ru/footstrap.po` из апстрима.
4. Прогнать стенд (`tools/luci-bench`).

# Тема Proton2025 на LuCI 19.07

[luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025) — вторая
тема в образе (переключение: «Система → Система → Язык и тема»). Апстрим рассчитан на
OpenWrt 23.05+ (ucode); пакет `package/luci-theme-proton2025` собирает его на закреплённом
коммите и накладывает слой совместимости так же, как для footstrap.

| Апстрим (23.05+) | Здесь (19.07) |
|---|---|
| `header.ut`, `footer.ut`, `sysauth.ut` (ucode) | `compat/luasrc/view/themes/proton2025/*.htm` (Lua): разметка и inline-скрипты те же, данные из ubus — через `luci.util.ubus`, JSON — `luci.jsonc` |
| rpcd-модули `luci.proton-{settings,temp,system,search-cache}` (ucode) | exec-плагины на Lua в `compat/root/usr/libexec/rpcd/`; UCI — через `luci.model.uci` (Lua-биндинга `uci` в 19.07 нет) |
| пики температур в памяти rpcd | файл `/tmp/proton-temp-peaks.json` (exec-плагин живёт один вызов) |
| — | температура радиомодулей WAV600 (`iw … iwlwav gTemperature`) |
| проверка и установка обновлений с GitHub | отключены: релизы апстрима — для 23.05+, тема обновляется из фида прошивки |
| таблицы `<table>/<tr>/<td>` | в 19.07 это `<div class="table|tr|td">`: `divtables.py` при сборке переписывает селекторы CSS и `querySelector` в JS (`td` → `:is(td,.td)` и т. д.) и добавляет `display: table*` для `div` |

Без изменений: CSS (кроме селекторов таблиц), JS-модули, поиск по страницам, страница
настроек темы (карточка на «Система → Система»), страница температуры, переводы темы,
`/etc/config/proton2025`.

Исходники пакет берёт git-клоном (`PKG_MIRROR_HASH` — архив, который собирает
OpenWrt из клона). Локально за TLS-прокси git в контейнере сборки не доверяет его
сертификату — клонируйте апстрим на хост и подставьте его через
`git config --global url."file:///work/build/proton-src.git".insteadOf <URL апстрима>`.

Проверка на стенде:

```bash
tools/luci-bench/run.sh start
scripts/docker.sh scripts/build.sh package/feeds/ax50/luci-theme-proton2025/compile
docker cp build/prplwrt/bin/packages/*/ax50/luci-theme-proton2025_*.ipk luci-bench:/tmp/p.ipk
docker exec luci-bench sh -c 'opkg install /tmp/p.ipk; uci set luci.main.mediaurlbase=/luci-static/proton2025; uci commit luci'
tools/luci-bench/run.sh nav admin/status/overview admin/network/wireless admin/system/system
```
