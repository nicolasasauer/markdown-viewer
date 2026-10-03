// Renders the 512px store icon from tool/icon/icon.svg.
// Usage: node tool/icon/render.js  (needs Playwright)
// The legacy launcher PNGs (res/mipmap-*/ic_launcher.png, API < 26) are kept
// from the original build.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '../..');
const svg = fs.readFileSync(path.join(__dirname, 'icon.svg'), 'utf8');
const file = path.join(root, 'store/icon-512.png');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  // Full-bleed square showing the 18..90 region; the store applies its own mask.
  const data = Buffer.from(svg).toString('base64');
  await page.setViewportSize({ width: 512, height: 512 });
  await page.setContent(`<html><body style="margin:0">
    <div style="width:512px;height:512px;background:url('data:image/svg+xml;base64,${data}') center/150% no-repeat"></div>
    </body></html>`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  await page.screenshot({ path: file });
  console.log('wrote', path.relative(root, file));
  await browser.close();
})();
