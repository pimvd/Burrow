#!/usr/bin/env python3
"""Draws the Burrow app icon: a burrow in a moss hill under a soft sky.

Usage: Scripts/make_app_icon.py Burrow/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
Needs Pillow. The output is a 1024x1024 opaque PNG, as App Store Connect requires.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 4                      # supersampling factor
N = 1024 * S

def rgb(r, g, b): return (round(r*255), round(g*255), round(b*255))

def lerp(a, b, t): return tuple(round(a[i] + (b[i]-a[i])*t) for i in range(3))

sky_top = rgb(0.62, 0.74, 0.83)
sky_bot = rgb(0.90, 0.89, 0.82)
hill_back = rgb(0.62, 0.72, 0.60)
hill = rgb(0.482, 0.588, 0.475)       # moss
hole_rim = rgb(0.36, 0.30, 0.25)
hole = rgb(0.20, 0.16, 0.14)
glow = rgb(0.749, 0.686, 0.529)       # sand
moon = rgb(0.98, 0.95, 0.84)

img = Image.new("RGB", (N, N))
d = ImageDraw.Draw(img)
for y in range(N):
    d.line([(0, y), (N, y)], fill=lerp(sky_top, sky_bot, y / N))

def u(v): return round(v * S)

# Moon, softly glowing.
halo = Image.new("L", (N, N), 0)
ImageDraw.Draw(halo).ellipse([u(690), u(150), u(870), u(330)], fill=110)
halo = halo.filter(ImageFilter.GaussianBlur(u(40)))
img.paste(Image.new("RGB", (N, N), moon), mask=halo)
d.ellipse([u(735), u(195), u(825), u(285)], fill=moon)

# A lighter hill behind, then the main hill.
d.ellipse([u(-260), u(560), u(700), u(1400)], fill=hill_back)
d.ellipse([u(-180), u(470), u(1204), u(1600)], fill=hill)

# The burrow: a round entrance with a rim, and a warm light far inside.
cx, base = 512, 850
w, h = 380, 250
d.ellipse([u(cx - w/2 - 26), u(base - h - 26), u(cx + w/2 + 26), u(base + h + 26)], fill=hole_rim)
d.ellipse([u(cx - w/2), u(base - h), u(cx + w/2), u(base + h)], fill=hole)
inner = Image.new("L", (N, N), 0)
ImageDraw.Draw(inner).ellipse([u(cx - 90), u(base - 130), u(cx + 90), u(base + 10)], fill=190)
inner = inner.filter(ImageFilter.GaussianBlur(u(45)))
img.paste(Image.new("RGB", (N, N), glow), mask=inner)

# Ground line in front of the entrance, so the hole sits in the hill.
d.ellipse([u(-200), u(base - 10), u(1224), u(base + 900)], fill=hill)

img = img.resize((1024, 1024), Image.LANCZOS)
img.save(sys.argv[1], optimize=True)
