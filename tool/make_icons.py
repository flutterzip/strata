#!/usr/bin/env python3
"""Generate Strata's app icon, launch artwork and logo from code.

The mark is the same geometry `StrataMark` paints in
`lib/shared/widgets/strata_mark.dart` — three offset slabs, each a little
more transparent than the one above it. Keep the two in step: if the glyph
changes there, change `mark_polygons` here and re-run.

    python3 tool/make_icons.py

Writes:
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png   (every size listed)
  ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png (blank — see below)
  ios/Runner/Assets.xcassets/LaunchBackground.colorset  (paper, light/dark)
  android/app/src/main/res/mipmap-*/ic_launcher.png
  assets/brand/strata_logo.png, strata_icon.png         (for marketing)

Requires Pillow.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent

# Mirrors lib/config/palette.dart.
PAPER = (0xF4, 0xF3, 0xEE)
PAPER_DARK = (0x12, 0x15, 0x11)
INK = (0x1B, 0x20, 0x19)
INK_DARK = (0xEC, 0xEF, 0xE9)
MOSS = (0x2E, 0x6B, 0x4C)       # CardSkin.moss.base / Brand.leaf
MOSS_SHADE = (0x16, 0x40, 0x2C)  # CardSkin.moss.shade
FOREST_SHADE = (0x0C, 0x18, 0x11)
LEAF_DARK = (0x7F, 0xD3, 0xA4)

SS = 4  # supersampling factor for clean edges


def mark_polygons(x0: float, y0: float, w: float):
    """The three slabs of the mark, fitted to width [w] at (x0, y0)."""
    h = w * 0.72
    slab = h * 0.26
    skew = w * 0.16
    out = []
    for i in range(3):
        top = i * (h - slab) / 2
        dx = 0.0 if i % 2 == 0 else skew
        even = i % 2 == 0
        pts = [
            (dx, top + slab),
            (dx + skew, top),
            (w - (skew if even else 0), top),
            (w - (0 if even else skew), top + slab),
        ]
        alpha = 1 - i * 0.28
        out.append(([(x0 + px, y0 + py) for px, py in pts], alpha))
    return out, h


def draw_mark(img: Image.Image, cx: float, cy: float, w: float, rgb):
    polys, h = mark_polygons(cx - w / 2, cy - (w * 0.72) / 2, w)
    for pts, alpha in polys:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(pts, fill=rgb + (round(255 * alpha),))
        img.alpha_composite(layer)


def diagonal_gradient(size: int, a, b) -> Image.Image:
    """Top-left [a] to bottom-right [b]."""
    grad = Image.new("RGB", (size, size))
    px = grad.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3))
    return grad


def render_icon(size: int = 1024) -> Image.Image:
    big = size * SS // 4  # gradient built small, then upscaled — it is smooth
    base = diagonal_gradient(big, MOSS, FOREST_SHADE).resize(
        (size * SS, size * SS), Image.BICUBIC).convert("RGBA")
    S = size * SS

    # A soft bloom top-right, the same highlight the card faces carry.
    bloom = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    r = S * 0.62
    cx, cy = S * 0.82, S * 0.12
    ImageDraw.Draw(bloom).ellipse(
        (cx - r, cy - r, cx + r, cy + r), fill=LEAF_DARK + (70,))
    bloom = bloom.filter(ImageFilter.GaussianBlur(S * 0.16))
    base.alpha_composite(bloom)

    # Faint sediment bands across the lower half.
    bands = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(bands)
    for i in range(5):
        t = i / 4
        y0 = S * (0.78 + t * 0.24)
        amp = S * 0.03 * (1 - t * 0.5)
        pts = [(x, y0 + math.sin(x / S * math.pi * 2.1 + i * 1.3) * amp)
               for x in range(-S // 10, S + S // 10, S // 60)]
        d.line(pts, fill=(255, 255, 255, round(255 * (0.05 + 0.03 * (1 - t)))),
               width=max(1, round(S * (0.004 + t * 0.004))))
    base.alpha_composite(bands)

    draw_mark(base, S / 2, S / 2, S * 0.54, PAPER)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def render_mark(width: int, rgb) -> Image.Image:
    """Transparent mark only, padded so it sits centred."""
    W = width * SS
    H = round(W * 0.72)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_mark(img, W / 2, H / 2, W, rgb)
    return img.resize((width, round(width * 0.72)), Image.LANCZOS)


def write_ios(icon: Image.Image):
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((appicon / "Contents.json").read_text())
    for entry in contents["images"]:
        name = entry.get("filename")
        if not name:
            continue
        pt = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(pt * scale)
        icon.resize((px, px), Image.LANCZOS).save(appicon / name)

    # The launch screen is plain paper (LaunchBackground): the Flutter
    # splash builds the mark from nothing, so a static copy here would only
    # flash and vanish. The image set stays, blank, because the Flutter
    # template references it.
    launch = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for f in launch.glob("LaunchImageDark*.png"):
        f.unlink()
    for suffix in ("", "@2x", "@3x"):
        Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(
            launch / f"LaunchImage{suffix}.png")
    (launch / "Contents.json").write_text(json.dumps({
        "images": [
            {"idiom": "universal", "filename": f"LaunchImage{sfx}.png",
             "scale": f"{n}x"}
            for n, sfx in ((1, ""), (2, "@2x"), (3, "@3x"))
        ],
        "info": {"version": 1, "author": "xcode"},
    }, indent=2))

    colorset = ROOT / "ios/Runner/Assets.xcassets/LaunchBackground.colorset"
    colorset.mkdir(exist_ok=True)

    def comp(rgb):
        return {"color-space": "srgb", "components": {
            "red": f"{rgb[0] / 255:.3f}", "green": f"{rgb[1] / 255:.3f}",
            "blue": f"{rgb[2] / 255:.3f}", "alpha": "1.000"}}

    (colorset / "Contents.json").write_text(json.dumps({
        "colors": [
            {"idiom": "universal", "color": comp(PAPER)},
            {"idiom": "universal", "color": comp(PAPER_DARK),
             "appearances": [{"appearance": "luminosity", "value": "dark"}]},
        ],
        "info": {"version": 1, "author": "xcode"},
    }, indent=2))


def write_android(icon: Image.Image):
    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in sizes.items():
        out = ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
        # Android launchers mask to their own shape; round the corners so
        # a launcher that does not mask still shows a finished icon.
        small = icon.resize((px, px), Image.LANCZOS).convert("RGBA")
        mask = Image.new("L", (px * SS, px * SS), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, px * SS - 1, px * SS - 1), radius=px * SS * 0.22, fill=255)
        small.putalpha(mask.resize((px, px), Image.LANCZOS))
        small.save(out)


def write_brand(icon: Image.Image):
    brand = ROOT / "assets/brand"
    brand.mkdir(exist_ok=True)
    icon.save(brand / "strata_icon.png")
    render_mark(512, INK).save(brand / "strata_logo.png")
    render_mark(512, INK_DARK).save(brand / "strata_logo_dark.png")


def main():
    icon = render_icon(1024)
    write_ios(icon)
    write_android(icon)
    write_brand(icon)
    print("icons written")


if __name__ == "__main__":
    main()
