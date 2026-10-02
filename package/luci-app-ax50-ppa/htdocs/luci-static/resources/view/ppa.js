'use strict';
'require view';
'require form';
'require fs';
'require ui';
'require tools.widgets as widgets';

/* Сеть → Аппаратное ускорение: настройки /etc/config/ppa (применяются через
 * procd reload trigger службы ax50-ppa) и состояние PPA. */

function getStatus() {
	return L.resolveDefault(fs.exec('/usr/libexec/ax50-ppa', [ 'status' ]), {}).then(function(res) {
		return res.stdout || '';
	});
}

function renderStatus(text) {
	var on = /^state: on/m.test(text);

	return E('div', { 'class': 'cbi-section' }, [
		E('h3', _('Status')),
		E('p', [
			_('Acceleration') + ': ',
			on ? E('strong', { 'style': 'color:green' }, _('enabled'))
			   : E('strong', { 'style': 'color:red' }, _('disabled'))
		]),
		on ? E('pre', { 'style': 'white-space:pre-wrap;max-height:30em;overflow:auto' },
			text.replace(/^state: on\n?/m, '')) : '',
		E('div', [
			E('button', {
				'class': 'cbi-button cbi-button-action',
				'click': ui.createHandlerFn(this, function() {
					return fs.exec('/usr/libexec/ax50-ppa', [ 'restart' ]).then(function() {
						location.reload();
					});
				})
			}, _('Restart acceleration'))
		])
	]);
}

return view.extend({
	load: function() {
		return getStatus();
	},

	render: function(status) {
		var m, s, o;

		m = new form.Map('ppa', _('Hardware acceleration'),
			_('Packet Processing Accelerator of the GRX350: established connections are moved to the switch engine (PAE) and the MPE firmware on the 4th CPU thread, bypassing the CPU. Accelerated traffic bypasses iptables, SQM and traffic counters.'));

		s = m.section(form.NamedSection, 'global', 'ppa');
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable acceleration'));
		o.rmempty = false;

		o = s.option(form.Value, 'threshold', _('Packet threshold'),
			_('A connection is accelerated after this many packets (stock firmware: 3).'));
		o.datatype = 'range(0,100)';
		o.placeholder = '3';

		o = s.option(form.Flag, 'pae', _('PAE engine'), _('Hardware routing and NAT in the switch.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Flag, 'mpe', _('MPE engine'), _('Acceleration firmware on CPU3 (not in this firmware: CPU3 is given to Linux).'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Flag, 'hwfp', _('Hardware fast path'), _('ppacmd setppefp'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Flag, 'swfp', _('Software fast path'), _('ppacmd setswfp'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(widgets.DeviceSelect, 'lan', _('LAN interfaces'),
			_('Stock firmware: br-lan, eth0_1…eth0_4.'));
		o.multiple = true;
		o.noaliases = true;

		o = s.option(form.Flag, 'wlan', _('Wi-Fi access points'), _('Add all wlan* interfaces to LAN.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(widgets.DeviceSelect, 'wan', _('WAN interfaces'), _('Stock firmware: eth1.'));
		o.multiple = true;
		o.noaliases = true;

		o = s.option(form.Flag, 'tunnels', _('PPPoE and L2TP'), _('Add pppoe-* and l2tp-* interfaces to WAN.'));
		o.default = '1';
		o.rmempty = false;

		return m.render().then(function(node) {
			return E([], [ renderStatus(status), node ]);
		});
	}
});
