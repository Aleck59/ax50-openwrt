#!/usr/bin/env python3
"""
Proton2025 для LuCI 19.07 (ax50-openwrt): CSS темы под «таблицы» LuCI 19.07.

LuCI 21.02+ рисует таблицы элементами <table>/<tr>/<td>/<th> с классами
.table/.tr/.td/.th, а LuCI 19.07 — элементами <div> с теми же классами. CSS
Proton адресует элементы (td, th, table.cbi-section-table ...), поэтому в 19.07
таблицы разваливались. Скрипт переписывает только селекторы:

    table -> :is(table,.table)   tr -> :is(tr,.tr)
    td    -> :is(td,.td)         th -> :is(th,.th)

и дописывает в начало базовые display: table* для <div> с нулевой
специфичностью (:where), чтобы любые правила темы их перекрывали.
Свойства, @-правила, @keyframes, строки, [атрибуты] и комментарии не трогаются.

То же для JS (*.js, *.htm): переписываются только строковые аргументы
querySelector/querySelectorAll/closest/matches — скрипты темы ищут строки и
ячейки таблиц по именам элементов.

    divtables.py <файл.css|.js|.htm> [...]   — правит файлы на месте
"""
import re
import sys

ELEMS = ('table', 'tr', 'td', 'th')
TYPE_RE = re.compile(r'(?<![\w\-.#:\[\]"\'\\])(' + '|'.join(ELEMS) + r')(?![\w\-(])')

BASE = """/* ax50-openwrt: таблицы LuCI 19.07 (<div class="table|tr|td|th">) */
:where(.table):not(table) { display: table; width: 100%; }
:where(.tr):not(tr) { display: table-row; }
:where(.td, .th):not(td):not(th) { display: table-cell; vertical-align: middle; }
:where(.th):not(th) { font-weight: 600; }

"""


def transform_selector(sel):
    out, i, n = [], 0, len(sel)
    while i < n:
        c = sel[i]
        if c in '"\'':
            j = sel.index(c, i + 1) + 1 if c in sel[i + 1:] else n
            out.append(sel[i:j]); i = j
        elif c == '[':
            j = sel.find(']', i)
            j = n if j < 0 else j + 1
            out.append(sel[i:j]); i = j
        else:
            j = i
            while j < n and sel[j] not in '"\'[':
                j += 1
            chunk = sel[i:j]
            chunk = TYPE_RE.sub(lambda m: ':is(%s,.%s)' % (m.group(1), m.group(1)), chunk)
            out.append(chunk); i = j
    return ''.join(out)


def transform(css):
    out = []
    i, n = 0, len(css)
    # стек контекстов блоков: 'rules' — внутри правила-контейнера (@media),
    # 'decl' — объявления, 'frames' — @keyframes
    stack = ['rules']
    start = 0
    while i < n:
        c = css[i]
        if css.startswith('/*', i):
            j = css.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in '"\'':
            j = i + 1
            while j < n and css[j] != c:
                j += 2 if css[j] == '\\' else 1
            i = j + 1
            continue
        if c == '{':
            prelude = css[start:i]
            ctx = stack[-1]
            if ctx == 'rules':
                p = prelude.strip()
                if p.startswith('@'):
                    kw = p[1:].split(None, 1)[0].lower() if len(p) > 1 else ''
                    if kw.endswith('keyframes'):
                        stack.append('frames')
                    elif kw in ('media', 'supports', 'layer', 'container', 'document', 'scope'):
                        stack.append('rules')
                    else:
                        stack.append('decl')
                    out.append(prelude)
                else:
                    out.append(transform_selector(prelude))
                    stack.append('decl')
            else:
                out.append(prelude)
                stack.append('decl')
            out.append('{')
            i += 1; start = i
            continue
        if c == '}':
            out.append(css[start:i + 1])
            if len(stack) > 1:
                stack.pop()
            i += 1; start = i
            continue
        if c == ';' and stack[-1] == 'rules':
            # @import/@charset на верхнем уровне
            out.append(css[start:i + 1]); i += 1; start = i
            continue
        i += 1
    out.append(css[start:])
    return ''.join(out)


JS_CALL_RE = re.compile(r'\b(querySelector|querySelectorAll|closest|matches)\(\s*(["\'`])((?:(?!\2).)*)\2')


def transform_js(js):
    return JS_CALL_RE.sub(lambda m: '%s(%s%s%s' % (m.group(1), m.group(2), transform_selector(m.group(3)), m.group(2)), js)


if __name__ == '__main__':
    for path in sys.argv[1:]:
        with open(path, encoding='utf-8') as f:
            css = f.read()
        if path.endswith('.css'):
            res = transform(css)
            if path.endswith('/cascade.css'):
                res = BASE + res
        else:
            res = transform_js(css)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(res)
