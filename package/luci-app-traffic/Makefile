#
# LuCI: статистика трафика WAN (сутки, месяцы, 30 дней, часы, текущая
# скорость) по данным vnstat. Порт https://github.com/HanHan666666/luci-app-traffic
# (MIT, коммит 1f24c1b) на LuCI 19.07: бэкенд ucode заменён rpcd-плагином на sh.
#
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI traffic dashboard (vnstat)
LUCI_DEPENDS:=+vnstat
LUCI_PKGARCH:=all
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
