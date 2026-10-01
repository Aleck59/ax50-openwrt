module("luci.controller.adguardhome", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/adguardhome") then
		return
	end

	entry({"admin", "services", "adguardhome"}, view("adguardhome"), _("AdGuard Home"), 30).acl_depends = { "luci-app-adguardhome" }
end
