#
# LuCI: ZeroTier — включение, сети (join), порт, состояние узла и сетей,
# зона межсетевого экрана для интерфейсов zt*.
#
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI page for ZeroTier
LUCI_DEPENDS:=+zerotier
LUCI_PKGARCH:=all
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
