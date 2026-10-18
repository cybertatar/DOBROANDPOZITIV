"""Рисует иконку приложения из фото.

    pip install "rembg[cpu]" pillow
    python tools/make_icons.py фото.png

Пишет Resources/AppIcon.png (1024×1024). Значок в строке меню рисует само приложение.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter
from rembg import new_session, remove

OUT = Path(__file__).resolve().parent.parent / "Resources"


def cut_out(path):
    photo = Image.open(path).convert("RGB")
    person = remove(photo, session=new_session("isnet-general-use"))
    return person.crop(person.getbbox())


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        draw.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def equals(draw, cx, cy, width, bar, gap, fill, radius):
    for dy in (-(gap / 2 + bar), gap / 2):
        draw.rounded_rectangle([cx - width / 2, cy + dy, cx + width / 2, cy + dy + bar], radius, fill=fill)


def app_icon(person):
    # Сетка иконок macOS: «сквиркл» 824×824 с полями 100px и тенью.
    size, body, inset = 1024, 824, 100
    tile = gradient((body, body), (255, 214, 92), (255, 120, 64)).convert("RGBA")

    scale = 0.96 * body / person.height
    p = person.resize((round(person.width * scale), round(person.height * scale)), Image.LANCZOS)
    x, y = (body - p.width) // 2, body - p.height + 40
    shadow = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    shadow.paste((90, 30, 0, 110), (x, y + 10), p.getchannel("A"))
    tile.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    tile.alpha_composite(p, (x, y))

    # Знаки «=» по бокам от головы: человек сам стоит в =…=.
    draw = ImageDraw.Draw(tile)
    for cx in (body * 0.15, body * 0.85):
        equals(draw, cx, body * 0.2, 150, 34, 30, (255, 255, 255), 10)

    mask = Image.new("L", (body, body), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, body - 1, body - 1], 185, fill=255)
    tile.putalpha(mask)

    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    drop = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    drop.paste((0, 0, 0, 90), (inset, inset + 12), mask)
    icon.alpha_composite(drop.filter(ImageFilter.GaussianBlur(18)))
    icon.alpha_composite(tile, (inset, inset))
    icon.save(OUT / "AppIcon.png")


if __name__ == "__main__":
    person = cut_out(sys.argv[1])
    app_icon(person)
