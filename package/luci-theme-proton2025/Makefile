#
# Тема LuCI Proton2025 (https://github.com/ChesterGoodiny/luci-theme-proton2025),
# портированная на LuCI 19.07 из prplWrt.
#
# Апстрим рассчитан на OpenWrt 23.05+ (шаблоны и rpcd-модули на ucode). Пакет
# берёт его исходники на закреплённом коммите и накладывает слой compat/:
#   * luasrc/view/themes/proton2025/*.htm — Lua-порт header/footer/sysauth.ut;
#   * root/usr/libexec/rpcd/luci.proton-* — Lua-порт rpcd-модулей (настройки,
#     температура + радиомодули WAV600, поиск, сведения о системе).
# CSS, JS, меню (menu.d), ACL, переводы темы — апстримные. Обновления темы с
# GitHub отключены: релизы апстрима — для 23.05+. Проверено в браузере на
# LuCI 19.07.10 (см. docs/theme.md).
#
# При обновлении PKG_SOURCE_VERSION сверьте compat/ с ucode-шаблонами и
# rpcd-модулями апстрима.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-proton2025
PKG_VERSION:=1.4.2
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/ChesterGoodiny/luci-theme-proton2025.git
PKG_SOURCE_VERSION:=d7d415804b238c039dcbdec89d89b9b0ff795ad9
PKG_MIRROR_HASH:=808c4fad22e32a912d5dd4d5142136fd46b1ce7172c9e322818c152f3b71036e

PKG_LICENSE:=Apache-2.0 MIT
PKG_LICENSE_FILES:=LICENSE.proton2025 NOTICE.proton2025
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

LUCI_TITLE:=Proton2025 Theme
LUCI_DEPENDS:=+luci-base
LUCI_PKGARCH:=all

# csstidy и jsmin LuCI 19.07 портят современный CSS и JS темы (апстрим
# тоже отключает минификацию)
CONFIG_LUCI_CSSTIDY:=
CONFIG_LUCI_JSMIN:=

define Package/luci-theme-proton2025/conffiles
/etc/config/proton2025
endef

# Распаковка — в $(PKG_BUILD_DIR)/upstream, раскладку собирает assemble.sh
# (см. luci-theme-footstrap)
PKG_UNPACK:=true

define Proton/Assemble
	mkdir -p $(PKG_BUILD_DIR)/upstream
	$(TAR) -C $(PKG_BUILD_DIR)/upstream --strip-components=1 -xJf $(DL_DIR)/$(PKG_SOURCE)
	sh ./assemble.sh $(PKG_BUILD_DIR)/upstream ./compat $(PKG_BUILD_DIR)
endef
Hooks/Prepare/Post += Proton/Assemble

include $(TOPDIR)/feeds/luci/luci.mk

# uci-defaults темы запускает штатный default_postinst; здесь — как в luci.mk:
# сброс кэша LuCI и перечитывание rpcd (новые плагины и ACL)
define Package/luci-theme-proton2025/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || {
	rm -f /tmp/luci-indexcache /tmp/proton-search-prefetch-cache.json /tmp/proton-search-prefetch-cache-meta.json
	rm -rf /tmp/luci-modulecache/
	killall -HUP rpcd 2>/dev/null
}
exit 0
endef

# call BuildPackage - OpenWrt buildroot signature
