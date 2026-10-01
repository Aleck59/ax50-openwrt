#
# Тема LuCI footstrap (https://github.com/VizzleTF/luci-theme-footstrap),
# портированная на LuCI 19.07 из prplWrt.
#
# Апстрим рассчитан на LuCI 24.10+ (шаблоны ucode). Пакет берёт его исходники
# на закреплённом коммите и накладывает слой совместимости compat/:
#   * luasrc/view/themes/footstrap/*.htm — Lua-порт header/footer/sysauth.ut;
#   * fs-compat.js — ui.RangeSlider, ui.Table, L.itemlist и L.env.pathinfo,
#     которых нет в клиентском API LuCI 19.07.
# CSS, JS-модули, меню (menu.d), ACL и перевод — апстримные. Проверено в
# браузере на LuCI 19.07.10 (см. docs/theme.md).
#
# При обновлении PKG_SOURCE_VERSION сверьте compat/ с ucode-шаблонами апстрима
# и обновите po/ru/footstrap.po.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-footstrap
PKG_VERSION:=0.14.13.20260926
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/VizzleTF/luci-theme-footstrap.git
PKG_SOURCE_VERSION:=726d612365d3acc01c7d4375c6367af0e57ad58a
PKG_MIRROR_HASH:=820161bc18fbfd95fc18b7fce0695c16ad7b0f4a4ceb314bc87a62d5930e8731

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE.footstrap
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

LUCI_TITLE:=Footstrap Theme
LUCI_DEPENDS:=+luci-base
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# csstidy и jsmin из LuCI 19.07 портят современный CSS (:has(), color-mix())
# и JS темы — апстрим отключает их по той же причине.
CONFIG_LUCI_CSSTIDY:=
CONFIG_LUCI_JSMIN:=

define Package/luci-theme-footstrap/conffiles
/etc/config/footstrap
endef

define Build/Prepare
	rm -rf $(PKG_BUILD_DIR)/upstream $(PKG_BUILD_DIR)/htdocs $(PKG_BUILD_DIR)/luasrc $(PKG_BUILD_DIR)/root
	mkdir -p $(PKG_BUILD_DIR)/upstream
	$(TAR) -C $(PKG_BUILD_DIR)/upstream --strip-components=1 -xJf $(DL_DIR)/$(PKG_SOURCE)
	sh ./assemble.sh $(PKG_BUILD_DIR)/upstream ./compat $(PKG_BUILD_DIR) $(PKG_VERSION)
endef

# call BuildPackage - OpenWrt buildroot signature
