#
# TP-Link Archer AX50 v1 — рецепт образа для таргета intel_mips/xrx500.
#
# Подключается из intel_mips/image/Makefile строкой `-include ax50.mk`
# (её добавляет scripts/10-setup-tree.sh).
#
# Всё, что касается формата образа, наследуется от $(Device/xrx500):
#   Device/NAND            -> IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
#   Device/lantiqFullImage -> IMAGE/fullimage.img  := fullimage 16 | check-size $(IMAGE_SIZE)
# Свои IMAGE/... здесь намеренно не переопределяются: в ветке ugw-8.4.1-cleanup
# шага `append-rootfs-uImage` не существует (он появился только в 8.4.2), а
# `fullimage` сам склеивает ядро с rootfs.
#
# DEVICE_PACKAGES тоже намеренно не задаётся: переменные вроде $(OWRT_PACKAGES)
# и $(WAV600_PACKAGES_UCI) из packages.mk ссылаются на пакеты (base-files-owrt,
# owrt-*-scripts, ltq-wlan-wave6x-rflib, crda_wave_6x, libwlan_6x-uci и др.),
# которых в публично доступных фидах нет — сборка на них падает. Нужный набор
# задаётся списком packages в device/profiles/ax50.yml, он проверен целиком.
#
# ВАЖНО: заводской образ TP-Link подписан (файл в архиве прошивки называется
# ..._sign.bin, в шапке лежат soft-version/fw_id/support-list). Воспроизвести
# подпись мы не можем, поэтому factory-образ для веб-интерфейса TP-Link
# здесь НЕ собирается. Установка — только через U-Boot/TFTP, см. docs/04-flashing.md
#
ifeq ($(SUBTARGET),xrx500)

define Device/TPLINK_AX50
  $(Device/xrx500)
  DEVICE_DTS := tplink_ax50
  DEVICE_TITLE := TP-Link Archer AX50 v1
  # раздел system_sw — 250 MiB на два банка (A/B), ограничиваем образ 64 MiB
  IMAGE_SIZE := 65536k
endef
TARGET_DEVICES += TPLINK_AX50

endif
