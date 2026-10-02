#
# LuCI: температура процессора и радиомодулей Wi-Fi на главной странице.
#
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI temperature block (CPU and Wi-Fi) for TP-Link Archer AX50
LUCI_DEPENDS:=+luci-mod-status +iwlwav-iw
LUCI_PKGARCH:=all
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
