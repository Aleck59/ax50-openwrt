#
# Поддержка платы TP-Link Archer AX50 v1: MAC-адреса, порты, светодиоды,
# кнопка WPS, конфигурация Wi-Fi по умолчанию, резервная копия заводских данных.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=ax50-base-files
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

include $(INCLUDE_DIR)/package.mk

define Package/ax50-base-files
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=TP-Link Archer AX50 v1 board support
  DEPENDS:=@TARGET_intel_mips_xrx500 +nand-utils
endef

define Package/ax50-base-files/description
  Board support for TP-Link Archer AX50 v1: factory MAC address lookup,
  LAN/WAN ports, LEDs, WPS button, sane default Wi-Fi configuration and
  a backup tool for the factory partitions (calibration, U-Boot env).
endef

define Build/Compile
endef

define Package/ax50-base-files/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,ax50-base-files))
