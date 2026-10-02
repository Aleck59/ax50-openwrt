#
# LuCI: аппаратное ускорение PPA (GRX350: PAE, MPE) — настройки /etc/config/ppa
# и состояние ускорителя.
#
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI page for PPA hardware acceleration (TP-Link Archer AX50)
LUCI_DEPENDS:=+ax50-base-files +ppacmd
LUCI_PKGARCH:=all
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
