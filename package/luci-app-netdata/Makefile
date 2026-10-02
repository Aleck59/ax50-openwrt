#
# LuCI: панель Netdata (мониторинг в реальном времени) во фрейме, запуск и
# остановка службы.
#
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI page for Netdata
LUCI_DEPENDS:=+netdata
LUCI_PKGARCH:=all
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
