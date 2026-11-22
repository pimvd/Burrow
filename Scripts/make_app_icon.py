#!/usr/bin/env python3
"""Draws the Burrow app icon: a hare peeking out of its burrow in a green hill.

Usage: Scripts/make_app_icon.py Burrow/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
Needs Pillow. The output is a 1024x1024 opaque PNG, as App Store Connect requires.
Shapes are kept large and few, so the icon still reads at 40 px.
"""
import sys
from PIL import Image, ImageDraw

S = 4                      # supersampling factor
N = 1024 * S


def u(v): return round(v * S)


def hexrgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


sky_top, sky_bottom = hexrgb("#F7EBD3"), hexrgb("#EED8B2")   # warm cream
hill = hexrgb("#7B9677")                                      # moss
hole = hexrgb("#3A2C24")
fur = hexrgb("#FFFDF7")
inner_ear = hexrgb("#E8A8A0")
eye = hexrgb("#2F2620")

img = Image.new("RGB", (N, N))
d = ImageDraw.Draw(img)
for y in range(N):
    t = y / N
    d.line([(0, y), (N, y)], fill=tuple(round(sky_top[i] + (sky_bottom[i] - sky_top[i]) * t) for i in range(3)))

# The hill, and the burrow's opening in it.
d.ellipse([u(-220), u(580), u(1244), u(1520)], fill=hill)
d.ellipse([u(300), u(690), u(724), u(860)], fill=hole)


def ear(x, tilt):
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle([u(x), u(230), u(x + 96), u(640)], radius=u(48), fill=fur + (255,))
    ld.rounded_rectangle([u(x + 28), u(285), u(x + 68), u(590)], radius=u(20), fill=inner_ear + (255,))
    layer = layer.rotate(tilt, center=(u(x + 48), u(640)), resample=Image.BICUBIC)
    img.paste(layer, mask=layer)


ear(370, 6)
ear(558, -8)
d = ImageDraw.Draw(img)

# The head, peeking: its lower half stays in the burrow.
d.ellipse([u(322), u(500), u(702), u(860)], fill=fur)

# Eyes with a highlight, and a small nose.
for x in (424, 554):
    d.ellipse([u(x), u(605), u(x + 50), u(663)], fill=eye)
    d.ellipse([u(x + 13), u(615), u(x + 29), u(631)], fill=fur)
d.ellipse([u(492), u(676), u(532), u(704)], fill=inner_ear)

# The front of the hill, covering the bottom of the head and the burrow.
d.ellipse([u(-260), u(775), u(1284), u(1720)], fill=hill)

img = img.resize((1024, 1024), Image.LANCZOS)
img.save(sys.argv[1], optimize=True)
