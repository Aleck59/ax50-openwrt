#
# TP-Link Archer AX50 v1 (GRX350 + WAV654)
#
# Подключается из intel_mips/image/Makefile (патч
# patches/feed_target_mips/0001-image-include-tplink_ax50.patch).
#
# Формат образов наследуется от $(Device/xrx500):
#   *-squashfs-fullimage.img   uImage multi «ядро + rootfs» — для заливки из
#                              U-Boot командой `upgrade` (тома kernelA/rootfsA)
#   *-squashfs-sysupgrade.bin  tar для sysupgrade из уже работающей системы
#   *-initramfs-kernel.bin     ядро со встроенной rootfs для загрузки в ОЗУ
#
# Заводской образ для веб-интерфейса TP-Link не собирается: стоковые прошивки
# подписаны ключом TP-Link (файлы *_sign.bin).
#
ifeq ($(SUBTARGET),xrx500)

define Device/TPLINK_AX50
  $(Device/xrx500)
  DEVICE_DTS := tplink_archer-ax50-v1
  DEVICE_TITLE := TP-Link Archer AX50 v1
  SUPPORTED_DEVICES := tplink,archer-ax50-v1
  # system_sw = 124 MiB: два банка (kernel+rootfs A/B) и rootfs_data.
  IMAGE_SIZE := 49152k
  DEVICE_PACKAGES := ax50-base-files \
	kmod-intel_eth_toe_drv_xrx500 kmod-directconnect-dp kmod-litepath-hwacc \
	kmod-mac-violation-mirror ltq-gphy-fw-xrx5xx switch_cli_ugw8 \
	kmod-ppa-drv kmod-ppa-drv-accel kmod-ppa-drv-grx500 \
	kmod-ppa-drv-stack-al ppacmd \
	kmod-eip97 \
	kmod-iwlwav-driver-uci iwlwav-hostap-uci iwlwav-iw iwlwav-tools \
	iwlwav-base-files ltq-wlan-wave_6x-uci dwpal_6x-uci swpal_6x-uci iwinfo \
	kmod-usb-core kmod-usb-dwc3 kmod-usb-dwc3-grx500 kmod-usb3 \
	kmod-gpio-button-hotplug nand-utils
endef
TARGET_DEVICES += TPLINK_AX50

endif
