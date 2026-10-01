'use strict';
'require view';
'require form';
'require fs';
'require rpc';
'require ui';

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: [ 'name' ],
	expect: { '': {} }
});

function isRunning() {
	return L.resolveDefault(callServiceList('adguardhome'), {}).then(function(res) {
		var instances = (res.adguardhome || {}).instances || {};
		for (var k in instances)
			if (instances[k].running)
				return true;
		return false;
	});
}

/* Адреса веб-интерфейса и DNS из /etc/adguardhome.yaml (без полноценного YAML-парсера) */
function parseYaml(text) {
	var conf = { configured: false, web_port: 3000, dns_port: null };

	if (!text)
		return conf;

	conf.configured = true;

	var m = text.match(/^http:\s*\n(?:[ \t]+.*\n)*?[ \t]+address:\s*[^\n]*:(\d+)\s*$/m);
	if (m)
		conf.web_port = +m[1];
	else if ((m = text.match(/^bind_port:\s*(\d+)/m)) != null)
		conf.web_port = +m[1];

	m = text.match(/^dns:\s*\n(?:[ \t]+.*\n)*?  port:\s*(\d+)/m);
	if (m)
		conf.dns_port = +m[1];

	return conf;
}

function serviceAction(action) {
	return fs.exec('/etc/init.d/adguardhome', [ action ]).then(function() {
		window.setTimeout(function() { location.reload(); }, 1500);
	}).catch(function(e) {
		ui.addNotification(null, E('p', e.message));
	});
}

return view.extend({
	load: function() {
		return Promise.all([
			isRunning(),
			L.resolveDefault(fs.read('/etc/adguardhome.yaml'), null),
			L.resolveDefault(fs.exec('/usr/bin/AdGuardHome', [ '--version' ]), {})
		]);
	},

	render: function(data) {
		var running = data[0],
		    conf = parseYaml(data[1]),
		    version = ((data[2] || {}).stdout || '').trim(),
		    host = window.location.hostname,
		    url = 'http://' + host + ':' + conf.web_port + '/',
		    m, s, o;

		m = new form.Map('adguardhome', _('AdGuard Home'),
			_('Network-wide DNS filtering of ads and trackers. Detailed settings, filter lists and statistics are in the AdGuard Home web interface.'));

		s = m.section(form.NamedSection, 'config', 'adguardhome');
		s.anonymous = true;

		o = s.option(form.DummyValue, '_status', _('Status'));
		o.rawhtml = true;
		o.cfgvalue = function() {
			var state = running
				? '<span style="color:green">' + _('Running') + '</span>'
				: '<span style="color:red">' + _('Not running') + '</span>';
			return state + (version ? ' &#8212; ' + version : '');
		};

		o = s.option(form.DummyValue, '_webui', _('Web interface'));
		o.rawhtml = true;
		o.cfgvalue = function() {
			var hint = conf.configured ? '' :
				'<br /><em>' + _('Not configured yet: open the web interface to run the setup wizard. For DNS choose port 5353, then enable forwarding below.') + '</em>';
			return '<a href="' + url + '" target="_blank" rel="noopener">' + url + '</a>' + hint;
		};

		o = s.option(form.DummyValue, '_actions', _('Service'));
		o.render = function() {
			return E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, _('Service')),
				E('div', { 'class': 'cbi-value-field' }, [
					E('button', {
						'class': 'cbi-button cbi-button-apply',
						'click': ui.createHandlerFn(this, serviceAction, running ? 'restart' : 'start')
					}, running ? _('Restart') : _('Start')), ' ',
					E('button', {
						'class': 'cbi-button cbi-button-reset',
						'disabled': running ? null : true,
						'click': ui.createHandlerFn(this, serviceAction, 'stop')
					}, _('Stop'))
				])
			]);
		};

		o = s.option(form.Flag, 'enabled', _('Enable'),
			_('Start AdGuard Home at boot.'));
		o.rmempty = false;

		o = s.option(form.Flag, 'dnsmasq_upstream', _('Filter DNS of the whole network'),
			conf.dns_port
				? _('dnsmasq will forward all DNS queries to AdGuard Home on port %d. Local DHCP host names keep working.').format(conf.dns_port)
				: _('Available after the setup wizard is complete.'));
		o.rmempty = false;
		o.readonly = !conf.dns_port || conf.dns_port == 53;

		return m.render();
	}
});
