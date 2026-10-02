#
# LuCI: температура процессора и Wi-Fi и нагрузка ядер на главной странице.
#
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI status blocks for TP-Link Archer AX50: temperature, CPU core load
LUCI_DEPENDS:=+luci-mod-status +iwlwav-iw
LUCI_PKGARCH:=all
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
