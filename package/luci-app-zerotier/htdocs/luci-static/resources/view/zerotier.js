'use strict';
'require view';
'require form';
'require fs';

/* Службы → ZeroTier: /etc/config/zerotier (служба перезапускается procd
 * reload trigger) и состояние узла: zerotier-cli info / listnetworks. */

function cli(args) {
	return L.resolveDefault(fs.exec('/usr/bin/zerotier-cli', args), {}).then(function(res) {
		return (res.code == 0 && res.stdout) ? res.stdout.trim() : '';
	});
}

return view.extend({
	load: function() {
		return Promise.all([ cli([ 'info' ]), cli([ 'listnetworks' ]) ]);
	},

	render: function(data) {
		var info = data[0], nets = data[1], m, s, o;

		m = new form.Map('zerotier', _('ZeroTier'),
			_('Access to the home network without a public IP. Join a network by its ID (my.zerotier.com), then authorize this router in the network settings. Interfaces zt* are in the firewall zone "zerotier" with access to LAN.'));

		s = m.section(form.NamedSection, 'global', 'zerotier');
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.rmempty = false;

		o = s.option(form.Value, 'port', _('Port'), _('UDP port, default 9993.'));
		o.datatype = 'port';
		o.placeholder = '9993';

		s = m.section(form.GridSection, 'network', _('Networks'));
		s.anonymous = true;
		s.addremove = true;

		o = s.option(form.Value, 'id', _('Network ID'), _('16-digit network ID.'));
		o.datatype = 'and(hexstring,length(16))';
		o.rmempty = false;

		o = s.option(form.Flag, 'allow_managed', _('Managed addresses'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Flag, 'allow_global', _('Global addresses'));
		o.default = '0';

		o = s.option(form.Flag, 'allow_default', _('Default route'));
		o.default = '0';

		o = s.option(form.Flag, 'allow_dns', _('DNS'));
		o.default = '0';

		return m.render().then(function(node) {
			return E([], [
				E('div', { 'class': 'cbi-section' }, [
					E('h3', _('Status')),
					info
						? E('pre', { 'style': 'white-space:pre-wrap' }, info + (nets ? '\n\n' + nets : ''))
						: E('p', {}, _('ZeroTier is not running.'))
				]),
				node
			]);
		});
	}
});
