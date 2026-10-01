module("luci.controller.zapret", package.seeall)

function index()
	if not nixio.fs.access("/opt/zapret/config") then
		return
	end

	entry({"admin", "services", "zapret"}, view("zapret"), _("zapret"), 31).acl_depends = { "luci-app-zapret" }
end
