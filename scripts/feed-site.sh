#!/bin/bash
#
# Главная страница сайта фида (GitHub Pages): список релизов и инструкция.
#   scripts/feed-site.sh <каталог сайта> <актуальный тег> <owner/repo>
#
set -euo pipefail

SITE="${1:?каталог}"
TAG="${2:?тег}"
REPO="${3:?owner/repo}"
OWNER="${REPO%%/*}"
URL="https://$(echo "$OWNER" | tr 'A-Z' 'a-z').github.io/${REPO#*/}"

releases="$(cd "$SITE/releases" && ls -1 | sort -rV)"
touch "$SITE/.nojekyll"

{
	cat <<EOF
<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AX50 OpenWrt — фид пакетов</title>
<style>
:root { --bg:#fff; --fg:#1d232a; --muted:#5b6672; --line:#d9dee3; --code:#f3f5f7; --link:#0b63c5; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#14181d; --fg:#e6e9ec; --muted:#9aa5b1; --line:#2b323a; --code:#1d232a; --link:#6cb0ff; }
}
body { margin:0; background:var(--bg); color:var(--fg); font:16px/1.55 system-ui,sans-serif; }
main { max-width:760px; margin:0 auto; padding:32px 16px; }
h1 { font-size:1.6rem; margin:0 0 4px; }
p.lead { color:var(--muted); margin-top:0; }
a { color:var(--link); }
pre { background:var(--code); border:1px solid var(--line); border-radius:6px; padding:12px; overflow-x:auto; }
ul.rel { list-style:none; padding:0; }
ul.rel li { padding:8px 0; border-bottom:1px solid var(--line); }
</style>
</head>
<body>
<main>
<h1>AX50 OpenWrt — фид пакетов</h1>
<p class="lead">opkg-репозиторий прошивки для TP-Link Archer AX50 v1 (<a href="https://github.com/$REPO">исходники</a>).</p>

<p>Фид уже прописан в прошивке, достаточно:</p>
<pre>opkg update
opkg install luci-app-openvpn luci-i18n-openvpn-ru</pre>

<p>Модули ядра привязаны к сборке, поэтому у каждого релиза прошивки свой фид:</p>
<ul class="rel">
EOF
	for r in $releases; do
		mark=""
		[ "$r" = "$TAG" ] && mark=" — актуальный"
		echo "<li><a href=\"releases/$r/\">$r</a>$mark</li>"
	done
	cat <<EOF
</ul>
<p>Ручная настройка (<code>/etc/opkg/distfeeds.conf</code>, релиз $TAG):</p>
<pre>$(for d in $(cd "$SITE/releases/$TAG" && find . -name Packages.gz -printf '%h\n' | sort); do
	n="$(basename "$d")"; [ "$n" = packages ] && n=core
	echo "src/gz ax50_$n $URL/releases/$TAG/${d#./}"
done)</pre>
</main>
</body>
</html>
EOF
} > "$SITE/index.html"

# Простые листинги каталогов: Pages не показывает содержимое папок
find "$SITE/releases" -type d | while read -r d; do
	[ -f "$d/index.html" ] && continue
	{
		echo "<!doctype html><meta charset=utf-8><title>${d#"$SITE"/}</title><pre>"
		echo "<a href=\"../\">../</a>"
		(cd "$d" && ls -1p) | while read -r e; do
			echo "<a href=\"$e\">$e</a>"
		done
		echo "</pre>"
	} > "$d/index.html"
done
