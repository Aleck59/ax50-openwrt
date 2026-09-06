# prplWrt на базе OpenWrt 22.03

Эксперимент по просьбе: поднять сборку на более свежей базе, чем 19.07.

## Два разных «22.03»

**Полный порт на ядро 5.10** — то, что в [`02-analysis.md`](02-analysis.md) помечено
как исследовательская задача. Я измерил его объём, а не оценил на глаз: вендорский
форк ядра содержит **1183 новых файла и 437 изменённых** относительно ванильного
4.9.206. Из них `arch/mips/lantiq` — 44 новых файла (поддержки GRX500 в mainline нет
вообще: в 5.10 из Lantiq только Amazon SE, XWAY и FALCON, серия патчей Intel 2018 года
так и не была принята), `drivers/net/ethernet/lantiq` — 113 новых файлов, весь
GSWIP-3.1 и датапат CBM/TMU/MPE. Это перенос вендорского BSP через четыре мажорные
версии ядра. Реалистичного пути в одиночку нет.

**Свежий userspace на вендорском ядре 4.9** — то, чем живёт сам prplWrt на 19.07.
Именно это здесь и сделано, только с базой 22.03: musl 1.2, GCC 11.2, современные
пакеты, fw4/nftables — при вендовском ядре 4.9.206, а значит при рабочем Wi-Fi.

Скрипт: [`../scripts/40-setup-2203.sh`](../scripts/40-setup-2203.sh).

## Статус

Ядро 4.9.206 **собирается и линкуется** тулчейном OpenWrt 22.03 (GCC 11.2, musl 1.2).
Сборка образа целиком — в работе, статус см. в конце файла.

## Что пришлось выяснить

Каждый пункт — реальная поломка, найденная на практике. Без любого из них сборка
молча делает не то или падает без внятного сообщения.

### 1. Таргет молча выпадает из списка

В 22.03 есть только `include/kernel-5.10`. Таргет `intel_mips` объявляет
`KERNEL_PATCHVER := 4.4` на верхнем уровне и `4.9` в субтаргете `xrx500`. Без файлов
`include/kernel-4.4` и `include/kernel-4.9` его Makefile обрывается на

```
include/kernel-version.mk:11: *** Missing kernel version/hash file for 4.4.
```

таргет не попадает в `tmp/.targetinfo`, а `make defconfig` **молча** скатывается на
`ath79`. Никакой ошибки при этом не печатается — легко не заметить и собрать
прошивку не для того устройства и даже не для той архитектуры.

Ядро берётся из git по `CONFIG_KERNEL_GIT_REF`, поэтому хеш тарболла в этих файлах
не используется — важно само их наличие.

### 2. Нет generic-слоя ядра 4.9

В 22.03 нет `target/linux/generic/{config,backport,hack,pending}-4.9`. Без
`config-4.9` ядро получает почти пустую конфигурацию, и kconfig начинает спрашивать
тип машины MIPS из 46 вариантов:

```
choice[1-46]: aborted!
Console input/output is redirected. Run 'make oldconfig' to update configuration.
```

Слой переносится из дерева 19.07: `config-4.9`, `backport-4.9` (97 патчей),
`hack-4.9` (37), `pending-4.9` (93).

### 3. Новые символы конфигурации без умолчаний

После появления generic-слоя всплывают символы, которых нет ни в одном конфиге.
Гасятся итеративно — тем же приёмом, что и в ветке 19.07
([`../scripts/lib/fix-kernel-build.sh`](../scripts/lib/fix-kernel-build.sh)).
На нашем дереве понадобилось 10 итераций, все — netfilter:

`NF_CONNTRACK_RTCACHE`, `NF_NAT_REDIRECT`, `NF_TABLES_INET`, `NFT_EXTHDR`,
`NFT_SET_RBTREE`, `NFT_SET_HASH`, `NF_TABLES_IPV4`, `NF_TABLES_ARP`,
`NF_TABLES_IPV6`, `NF_TABLES_BRIDGE`.

### 4. GCC 11 против ядра 4.9

Ядро 4.9 старше GCC 10, и новые предупреждения оказываются фатальными:

```
arch/mips/include/asm/string.h:162:25: error: '__builtin_memcpy' offset [0, 7]
    is out of the bounds [0, 0] [-Werror=array-bounds]
arch/mips/include/asm/string.h:162:25: error: writing 32 bytes into a region
    of size 0 [-Werror=stringop-overflow=]
include/linux/thread_info.h:124:17: error: 'uregs' may be used uninitialized
    [-Werror=maybe-uninitialized]
```

Передать `KCFLAGS` снаружи **не помогает** — флаги затираются. Работает только
правка Makefile самого ядра: после последней строки `-Werror=designated-init`
добавляются

```make
KBUILD_CFLAGS   += $(call cc-option,-Wno-error=array-bounds)
KBUILD_CFLAGS   += $(call cc-option,-Wno-error=stringop-overflow)
KBUILD_CFLAGS   += $(call cc-option,-Wno-error=stringop-truncation)
KBUILD_CFLAGS   += $(call cc-option,-Wno-error=maybe-uninitialized)
KBUILD_CFLAGS   += $(call cc-option,-Wno-error=zero-length-bounds)
KBUILD_CFLAGS   += $(call cc-option,-Wno-error=address)
KBUILD_CFLAGS   += $(call cc-option,-Wno-error=misleading-indentation)
```

После этого **всё ядро компилируется**, остаётся только линковка.

### 5. Датапат не линкуется без пакетов PPA

`vmlinux` не собирался с неразрешёнными ссылками:

```
undefined reference to `dp_mib_init'
undefined reference to `dp_mib_exit'
undefined reference to `dp_reset_sys_mib'
undefined reference to `reset_gsw_itf'
undefined reference to `get_free_itf'
```

Все они определены в `drivers/net/datapath/dpm/gswip30/datapath_mib.c`, который
собирается только при `CONFIG_INTEL_DATAPATH_HAL_GSWIP30_MIB`. У этого символа
цепочка зависимостей:

```
depends on INTEL_DATAPATH_HAL_GSWIP30 && SOC_GRX500 && LTQ_TMU
        && PPA_TMU_MIB_SUPPORT && INTEL_DATAPATH_MIB
```

Четыре из пяти были выставлены, а `PPA_TMU_MIB_SUPPORT` отсутствовал как символ:
его приносит не ядро, а пакет `ppa_drv` из фида PPA через свой `KCONFIG`.
Просто дописать символ в конфиг таргета бесполезно — зависимость всё равно не
выполняется. Лечится подключением фидов Intel в дерево 22.03 и выбором пакетов:

```
kmod-ppa-drv, kmod-ppa-drv-accel, kmod-ppa-drv-grx500,
kmod-ppa-drv-grx500-mpe, kmod-ppa-drv-mpe-ip97, kmod-ppa-drv-stack-al
```

После этого ядро собирается и линкуется полностью.

## Чего это не решает

Ядро остаётся 4.9.206 — со всеми его ограничениями по безопасности и по
отсутствию современных подсистем. Свежее только userspace. Настоящий скачок
даёт лишь порт BSP на 5.10, объём которого приведён выше.
