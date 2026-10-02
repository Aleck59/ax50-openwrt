'use strict';
'require baseclass';
'require fs';

/* Блок «Температура» на главной странице (Статус → Обзор). */

function level(t) {
	if (t >= 95) return 'color:#d9534f;font-weight:bold';
	if (t >= 80) return 'color:#f0ad4e;font-weight:bold';
	return '';
}

function cell(t) {
	return E('span', { 'style': level(t) }, '%.1f °C'.format(t));
}

return baseclass.extend({
	title: _('Temperature'),

	load: function() {
		return L.resolveDefault(fs.exec('/usr/libexec/ax50-temperature'), null).then(function(res) {
			try { return JSON.parse(res.stdout); }
			catch (e) { return null; }
		});
	},

	render: function(data) {
		if (!L.isObject(data))
			return null;

		var table = E('table', { 'class': 'table' }),
		    rows = [];

		(data.cpu || []).forEach(function(z, i) {
			rows.push([ (data.cpu.length > 1) ? _('Processor') + ' (' + z.name + ')' : _('Processor'), z.temp ]);
		});

		(data.wifi || []).forEach(function(w) {
			rows.push([ _('Wi-Fi %s GHz').format(w.band), w.temp ]);
		});

		if (!rows.length)
			return null;

		rows.forEach(function(r) {
			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ r[0] ]),
				E('td', { 'class': 'td left' }, [ cell(r[1]) ])
			]));
		});

		return table;
	}
});
