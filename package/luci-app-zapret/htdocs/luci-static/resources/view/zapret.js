'use strict';
'require view';
'require fs';
'require rpc';
'require ui';

var INIT = '/etc/init.d/zapret';

var FILES = [
	{ id: 'config',  path: '/opt/zapret/config',
	  title: _('Configuration'),
	  help: _('Shell variables of zapret. The DPI desync strategy is NFQWS_OPT; pick one for your ISP with /opt/zapret/blockcheck.sh.') },
	{ id: 'user',    path: '/opt/zapret/ipset/zapret-hosts-user.txt',
	  title: _('Domains'),
	  help: _('Domains processed by zapret, one per line (subdomains included).') },
	{ id: 'exclude', path: '/opt/zapret/ipset/zapret-hosts-user-exclude.txt',
	  title: _('Exclusions'),
	  help: _('Domains that are never processed.') },
	{ id: 'auto',    path: '/opt/zapret/ipset/zapret-hosts-auto.txt',
	  title: _('Detected automatically'),
	  help: _('Blocked domains detected by nfqws (MODE_FILTER=autohostlist). Clear the list if something works worse than without zapret.') }
];

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: [ 'name' ],
	expect: { '': {} }
});

function isRunning() {
	return L.resolveDefault(callServiceList('zapret'), {}).then(function(res) {
		var instances = (res.zapret || {}).instances || {};
		for (var k in instances)
			if (instances[k].running)
				return true;
		return false;
	});
}

function isEnabled() {
	return fs.exec(INIT, [ 'enabled' ]).then(function(res) {
		return res.code == 0;
	}).catch(function() { return false; });
}

function initAction(action) {
	return fs.exec(INIT, [ action ]).then(function(res) {
		if (res.code != 0)
			ui.addNotification(null, E('pre', [ res.stderr || res.stdout || action ]));
		window.setTimeout(function() { location.reload(); }, 1000);
	}).catch(function(e) {
		ui.addNotification(null, E('p', e.message));
	});
}

return view.extend({
	load: function() {
		return Promise.all([
			isRunning(),
			isEnabled()
		].concat(FILES.map(function(f) {
			return L.resolveDefault(fs.read(f.path), '');
		})));
	},

	saveFile: function(f, restart) {
		var value = document.getElementById('zapret-' + f.id).value.replace(/\r\n/g, '\n');

		if (value.length && value.charAt(value.length - 1) != '\n')
			value += '\n';

		return fs.write(f.path, value).then(function() {
			ui.addNotification(null, E('p', _('Saved: %s').format(f.path)), 'info');
			if (restart)
				return initAction('restart');
		}).catch(function(e) {
			ui.addNotification(null, E('p', e.message));
		});
	},

	render: function(data) {
		var running = data[0],
		    enabled = data[1],
		    contents = data.slice(2),
		    self = this;

		var status = E('div', { 'class': 'cbi-section' }, [
			E('h3', _('Service')),
			E('p', [
				_('Status') + ': ',
				running
					? E('strong', { 'style': 'color:green' }, _('Running'))
					: E('strong', { 'style': 'color:red' }, _('Not running')),
				' / ',
				enabled ? _('starts at boot') : _('does not start at boot')
			]),
			E('div', [
				E('button', {
					'class': 'cbi-button cbi-button-apply',
					'click': ui.createHandlerFn(this, initAction, running ? 'restart' : 'start')
				}, running ? _('Restart') : _('Start')), ' ',
				E('button', {
					'class': 'cbi-button cbi-button-reset',
					'disabled': running ? null : true,
					'click': ui.createHandlerFn(this, initAction, 'stop')
				}, _('Stop')), ' ',
				E('button', {
					'class': 'cbi-button',
					'click': ui.createHandlerFn(this, initAction, enabled ? 'disable' : 'enable')
				}, enabled ? _('Disable autostart') : _('Enable autostart'))
			])
		]);

		var panes = FILES.map(function(f, i) {
			return E('div', { 'data-tab': f.id, 'data-tab-title': f.title }, [
				E('p', { 'class': 'cbi-section-descr' }, f.help),
				E('textarea', {
					'id': 'zapret-' + f.id,
					'style': 'width:100%; font-family:monospace',
					'rows': f.id == 'config' ? 30 : 15,
					'spellcheck': 'false',
					'wrap': 'off'
				}, [ contents[i] || '' ]),
				E('div', { 'class': 'right' }, [
					E('button', {
						'class': 'cbi-button cbi-button-save',
						'click': ui.createHandlerFn(self, 'saveFile', f, false)
					}, _('Save')), ' ',
					E('button', {
						'class': 'cbi-button cbi-button-apply',
						'click': ui.createHandlerFn(self, 'saveFile', f, true)
					}, _('Save and restart'))
				])
			]);
		});

		var tabs = E('div', {}, panes);
		ui.tabs.initTabGroup(tabs.childNodes);

		return E([], [
			E('h2', _('zapret')),
			E('div', { 'class': 'cbi-map-descr' },
				_('DPI circumvention (bol-van/zapret). Only listed and automatically detected domains are processed.')),
			status,
			E('div', { 'class': 'cbi-section' }, tabs)
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
