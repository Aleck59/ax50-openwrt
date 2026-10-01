#
# zapret — обход DPI (bol-van/zapret), режим iptables/fw3 для OpenWrt 19.07.
#
# Ставится как у автора (install_easy.sh): дерево в /opt/zapret, служба —
# симлинк /etc/init.d/zapret на init.d/openwrt/zapret, правила firewall —
# через include fw3 (/etc/firewall.zapret). Настройки — /opt/zapret/config.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=zapret
PKG_VERSION:=72.13
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/bol-van/zapret.git
PKG_SOURCE_VERSION:=87e058624c72863db53bdaf7fb6f16576dddb6ab
PKG_MIRROR_HASH:=89e1f2b3977b9ac42390857e35822ff7b0a1d9183779eabc09ba057e24ea306b

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=docs/LICENSE.txt
PKG_MAINTAINER:=ax50-openwrt <https://github.com/Aleck59/ax50-openwrt>

include $(INCLUDE_DIR)/package.mk

define Package/zapret
  SECTION:=net
  CATEGORY:=Network
  TITLE:=zapret — DPI circumvention (nfqws, tpws)
  URL:=https://github.com/bol-van/zapret
  DEPENDS:=+libnetfilter-queue +libnfnetlink +libmnl +zlib +libpthread \
	+iptables +ip6tables +ipset +curl +gzip \
	+kmod-ipt-nfqueue +iptables-mod-nfqueue +kmod-nfnetlink-queue \
	+kmod-ipt-conntrack-extra +iptables-mod-conntrack-extra \
	+kmod-ipt-ipset +kmod-ipt-nat +kmod-ipt-nat6 +iptables-mod-extra
endef

define Package/zapret/description
  Autonomous DPI circumvention tool: nfqws (packet modification via NFQUEUE)
  and tpws (transparent proxy), with OpenWrt integration from upstream.
endef

define Package/zapret/conffiles
/opt/zapret/config
/opt/zapret/ipset/zapret-hosts-user.txt
/opt/zapret/ipset/zapret-hosts-user-exclude.txt
/opt/zapret/ipset/zapret-hosts-user-ipban.txt
/opt/zapret/ipset/zapret-ip-user.txt
/opt/zapret/ipset/zapret-ip-exclude.txt
endef

# Сборка без -flto=auto из Makefile'ов автора: GCC 7.5 его не понимает
ZAPRET_CFLAGS:=$(TARGET_CFLAGS) -std=gnu99 -ffunction-sections -fdata-sections
ZAPRET_LDFLAGS:=$(TARGET_LDFLAGS) -Wl,--gc-sections

define Build/Compile
	for d in nfq tpws ip2net mdig; do \
		$(MAKE) -C $(PKG_BUILD_DIR)/$$$$d \
			CC="$(TARGET_CC)" CFLAGS="$(ZAPRET_CFLAGS)" \
			LDFLAGS="$(ZAPRET_LDFLAGS)" OPTIMIZE= || exit 1; \
	done
endef

define Package/zapret/install
	$(INSTALL_DIR) $(1)/opt/zapret
	$(CP) $(PKG_BUILD_DIR)/common $(PKG_BUILD_DIR)/files $(PKG_BUILD_DIR)/ipset \
		$(1)/opt/zapret/
	$(INSTALL_DIR) $(1)/opt/zapret/init.d
	$(CP) $(PKG_BUILD_DIR)/init.d/openwrt $(1)/opt/zapret/init.d/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/blockcheck.sh $(1)/opt/zapret/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/config.default $(1)/opt/zapret/config.default
	$(INSTALL_DATA) ./files/config $(1)/opt/zapret/config
	$(INSTALL_DATA) ./files/zapret-hosts-user.txt $(1)/opt/zapret/ipset/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ipset/zapret-hosts-user-exclude.txt.default \
		$(1)/opt/zapret/ipset/zapret-hosts-user-exclude.txt
	touch $(1)/opt/zapret/ipset/zapret-hosts-user-ipban.txt \
		$(1)/opt/zapret/ipset/zapret-ip-user.txt \
		$(1)/opt/zapret/ipset/zapret-ip-exclude.txt
	for d in nfq:nfqws tpws:tpws ip2net:ip2net mdig:mdig; do \
		$(INSTALL_DIR) $(1)/opt/zapret/$$$${d%%:*}; \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/$$$${d%%:*}/$$$${d##*:} $(1)/opt/zapret/$$$${d%%:*}/; \
	done
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/hotplug.d/iface $(1)/etc/uci-defaults
	ln -sf /opt/zapret/init.d/openwrt/zapret $(1)/etc/init.d/zapret
	ln -sf /opt/zapret/init.d/openwrt/90-zapret $(1)/etc/hotplug.d/iface/90-zapret
	ln -sf /opt/zapret/init.d/openwrt/firewall.zapret $(1)/etc/firewall.zapret
	$(INSTALL_BIN) ./files/zapret.uci-defaults $(1)/etc/uci-defaults/90-zapret
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/zapret.keep $(1)/lib/upgrade/keep.d/zapret
endef

define Package/zapret/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
uci -q delete firewall.zapret && uci -q commit firewall
/etc/init.d/firewall reload >/dev/null 2>&1
exit 0
endef

$(eval $(call BuildPackage,zapret))
