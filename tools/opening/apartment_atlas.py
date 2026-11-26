"""Paint the apartment source textures. Run with python tools/opening/apartment_atlas.py."""
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/materials/opening"
RNG = Random(20061124)
FONT = ImageFont.load_default()


def rgb(color, value):
    return tuple(max(0, min(255, channel + value)) for channel in color)


def grain(size, color, grain_amount, cloud_amount):
    large = Image.new("L", (8, 8))
    large.putdata([RNG.randrange(256) for _ in range(64)])
    cloud = large.resize((size, size), Image.Resampling.BICUBIC).tobytes()
    image = Image.new("RGB", (size, size))
    image.putdata([
        rgb(color, int((value - 127) * cloud_amount / 127) + RNG.randint(-grain_amount, grain_amount))
        for value in cloud
    ])
    return image


def streaks(image, color, count, lengths):
    d = ImageDraw.Draw(image)
    width, height = image.size
    for _ in range(count):
        x, y = RNG.randrange(width), RNG.randrange(height)
        d.line((x, y, x + RNG.randint(*lengths), y), fill=rgb(color, RNG.randint(-17, 15)))


def floorboards():
    image = Image.new("RGB", (256, 256))
    for row in range(8):
        color = rgb((118, 84, 58), RNG.randint(-13, 13))
        board = grain(256, color, 3, 10).crop((0, 0, 256, 32))
        streaks(board, color, 200, (2, 50))
        d = ImageDraw.Draw(board)
        split = 14 + (row * 73) % 218
        d.line((split, 0, split, 31), fill=(71, 51, 39))
        d.line((0, 0, 255, 0), fill=(58, 43, 34))
        d.line((0, 1, 255, 1), fill=rgb(color, 17))
        for x in range(6):
            px, py = (split + 2 + (x % 2) * 250) % 256, 5 + x // 2 * 10
            d.point((px, py), fill=(58, 45, 36))
        image.paste(board, (0, row * 32))
    return image


def plaster():
    image = grain(256, (155, 148, 127), 3, 7)
    d = ImageDraw.Draw(image)
    for _ in range(90):
        x, y = RNG.randrange(256), RNG.randrange(256)
        d.line((x, y, x + RNG.randrange(1, 5), y - 1), fill=(143, 136, 117))
    return image


def sign(d, xy, message, color):
    d.text(xy, message, fill=color, font=FONT)


def apartment_atlas():
    colors = [
        (105, 66, 42), (135, 108, 77), (88, 100, 91), (201, 189, 156),
        (64, 66, 59), (158, 143, 109), (76, 90, 93), (188, 180, 153),
        (90, 43, 48), (174, 144, 69), (33, 36, 35), (218, 202, 157),
        (119, 85, 54), (212, 190, 135), (227, 193, 113), (147, 140, 119),
    ]
    cells = [grain(128, color, 4, 8) for color in colors]
    for index in (0, 1, 12):
        streaks(cells[index], colors[index], 300, (5, 67))
    for index in (2, 3, 5, 8, 14):
        d = ImageDraw.Draw(cells[index])
        for y in range(3, 128, 4):
            d.line((0, y, 127, y), fill=rgb(colors[index], -9))
        for x in range(4, 128, 8):
            d.line((x, 0, x, 127), fill=rgb(colors[index], 5))
    d = ImageDraw.Draw(cells[2])
    for x in (8, 11, 110, 114):
        d.line((x, 0, x, 127), fill=(119, 121, 104))
    d = ImageDraw.Draw(cells[6])
    d.rectangle((0, 54, 128, 128), fill=(38, 56, 67))
    for x, height in ((-4, 51), (22, 39), (51, 28), (77, 47), (105, 35)):
        d.rectangle((x, 112-height, x+23, 127), fill=(27, 40, 49))
        d.line((x, 112-height, x+23, 112-height), fill=(67, 82, 87))
        for row in range(2):
            for col in range(3):
                tint = (133, 116, 76) if RNG.random() < .25 else (47, 64, 70)
                left, top = x+4+col*6, 119-height+row*8
                d.rectangle((left, top, left+2, top+3), fill=tint)
    for _ in range(55):
        x, y = RNG.randrange(128), RNG.randrange(128)
        d.line((x, y, x-1, y+RNG.randint(1, 8)), fill=(79, 97, 104))
    d = ImageDraw.Draw(cells[7])
    sign(d, (12, 12), "BELLWICK NEWS", (70, 64, 52))
    d.line((11, 26, 117, 26), fill=(98, 88, 72), width=2)
    sign(d, (12, 31), "DEC 11, 2006", (104, 94, 79))
    d.rectangle((12, 51, 54, 81), fill=(104, 105, 94))
    for y in range(52, 119, 5):
        d.line((62, y, 115, y), fill=(131, 121, 103))
        if y > 83:
            d.line((12, y, 54, y), fill=(131, 121, 103))
    d = ImageDraw.Draw(cells[10])
    d.rectangle((17, 15, 110, 57), fill=(52, 100, 91), outline=(94, 119, 105), width=3)
    sign(d, (30, 28), "1 MESSAGE", (163, 204, 170))
    for y in (73, 89, 105):
        for x in (33, 63, 93):
            d.rounded_rectangle((x-8, y-5, x+8, y+5), radius=3, fill=(76, 82, 77))
    d = ImageDraw.Draw(cells[11])
    d.rectangle((10, 11, 117, 30), fill=(153, 110, 72))
    sign(d, (15, 14), "RENT NOTICE", (249, 229, 190))
    sign(d, (12, 38), "DUE DEC 1", (94, 67, 51))
    for y in (67, 75, 83, 101):
        d.line((12, y, 92 if y != 83 else 70, y), fill=(151, 126, 93), width=2)
    d.line([(62, 107), (69, 96), (76, 109), (84, 98), (94, 103), (107, 91)], fill=(102, 70, 56), width=2)
    d = ImageDraw.Draw(cells[13])
    d.rectangle((9, 9, 118, 108), fill=(121, 137, 129))
    d.polygon([(9, 78), (40, 44), (68, 72), (96, 51), (118, 68), (118, 108), (9, 108)], fill=(63, 91, 78))
    d.rectangle((9, 88, 118, 108), fill=(96, 103, 73))
    for x, shirt in ((53, (138, 79, 63)), (76, (64, 77, 86))):
        d.ellipse((x-6, 56, x+7, 71), fill=(174, 133, 96))
        d.polygon([(x-13, 99), (x-9, 72), (x+8, 71), (x+14, 99)], fill=shirt)
    sign(d, (15, 112), "JUNE  06", (91, 67, 47))
    atlas = Image.new("RGB", (512, 512))
    for i, cell in enumerate(cells):
        atlas.paste(cell, (i % 4 * 128, i // 4 * 128))
    return atlas


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, image in (("apartment_atlas", apartment_atlas()), ("apartment_floor", floorboards()), ("apartment_plaster", plaster())):
        image.save(OUT / f"{name}.png")
