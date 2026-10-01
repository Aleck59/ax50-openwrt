'use strict';
'require baseclass';
'require dom';
'require ui';

/*
 * luci-theme-footstrap на LuCI 19.07 (ax50-openwrt).
 *
 * Тема написана под LuCI 24.10+, где в клиентском API есть ui.RangeSlider,
 * ui.Table и L.itemlist. В финальной LuCI 19.07 остальной API тот же
 * (baseclass, dom, ui.menu, view, rpc), а этих трёх нет — модуль добавляет их,
 * повторяя поведение апстрима. Подключается первым (footer.htm) и из модулей
 * темы, которым они нужны (Makefile вставляет 'require fs-compat').
 */

/* На корневом URL (/cgi-bin/luci/) LuCI 19.07 не передаёт PATH_INFO, и
 * L.env.pathinfo отсутствует; роутер темы тогда отключается целиком. */
[ window.L, L ].forEach(function(l) {
	if (l && l.env && l.env.pathinfo == null)
		l.env.pathinfo = '';
});

if (typeof ui.RangeSlider !== 'function') {
	ui.RangeSlider = ui.AbstractElement.extend({
		__init__: function(value, options) {
			this.value = value;
			this.options = Object.assign({ min: 0, max: 100, step: 1 }, options);
		},

		render: function() {
			var input = E('input', {
				'type': 'range',
				'id': this.options.id,
				'name': this.options.name,
				'min': this.options.min,
				'max': this.options.max,
				'step': this.options.step,
				'value': this.value,
				'disabled': this.options.disabled ? '' : null
			});

			var out = E('span', { 'class': 'cbi-range-slider-value' }, [ String(this.value) ]);

			var frame = E('div', { 'class': 'cbi-range-slider' }, [ input, out ]);

			input.addEventListener('input', function() {
				out.textContent = input.value;
			});

			this.node = frame;
			this.input = input;
			this.setUpdateEvents(input, 'input', 'blur');
			this.setChangeEvents(input, 'change');

			dom.bindClassInstance(frame, this);

			return frame;
		},

		getValue: function() {
			return this.input ? this.input.value : String(this.value);
		},

		setValue: function(value) {
			this.value = value;
			if (this.input) {
				this.input.value = value;
				this.input.nextElementSibling.textContent = String(value);
			}
		}
	});
}

if (typeof ui.Table !== 'function') {
	/* Достаточно для update(): строки заменяются целиком, как в апстриме */
	ui.Table = ui.AbstractElement.extend({
		__init__: function(captions, options, placeholder) {
			this.captions = captions || [];
			this.options = options || {};
			this.placeholder = placeholder;
		},

		render: function() {
			var head = E('tr', { 'class': 'tr table-titles' }, this.captions.map(function(c) {
				return E('th', { 'class': 'th' }, [ c ]);
			}));

			this.node = E('table', { 'class': 'table', 'id': this.options.id }, [ head ]);

			if (this.placeholder)
				this.node.appendChild(E('tr', { 'class': 'tr placeholder' }, [
					E('td', { 'class': 'td' }, [ this.placeholder ])
				]));

			dom.bindClassInstance(this.node, this);
			return this.node;
		},

		update: function(data, placeholder) {
			cbi_update_table(this.node, data, placeholder || this.placeholder);
		}
	});
}

if (window.L && typeof window.L.itemlist !== 'function') {
	/* Как LuCI.itemlist в 21.02+: пары «подпись, значение» через разделитель */
	window.L.itemlist = function(node, items, separators) {
		var children = [];

		if (!Array.isArray(separators))
			separators = [ separators || E('br') ];

		for (var i = 0; i < items.length; i += 2) {
			if (items[i + 1] !== null && items[i + 1] !== undefined) {
				var sep = separators[(i / 2) % separators.length],
				    cld = [];

				children.push(E('span', { class: 'nowrap' }, [
					items[i] ? E('strong', items[i] + ': ') : '',
					items[i + 1]
				]));

				if ((i + 2) < items.length) {
					sep = (typeof sep === 'string') ? E('span', {}, sep) : sep;
					children.push(dom.elem(sep) ? sep.cloneNode(true) : sep);
				}
			}
		}

		dom.content(node, children);
		return node;
	};
}

return baseclass.extend({});
