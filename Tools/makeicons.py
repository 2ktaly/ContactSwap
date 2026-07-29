#!/usr/bin/env python3
"""Erzeugt die App-Icons für ContactSwap.

Das Standard-Icon zeigt die Swap-Pfeile, die übrigen sind bewusst unauffällige
Alltagsmotive für den verdeckten Einsatz. Sie ahmen keine bestehende App nach –
das ist Absicht: Ein Klon einer echten App fällt bei genauem Hinsehen eher auf
als ein schlichtes, generisches Symbol.

Aufruf:  python3 Tools/makeicons.py
Ergebnis: ContactSwap/Assets.xcassets/<Name>.appiconset/icon.png (je 1024x1024)
"""

import json
import math
import os

from PIL import Image, ImageDraw

SIZE = 1024
ASSETS = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "ContactSwap", "Assets.xcassets"
)


def canvas(color):
    image = Image.new("RGB", (SIZE, SIZE), color)
    return image, ImageDraw.Draw(image)


def arrow(draw, y, x_start, x_end, color, width=54, head=64):
    """Waagerechter Pfeil mit Spitze am Zielende."""
    draw.line([(x_start, y), (x_end, y)], fill=color, width=width)
    direction = 1 if x_end > x_start else -1
    tip = x_end + direction * head // 2
    draw.polygon(
        [(tip, y),
         (x_end - direction * head // 2, y - head),
         (x_end - direction * head // 2, y + head)],
        fill=color,
    )


def icon_swap():
    """Standard: zwei gegenläufige Pfeile."""
    image, draw = canvas((10, 90, 200))
    arrow(draw, 400, 250, 720, "white")
    arrow(draw, 624, 774, 304, "white")
    return image


def icon_calculator():
    image, draw = canvas((44, 46, 52))
    draw.rounded_rectangle([190, 170, 834, 380], radius=26, fill=(232, 234, 238))
    size, gap = 118, 40
    left, top = 190, 440
    for row in range(3):
        for column in range(4):
            x = left + column * (size + gap)
            y = top + row * (size + gap)
            shade = (240, 148, 40) if column == 3 else (92, 95, 104)
            draw.rounded_rectangle([x, y, x + size, y + size], radius=22, fill=shade)
    return image


def icon_notes():
    image, draw = canvas((246, 241, 226))
    draw.rectangle([0, 0, SIZE, 180], fill=(226, 186, 92))
    for index in range(6):
        y = 320 + index * 108
        draw.line([(150, y), (874, y)], fill=(206, 199, 182), width=14)
    return image


def icon_compass():
    image, draw = canvas((26, 82, 62))
    draw.ellipse([180, 180, 844, 844], outline=(236, 240, 236), width=26)
    centre = SIZE // 2
    angle = math.radians(38)
    dx, dy = math.sin(angle), -math.cos(angle)
    reach, flank = 250, 96
    draw.polygon(
        [(centre + dx * reach, centre + dy * reach),
         (centre + dy * flank, centre - dx * flank),
         (centre - dy * flank, centre + dx * flank)],
        fill=(214, 74, 66),
    )
    draw.polygon(
        [(centre - dx * reach, centre - dy * reach),
         (centre + dy * flank, centre - dx * flank),
         (centre - dy * flank, centre + dx * flank)],
        fill=(236, 240, 236),
    )
    return image


def icon_clock():
    image, draw = canvas((38, 40, 46))
    draw.ellipse([150, 150, 874, 874], fill=(240, 242, 245))
    centre = SIZE // 2
    draw.line([(centre, centre), (centre, 300)], fill=(38, 40, 46), width=34)
    draw.line([(centre, centre), (720, centre)], fill=(38, 40, 46), width=28)
    draw.ellipse([centre - 30, centre - 30, centre + 30, centre + 30], fill=(214, 74, 66))
    return image


ICONS = {
    "AppIcon": icon_swap,
    "IconCalculator": icon_calculator,
    "IconNotes": icon_notes,
    "IconCompass": icon_compass,
    "IconClock": icon_clock,
}

CONTENTS = {
    "images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1},
}

# App-Icon-Sets lassen sich nicht per Image(...) laden – für die Auswahlliste
# in den Einstellungen braucht es dieselben Motive noch einmal als Bild-Asset.
PREVIEW_CONTENTS = {
    "images": [
        {"filename": "preview.png", "idiom": "universal", "scale": "1x"},
        {"idiom": "universal", "scale": "2x"},
        {"idiom": "universal", "scale": "3x"},
    ],
    "info": {"author": "xcode", "version": 1},
}


def main():
    for name, build in ICONS.items():
        image = build()

        folder = os.path.join(ASSETS, f"{name}.appiconset")
        os.makedirs(folder, exist_ok=True)
        image.save(os.path.join(folder, "icon.png"))
        with open(os.path.join(folder, "Contents.json"), "w") as handle:
            json.dump(CONTENTS, handle, indent=2)

        preview = os.path.join(ASSETS, f"{name}Preview.imageset")
        os.makedirs(preview, exist_ok=True)
        image.resize((180, 180), Image.LANCZOS).save(os.path.join(preview, "preview.png"))
        with open(os.path.join(preview, "Contents.json"), "w") as handle:
            json.dump(PREVIEW_CONTENTS, handle, indent=2)

        print(f"{name}.appiconset + {name}Preview.imageset")


if __name__ == "__main__":
    main()
