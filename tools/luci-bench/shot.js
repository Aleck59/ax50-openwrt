// node shot.js <path> <out.png> [dark]
const { chromium } = require('playwright');
(async () => {
  const [path, out, scheme] = process.argv.slice(2);
  const browser = await chromium.launch({ executablePath: process.env.CHROME });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, colorScheme: scheme || 'light' });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(m.type() + ': ' + m.text()); });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  await page.goto('http://127.0.0.1:8080/cgi-bin/luci/');
  if (await page.$('input[name=luci_password]')) {
    await page.fill('input[name=luci_password]', '');
    await Promise.all([page.waitForNavigation(), page.press('input[name=luci_password]', 'Enter')]);
  }
  if (path && path !== '/') await page.goto('http://127.0.0.1:8080/cgi-bin/luci/' + path);
  await page.waitForTimeout(2500);
  await page.screenshot({ path: out, fullPage: false });
  console.log('title:', await page.title());
  console.log(errors.join('\n') || 'no console errors');
  await browser.close();
})();
