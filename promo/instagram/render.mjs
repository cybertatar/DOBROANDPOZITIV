// Снимает каждый слайд carousel.html в PNG 1080×1350: node render.mjs
import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';

const dir = fileURLToPath(new URL('.', import.meta.url));
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 1400 } });
await page.goto(`file://${dir}carousel.html`);
await page.evaluate(() => document.fonts.ready);
const slides = await page.$$('.slide');
for (const [i, slide] of slides.entries()) {
  await slide.screenshot({ path: `${dir}slide-${i + 1}.png` });
}
await browser.close();
console.log(`Готово: ${slides.length} слайдов`);
