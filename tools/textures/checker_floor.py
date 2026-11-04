"""Teal/grey checkered store floor. Replaces only the tile albedo and normal maps (Pillow + numpy)."""
from PIL import Image, ImageFilter
from pathlib import Path
import numpy as np
ROOT = Path(__file__).resolve().parents[2]
SIZE, CELL, GROUT = 1024, 128, 4
rng = np.random.default_rng(12)
yy, xx = np.mgrid[0:SIZE, 0:SIZE]
check = ((xx // CELL) + (yy // CELL)) % 2
dark = np.array([86, 108, 104], float)
light = np.array([150, 152, 142], float)
img = np.where(check[..., None] == 1, dark, light)
# per-tile tone drift, broad stains, fine grain
tile_tone = rng.normal(0, 5, (SIZE // CELL, SIZE // CELL))
img += np.kron(tile_tone, np.ones((CELL, CELL)))[..., None]
stain = np.asarray(Image.fromarray(rng.integers(0, 255, (64, 64), dtype=np.uint8)).resize((SIZE, SIZE), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(14)), float)
img *= (0.86 + 0.2 * (stain / 255.0))[..., None]
img += rng.normal(0, 3.2, (SIZE, SIZE, 1))
grout = ((xx % CELL) < GROUT) | ((yy % CELL) < GROUT)
img[grout] = (60, 62, 56)
scuffs = rng.integers(0, SIZE, (160, 2))
for x, y in scuffs:
    img[y, x:x + int(rng.integers(4, 18))] *= 0.8
out = np.clip(img, 0, 255).astype(np.uint8)
alpha = np.full((SIZE, SIZE, 1), 255, np.uint8)
albedo = Image.fromarray(np.concatenate([out, alpha], axis=2), "RGBA")
# normal map from a height field with sunken grout
height = np.where(grout, 0.0, 1.0)
height = np.asarray(Image.fromarray((height * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.1)), float) / 255.0
gx = np.roll(height, -1, 1) - np.roll(height, 1, 1)
gy = np.roll(height, -1, 0) - np.roll(height, 1, 0)
n = np.stack([-gx * 2.0, -gy * 2.0, np.ones_like(gx)], axis=2)
n /= np.linalg.norm(n, axis=2, keepdims=True)
normal = Image.fromarray(np.concatenate([((n * 0.5 + 0.5) * 255).astype(np.uint8), alpha], axis=2), "RGBA")
for folder, prefix in [("assets/models", "shell_"), ("assets/materials", "")]:
    albedo.save(ROOT / folder / f"{prefix}tile.png")
    normal.save(ROOT / folder / f"{prefix}tile_normal.png")
print("checker floor written")
