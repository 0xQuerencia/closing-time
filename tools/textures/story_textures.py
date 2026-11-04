"""Story textures: Leon's two outfits (brown jacket / dark plaid overshirt) with a scar, and a wet boot print.
Derived from the Vinrax texture (pixels preserved outside the clothing and the scar). Requires Pillow + numpy."""
from PIL import Image, ImageDraw
from pathlib import Path
import numpy as np
ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'assets/models/characters/vinrax/casual_male_man_tex.png'
OUT = ROOT / 'assets/models/characters/vinrax'

def clothing_mask(a, y0, y1, x0, x1):
    reg = a[y0:y1, x0:x1, :3]
    return ((reg[..., 1] >= reg[..., 0] * 0.98) & (reg[..., 1] > reg[..., 2] * 0.9) & (reg.sum(2) > 45))

def recolor(a, mult, plaid=False):
    out = a.copy()
    for (y0, y1, x0, x1) in [(0, 88, 0, 132), (105, 175, 85, 185)]:
        mask = clothing_mask(a, y0, y1, x0, x1)
        reg = out[y0:y1, x0:x1, :3]
        lum = 0.3 * reg[..., 0] + 0.59 * reg[..., 1] + 0.11 * reg[..., 2]
        tint = np.stack([lum * mult[0], lum * mult[1], lum * mult[2]], axis=2)
        if plaid:
            yy, xx = np.mgrid[y0:y1, x0:x1]
            weave = 1.0 - 0.28 * (((xx // 5) % 2) ^ ((yy // 5) % 2)) - 0.14 * ((xx % 10) < 2) - 0.14 * ((yy % 10) < 2)
            tint *= weave[..., None]
        reg[mask] = np.clip(tint[mask], 0, 255)
        out[y0:y1, x0:x1, :3] = reg
    return out

def add_scar(img):
    d = ImageDraw.Draw(img)
    # Left cheek, running from the cheekbone toward the jaw (face block is top-middle of the atlas).
    d.line([(152, 40), (158, 47), (161, 53)], fill=(168, 118, 104, 255), width=2)
    d.line([(153, 39), (159, 46)], fill=(120, 76, 66, 255), width=1)
    return img

src = np.array(Image.open(SRC).convert('RGBA')).astype(float)
jacket = recolor(src, (0.95, 0.62, 0.34))
shirt = recolor(src, (0.42, 0.5, 0.52), plaid=True)
for name, arr in [('casual_male_leon_jacket', jacket), ('casual_male_leon_overshirt', shirt)]:
    img = Image.fromarray(arr.astype('uint8'), 'RGBA')
    add_scar(img).save(OUT / f'{name}.png')

# Wet boot print: heel + sole with tread bars, soft alpha (RGBA, dark water stain).
size = 128
im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rounded_rectangle((38, 8, 90, 74), radius=22, fill=(18, 22, 26, 215))
d.rounded_rectangle((44, 84, 86, 120), radius=14, fill=(18, 22, 26, 215))
for y in range(16, 70, 9):
    d.line((44, y, 84, y), fill=(0, 0, 0, 0), width=2)
for y in range(90, 116, 8):
    d.line((50, y, 80, y), fill=(0, 0, 0, 0), width=2)
im.save(ROOT / 'assets/textures_boot_print.png')
print('story textures written')
