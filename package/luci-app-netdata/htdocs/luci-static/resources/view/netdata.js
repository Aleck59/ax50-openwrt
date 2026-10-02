'use strict';
'require fs';
'require ui';

/* Netdata слушает порт 19999 на всех адресах (см. /etc/netdata/netdata.conf) */
var port = 19999;

function service(action) {
	return fs.exec('/etc/init.d/netdata', [ action ]).then(function() {
		if (action == 'start' || action == 'stop')
			return fs.exec('/etc/init.d/netdata', [ action == 'start' ? 'enable' : 'disable' ]);
	}).then(function() {
		window.setTimeout(function() { location.reload(); }, 2000);
	}).catch(function(e) {
		ui.addNotification(null, E('p', e.message));
	});
}

return L.view.extend({
	load: function() {
		return fs.exec('/bin/pidof', [ 'netdata' ]).then(function(res) {
			return res.code == 0;
		}).catch(function() { return false; });
	},

	render: function(running) {
		var url = '%s//%s:%d/'.format(window.location.protocol == 'https:' ? 'http:' : window.location.protocol,
			window.location.hostname, port);

		var bar = E('div', { 'class': 'cbi-page-actions', 'style': 'text-align:left' }, [
			E('span', { 'style': 'margin-right:1em' }, [
				_('Status') + ': ',
				E('strong', {}, running ? _('running') : _('stopped'))
			]),
			E('button', {
				'class': 'cbi-button ' + (running ? 'cbi-button-reset' : 'cbi-button-apply'),
				'click': ui.createHandlerFn(this, service, running ? 'stop' : 'start')
			}, running ? _('Stop') : _('Start')),
			' ',
			running ? E('a', { 'class': 'cbi-button', 'href': url, 'target': '_blank' }, _('Open in new tab')) : ''
		]);

		return E('div', {}, [
			E('h2', {}, _('Netdata')),
			E('div', { 'class': 'cbi-map-descr' },
				_('Real-time monitoring of the router. Netdata uses about 30 MB of RAM; stop it when not needed.')),
			bar,
			running
				? E('iframe', { 'src': url, 'style': 'width:100%;height:80vh;border:none' })
				: E('p', {}, _('Netdata is not running.'))
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
