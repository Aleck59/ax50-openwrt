// Проходит по страницам через меню (SPA-роутер темы), собирает ошибки и скриншоты
const { chromium } = require('playwright');
(async () => {
  const pages = process.argv.slice(2);
  const b = await chromium.launch({ executablePath: process.env.CHROME });
  const p = await b.newPage({ viewport: { width: 1280, height: 900 } });
  const errors = [];
  p.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  p.on('pageerror', e => errors.push('pageerror: ' + e.message));
  await p.goto('http://127.0.0.1:8080/cgi-bin/luci/');
  if (await p.$('input[name=luci_password]')) { await Promise.all([p.waitForNavigation(), p.press('input[name=luci_password]', 'Enter')]); }
  await p.waitForTimeout(1500);
  for (const path of pages) {
    errors.length = 0;
    const a = await p.$(`a[href$="/cgi-bin/luci/${path}"]`);
    let how = 'goto';
    if (a) { how = 'click'; await p.evaluate(el => el.click(), a); } else { await p.goto('http://127.0.0.1:8080/cgi-bin/luci/' + path); }
    await p.waitForTimeout(2500);
    const h2 = await p.evaluate(() => (document.querySelector('#maincontent h2, .fs-content h2') || {}).textContent);
    const shot = '/tmp/nav-' + path.replace(/\//g, '_') + '.png';
    await p.screenshot({ path: shot });
    console.log(`${path} [${how}] h2="${(h2||'').trim()}" url=${p.url().replace(/.*luci/, '')} errors=${errors.filter(e => !/status of 40[03]/.test(e)).join(' | ') || 'none'}`);
  }
  await b.close();
})();
