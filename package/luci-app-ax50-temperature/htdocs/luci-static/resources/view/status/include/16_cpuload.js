'use strict';
'require baseclass';
'require fs';

/* Блок «Нагрузка ядер» на главной странице (Статус → Обзор): загрузка каждого
 * потока процессора по /proc/stat между двумя опросами страницы. */

var prev = null;

function sample() {
	return L.resolveDefault(fs.read('/proc/stat'), '').then(function(text) {
		var cpus = {};

		text.split(/\n/).forEach(function(line) {
			var m = line.match(/^(cpu\d*)\s+(.*)$/);
			if (!m)
				return;

			/* user nice system idle iowait irq softirq steal */
			var v = m[2].trim().split(/\s+/).map(Number);
			var idle = v[3] + (v[4] || 0);
			var total = v.slice(0, 8).reduce(function(a, b) { return a + (b || 0); }, 0);

			cpus[m[1]] = { total: total, idle: idle, sirq: (v[5] || 0) + (v[6] || 0) };
		});

		return cpus;
	});
}

function delta(a, b) {
	var dt = b.total - a.total;
	if (dt <= 0)
		return { load: 0, sirq: 0 };
	return {
		load: 100 * (dt - (b.idle - a.idle)) / dt,
		sirq: 100 * (b.sirq - a.sirq) / dt
	};
}

function bar(load, sirq) {
	var color = (load >= 90) ? '#d9534f' : (load >= 70) ? '#f0ad4e' : '';

	return E('div', {
		'class': 'cbi-progressbar',
		'title': '%.0f%% (%s %.0f%%)'.format(load, _('interrupts'), sirq)
	}, E('div', { 'style': 'width:%.0f%%%s'.format(load, color ? ';background-color:' + color : '') }));
}

return baseclass.extend({
	title: _('CPU core load'),

	load: function() {
		/* Первый показ: второй замер через полсекунды */
		var first = prev ? Promise.resolve(prev) : sample().then(function(s) {
			return new Promise(function(resolve) { window.setTimeout(function() { resolve(s); }, 500); });
		});

		return first.then(function(a) {
			return sample().then(function(b) {
				prev = b;
				return [ a, b ];
			});
		});
	},

	render: function(data) {
		var a = data[0], b = data[1],
		    names = Object.keys(b).filter(function(n) { return n != 'cpu' && a[n]; })
				.sort(function(x, y) { return x.substr(3) - y.substr(3); }),
		    table = E('table', { 'class': 'table' });

		if (!names.length)
			return null;

		names.forEach(function(n) {
			var d = delta(a[n], b[n]);

			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ _('Core %d').format(+n.substr(3)) ]),
				E('td', { 'class': 'td left' }, [ bar(d.load, d.sirq) ])
			]));
		});

		if (b.cpu && a.cpu) {
			var t = delta(a.cpu, b.cpu);

			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ _('Total') ]),
				E('td', { 'class': 'td left' }, [
					'%.0f%%, %s %.0f%%'.format(t.load, _('interrupts'), t.sirq)
				])
			]));
		}

		return table;
	}
});
