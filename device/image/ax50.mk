#
# TP-Link Archer AX50 v1 — рецепт образа для таргета intel_mips/xrx500.
#
# Подключается из intel_mips/image/Makefile строкой `-include ax50.mk`
# (её добавляет scripts/10-setup-tree.sh).
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
  # system_sw = 250 MiB на два банка; ограничиваем образ 64 MiB на банк
  IMAGE_SIZE := 65536k
  DEVICE_PACKAGES := $(OWRT_PACKAGES) $(WAV600_PACKAGES_UCI) $(WAV600_UGW_PACKAGES_UCI)
  IMAGES := sysupgrade.bin fullimage.img
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
  IMAGE/fullimage.img := append-kernel | append-rootfs-uImage 16 | fullimage | check-size $$$$(IMAGE_SIZE)
endef
TARGET_DEVICES += TPLINK_AX50

endif
