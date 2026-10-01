#
# AdGuard Home — DNS-сервер с блокировкой рекламы и трекеров.
#
# Ставится официальная статическая сборка (Go, без зависимостей): тулчейн Go
# из фидов OpenWrt 19.07 (1.13) слишком стар для актуального AdGuard Home.
# Целостность — по SHA-256 из checksums.txt релиза.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=adguardhome
PKG_VERSION:=0.107.79
PKG_RELEASE:=1

ifeq ($(ARCH),mipsel)
  AGH_ARCH:=mipsle_softfloat
  PKG_HASH:=f2b6cccb5272fe726b09a35463732c580e4e8fab8a4e6e717a7d9af4d02b532c
else
  AGH_ARCH:=mips_softfloat
  PKG_HASH:=7f72c1d4db8bd29a12b24ca19ac9ddaac3963765fcaa580577dfea33811a9cb0
endif

PKG_SOURCE:=AdGuardHome_linux_$(AGH_ARCH)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/AdguardTeam/AdGuardHome/releases/download/v$(PKG_VERSION)/
PKG_SOURCE_URL_FILE:=AdGuardHome_linux_$(AGH_ARCH).tar.gz

PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE.txt
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

include $(INCLUDE_DIR)/package.mk

define Package/adguardhome
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  TITLE:=AdGuard Home — network-wide ads & trackers blocking DNS server
  URL:=https://github.com/AdguardTeam/AdGuardHome
  DEPENDS:=@(mips||mipsel) +ca-bundle
  USERID:=
endef

define Package/adguardhome/description
  AdGuard Home is a network-wide DNS server for blocking ads and tracking,
  with DNS-over-HTTPS/TLS/QUIC upstreams and a web interface.
endef

define Package/adguardhome/conffiles
/etc/config/adguardhome
/etc/adguardhome.yaml
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -C $(PKG_BUILD_DIR) --strip-components=1 -xzf $(DL_DIR)/$(PKG_SOURCE)
endef

define Build/Compile
endef

define Package/adguardhome/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/AdGuardHome $(1)/usr/bin/AdGuardHome
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/config $(1)/lib/upgrade/keep.d
	$(INSTALL_BIN) ./files/adguardhome.init $(1)/etc/init.d/adguardhome
	$(INSTALL_CONF) ./files/adguardhome.config $(1)/etc/config/adguardhome
	$(INSTALL_DATA) ./files/adguardhome.keep $(1)/lib/upgrade/keep.d/adguardhome
endef

$(eval $(call BuildPackage,adguardhome))
