"""Рисует фон окна установщика (.dmg): заголовок, стрелка от приложения к Applications.

    python tools/make_dmg_background.py

Пишет Resources/dmg-background.png (640×400) и @2x. Раскладка иконок — в dmg.py,
координаты здесь должны с ней совпадать.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "Resources"
FONTS = "/usr/share/fonts/opentype/inter"
W, H = 640, 400
APP_X, FOLDER_X, ICON_Y = 160, 480, 200
INK, ACCENT = (74, 42, 16), (255, 120, 64)


def draw(scale):
    s = lambda v: round(v * scale)
    img = Image.new("RGB", (s(W), s(H)))
    d = ImageDraw.Draw(img)
    top, bottom = (255, 246, 222), (255, 226, 196)
    for y in range(s(H)):
        t = y / (s(H) - 1)
        d.line([(0, y), (s(W), y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

    title = ImageFont.truetype(f"{FONTS}/Inter-ExtraBold.otf", s(30))
    hint = ImageFont.truetype(f"{FONTS}/Inter-Medium.otf", s(15))
    d.text((s(W / 2), s(62)), "=Добро и позитив=", font=title, fill=INK, anchor="mm")
    d.text((s(W / 2), s(352)), "Перетащи значок в папку Applications", font=hint, fill=INK, anchor="mm")

    # Стрелка между иконками (иконки 128pt, подписи под ними рисует Finder).
    x0, x1, y, w = APP_X + 84, FOLDER_X - 84, ICON_Y, 8
    d.rounded_rectangle([s(x0), s(y - w / 2), s(x1 - 18), s(y + w / 2)], s(w / 2), fill=ACCENT)
    d.polygon([(s(x1), s(y)), (s(x1 - 26), s(y - 20)), (s(x1 - 26), s(y + 20))], fill=ACCENT)

    img.save(OUT / ("dmg-background@2x.png" if scale == 2 else "dmg-background.png"))


if __name__ == "__main__":
    draw(1)
    draw(2)
