#!/usr/bin/env python3
"""Génère l'icône Resolio (cible jaune sur fond sombre) et l'écran de démarrage Android.

Usage : python3 scripts/generate-icons.py   (nécessite Pillow : pip install pillow)
"""
import glob
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
BG = (13, 13, 15, 255)
YELLOW = (245, 197, 24, 255)
RINGS = [(1.0, YELLOW), (0.80, BG), (0.62, YELLOW), (0.42, BG), (0.24, YELLOW)]


def draw_target(d, cx, cy, radius):
    for f, color in RINGS:
        r = radius * f
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


def render(size, shape, target_ratio, transparent=False):
    s = size * 4  # supersampling pour des bords nets
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0) if transparent else BG)
    d = ImageDraw.Draw(im)
    if shape == "rounded":
        im = Image.new("RGBA", (s, s), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=BG)
    elif shape == "circle":
        im = Image.new("RGBA", (s, s), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        d.ellipse([0, 0, s - 1, s - 1], fill=BG)
    draw_target(d, s / 2, s / 2, s * target_ratio)
    return im.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(os.path.join(ROOT, "resources"), exist_ok=True)
    render(1024, "square", 0.30).save(os.path.join(ROOT, "resources", "icon.png"))
    for folder in glob.glob(os.path.join(RES, "mipmap-*dpi")):
        for name in ("ic_launcher.png", "ic_launcher_round.png", "ic_launcher_foreground.png"):
            path = os.path.join(folder, name)
            size = Image.open(path).size[0]
            if name == "ic_launcher.png":
                img = render(size, "rounded", 0.34)
            elif name == "ic_launcher_round.png":
                img = render(size, "circle", 0.32)
            else:  # premier plan de l'icône adaptative (zone sûre = 66/108)
                img = render(size, "none", 0.25, transparent=True)
            img.save(path)
    for path in glob.glob(os.path.join(RES, "drawable*", "splash.png")):
        w, h = Image.open(path).size
        im = Image.new("RGBA", (w, h), BG)
        t = min(w, h) // 4
        im.alpha_composite(render(t, "none", 0.5, transparent=True), ((w - t) // 2, (h - t) // 2))
        im.convert("RGB").save(path)
    print("Icônes et écrans de démarrage générés.")


if __name__ == "__main__":
    main()
