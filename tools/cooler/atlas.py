"""Original hand-pixelled lettering and painted surfaces for the Marlow cooler."""
import json
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw

SIZE = 512
GLYPHS = json.loads((Path(__file__).resolve().parents[1] / "fonts/glyphs.json").read_text())
IMAGE = Image.new("RGBA", (SIZE, SIZE), (40, 39, 35, 255))
REGIONS = {}


def shade(color, amount):
    return tuple(max(0, min(255, channel + amount)) for channel in color[:3])


def patch(name, cell, color, grain=7, wear=0, shape=(1, 1), alpha=255):
    """Paint inside a two-pixel atlas gutter, then pad the paint out to its edges."""
    width, height = (64 * n - 4 for n in shape)
    rng = Random(name)
    tile = Image.new("RGBA", (width, height))
    spots = [[rng.randrange(-grain, grain + 1) for _ in range(width // 5 + 1)]
             for _ in range(height // 5 + 1)]
    for y in range(height):
        for x in range(width):
            edge = max(0, 3 - min(x, y, width - x - 1, height - y - 1))
            tone = spots[y // 5][x // 5] + rng.randrange(-grain, grain + 1) - edge * wear
            tile.putpixel((x, y), (*shade(color, tone), alpha))
    origin = (cell[0] * 64 + 2, cell[1] * 64 + 2)
    REGIONS[name] = (*origin, width, height)
    return tile, ImageDraw.Draw(tile), rng


def place(name, tile):
    x, y, w, h = REGIONS[name]
    IMAGE.paste(tile, (x, y))
    for offset in (1, 2):
        IMAGE.paste(tile.crop((0, 0, w, 1)), (x, y - offset))
        IMAGE.paste(tile.crop((0, h - 1, w, h)), (x, y + h - 1 + offset))
        IMAGE.paste(tile.crop((0, 0, 1, h)), (x - offset, y))
        IMAGE.paste(tile.crop((w - 1, 0, w, h)), (x + w - 1 + offset, y))


def text(draw, position, label, ink, scale=1, centered=False):
    x, y = position
    if centered:
        x -= (len(label) * 6 - 1) * scale // 2
    for letter in label:
        for row, bits in enumerate(bytes.fromhex(GLYPHS[letter])):
            for col in range(5):
                if bits & (16 >> col):
                    px, py = x + col * scale, y + row * scale
                    draw.rectangle((px, py, px + scale - 1, py + scale - 1), fill=ink)
        x += scale * 6


def metal(name, cell, color, grain, scratches, edges=True):
    tile, d, rng = patch(name, cell, color, grain, 3)
    for _ in range(scratches):
        x, y = rng.randrange(2, 57), rng.randrange(2, 57)
        length = rng.choice((1, 2, 4, 8))
        d.line((x, y, min(59, x + length), y + rng.choice((0, 0, 1))),
               fill=shade(color, rng.choice((-18, -12, 15, 32))))
    if edges:
        d.line((1, 1, 58, 1), fill=shade(color, 32))
        d.line((2, 2, 2, 57), fill=shade(color, 16))
        d.line((1, 58, 58, 58), fill=shade(color, -25))
    place(name, tile)


def packaging(name, cell, base, ink, words, motif):
    tile, d, rng = patch(name, cell, base, 5)
    cream = (222, 215, 184)
    d.rectangle((0, 4, 59, 6), fill=shade(base, 35))
    d.rectangle((0, 48, 59, 51), fill=ink)
    d.rectangle((0, 52, 59, 54), fill=shade(base, -22))
    if name in ("milk", "coffee"):
        d.rectangle((0, 0, 59, 27), fill=(210, 200, 170))
        d.line((0, 26, 59, 26), fill=ink, width=2)
    elif name in ("cola", "ocean"):
        d.polygon([(0, 49), (42, 13), (59, 6), (59, 33), (25, 49)], fill=ink)
    else:
        d.ellipse((13, 11, 47, 47), fill=shade(base, 16), outline=shade(base, 34))
    if motif == "mountain":
        d.polygon([(3, 38), (19, 29), (26, 32), (36, 24), (54, 40), (54, 46), (3, 46)], fill=ink)
        d.polygon([(29, 30), (36, 24), (43, 31), (38, 30), (36, 33), (34, 29)], fill=cream)
    elif motif == "citrus":
        d.ellipse((23, 27, 37, 43), outline=cream, width=2)
        d.line((30, 29, 30, 41), fill=cream)
        d.line((24, 35, 36, 35), fill=cream)
        d.line((26, 31, 34, 39), fill=cream)
        d.line((26, 39, 34, 31), fill=cream)
    elif motif == "berry":
        d.line((26, 30, 34, 25), fill=(193, 197, 150), width=2)
        for x, y in [(25, 30), (33, 30), (29, 35), (27, 40)]:
            d.ellipse((x, y, x+5, y+5), fill=ink, outline=cream)
    elif motif == "bolt":
        d.polygon([(36, 24), (24, 36), (29, 36), (26, 45), (40, 32), (34, 32)],
                  fill=cream)
    else:
        for offset in (0, 4, 8):
            d.line((11, 44 - offset, 47, 32 - offset), fill=ink, width=2)
    word_ink = ink if name in ("milk", "coffee") else cream
    text(d, (30, 17), words, word_ink, centered=True)
    for _ in range(30):
        x, y = rng.randrange(60), rng.choice((0, 1, 2, 55, 56, 57, 58))
        d.point((x, y), fill=shade(base, rng.choice((-18, 20))))
    place(name, tile)


def build_atlas(output):
    for entry in [
        ("enamel", (0, 0), (67, 70, 70), 5, 80),
        ("rubber", (1, 0), (41, 43, 41), 3, 15),
        ("liner", (2, 0), (119, 132, 128), 6, 28, False),
        ("shelf", (3, 0), (123, 129, 119), 7, 65),
        ("lip", (4, 0), (162, 164, 145), 6, 60),
        ("steel", (5, 0), (146, 148, 133), 6, 105),
        ("shadow", (6, 0), (29, 34, 34), 4, 19, False),
        ("board", (7, 0), (114, 77, 46), 7, 65),
        ("hinge", (7, 1), (112, 112, 98), 5, 45),
        ("diffuser", (6, 1), (230, 239, 216), 3, 6, False),
        ("carton_fold", (0, 5), (180, 180, 154), 5, 16),
        ("can_metal", (7, 4), (164, 166, 151), 6, 32),
        ("panel", (1, 5), (124, 112, 87), 6, 50),
        ("rail", (2, 5), (132, 125, 101), 7, 62),
        ("kick", (3, 5), (71, 64, 50), 5, 30),
        ("plaster", (4, 5), (144, 122, 95), 8, 48, False),
        ("plaster_dark", (5, 5), (127, 102, 78), 8, 56, False),
        ("stripe", (6, 5), (105, 51, 39), 7, 60),
        ("brick", (7, 5), (109, 76, 56), 7, 40),
        ("birch_plastic", (6, 3), (164, 186, 180), 7, 35),
        ("cap", (7, 3), (227, 219, 181), 6, 35),
        ("amber_pet", (6, 6), (153, 97, 43), 8, 42),
        ("cola_pet", (7, 6), (86, 62, 53), 8, 42),
    ]:
        metal(*entry)

    tile, d, rng = patch("vent", (0, 1), (66, 66, 58), 6, 5, (2, 1))
    d.rectangle((4, 5, 119, 54), outline=(116, 109, 94), width=2)
    for x in (7, 66):
        for y in range(10, 51, 8):
            d.rectangle((x, y, x + 50, y + 3), fill=(26, 27, 25))
            d.line((x + 1, y + 4, x + 50, y + 4), fill=(91, 85, 71))
    for _ in range(58):
        x, y = rng.randrange(124), rng.randrange(60)
        d.point((x, y), fill=(100, 87, 65))
    place("vent", tile)

    tile, d, _ = patch("controller", (2, 1), (75, 73, 61), 4)
    d.rectangle((4, 7, 55, 51), fill=(44, 47, 42), outline=(111, 107, 91))
    d.rectangle((8, 17, 39, 42), fill=(25, 36, 27))
    text(d, (11, 23), "36F", (169, 179, 105), 1)
    d.rectangle((45, 20, 49, 24), fill=(134, 157, 88))
    d.rectangle((45, 32, 49, 36), fill=(129, 67, 52))
    place("controller", tile)

    tile, d, _ = patch("perforation", (3, 1), (122, 131, 123), 5, 3)
    for y in range(5, 58, 6):
        for x in range(5, 57, 7):
            d.point((x, y + 1), fill=(159, 163, 148))
            d.line((x, y, x + 1, y), fill=(69, 78, 75))
    place("perforation", tile)

    for idx, key in enumerate(("row_a", "row_b", "row_c")):
        tile, d, _ = patch(key, (4 + idx, 2), (182, 171, 134), 5, 6)
        d.rectangle((4, 4, 55, 55), outline=(97, 89, 62), width=2)
        text(d, (30, 13), "ROW", (48, 55, 44), 2, centered=True)
        text(d, (30, 33), "ABC"[idx], (54, 70, 53), 3, centered=True)
        place(key, tile)
    tile, d, _ = patch("price", (7, 2), (192, 178, 137), 5, 4)
    d.line((1, 8, 58, 8), fill=(120, 48, 37), width=2)
    text(d, (30, 13), "COLD CASE", (69, 60, 43), centered=True)
    text(d, (30, 31), "1.49", (54, 48, 37), 2, centered=True)
    place("price", tile)

    tile, d, rng = patch("glass", (0, 2), (174, 202, 201), 6, 0, (2, 2), 10)
    for x in range(124):
        for y in range(124):
            edge = max(0, 10 - min(x, 123-x)) + max(0, 18 - y)
            reflection = 11 < x + (y // 9) < 21 and 5 < y < 98
            gloss = max(0, 40 - abs(y - 6) * 7) if 19 < x < 106 else 0
            tile.putpixel((x, y), (168, 194, 186, min(69, 8 + edge + gloss + (10 if reflection else 0))))
    for _ in range(98):
        x, y = rng.randrange(3, 120), rng.randrange(3, 121)
        a = rng.randrange(23, 60) if x < 24 or x > 100 or y > 101 else rng.randrange(16, 32)
        d.line((x, y, x, min(122, y + rng.choice((0, 1, 3, 6)))), fill=(171, 201, 196, a))
    place("glass", tile)

    tile, d, rng = patch("card", (2, 2), (212, 195, 151), 5, 2, (2, 2))
    ink = (63, 58, 43)
    d.polygon([(0, 112), (13, 123), (0, 123)], fill=(171, 147, 107))
    d.line((10, 23, 113, 23), fill=(88, 76, 53), width=2)
    text(d, (62, 11), "STOCK COUNT", ink, centered=True)
    text(d, (13, 30), "NOV 24 PM", ink)
    text(d, (13, 42), "BIRCH SPRING", ink)
    for idx, line in enumerate(("ROW A", "ROW B", "ROW C", "TOTAL")):
        y = 55 + 13 * idx
        text(d, (13, y), line, ink)
        d.line((51, y + 8, 105, y + 8), fill=(144, 126, 90))
        d.rectangle((108, y, 113, y + 6), outline=(112, 97, 71))
        if idx < 3:
            d.line((109, y + 3, 111, y + 5, 116, y - 1), fill=(76, 91, 81), width=1)
    text(d, (78, 94), "12", (76, 91, 81))
    text(d, (13, 110), "PM INITIALS", ink)
    d.line((84, 116, 89, 108, 91, 116, 93, 111, 97, 115, 103, 110, 103, 116, 109, 113),
           fill=(76, 91, 81))
    for _ in range(34):
        d.point((rng.randrange(124), rng.choice((0, 1, 122, 123))), fill=(146, 110, 71))
    place("card", tile)

    for args in [
        ("milk", (0, 4), (79, 104, 130), (46, 69, 100), "DAIRY", "mountain"),
        ("coffee", (1, 4), (143, 74, 55), (78, 49, 34), "MOCHA", "stripe"),
        ("lime", (2, 4), (81, 111, 79), (42, 76, 56), "LIME", "citrus"),
        ("cola", (3, 4), (139, 60, 46), (103, 44, 36), "COLA", "stripe"),
        ("grape", (4, 4), (112, 90, 132), (64, 54, 90), "GRAPE", "berry"),
        ("orange", (5, 4), (168, 114, 49), (126, 74, 27), "ORANGE", "citrus"),
        ("ocean", (6, 4), (56, 99, 122), (36, 72, 104), "SURGE", "bolt"),
        ("birch", (5, 3), (49, 111, 85), (35, 81, 59), "BIRCH", "mountain"),
    ]:
        packaging(*args)

    for i, color in enumerate(((161, 139, 105), (151, 127, 99), (126, 78, 61), (119, 69, 57))):
        name = "tile_" + str(i)
        tile, d, rng = patch(name, (i, 6), color, 10, 5)
        for _ in range(130):
            x, y = rng.randrange(2, 58), rng.randrange(2, 58)
            d.line((x, y, x + rng.choice((0, 0, 1, 2)), y), fill=shade(color, rng.choice((-23, -12, 18, 26))))
        d.line((0, 0, 59, 0, 59, 59, 0, 59, 0, 0), fill=(81, 68, 54), width=1)
        d.line((1, 1, 57, 1), fill=shade(color, 19))
        place(name, tile)

    tile, d, _ = patch("aisle_post", (4, 6), (135, 125, 101), 6, 3)
    for y in range(2, 60, 8):
        for x in (13, 39):
            d.rectangle((x, y, x + 5, y + 4), fill=(57, 56, 46))
            d.line((x, y + 5, x + 5, y + 5), fill=(162, 147, 114))
    place("aisle_post", tile)
    tile, d, _ = patch("insulation", (5, 6), (93, 104, 96), 4)
    for x in (7, 27, 47):
        d.line((x, 0, x, 59), fill=(104, 114, 104))
        d.line((x+1, 0, x+1, 59), fill=(72, 83, 79))
    place("insulation", tile)
    for name, cell, label in [("maker", (0, 7), "MARLOW"), ("service", (1, 7), "KEEP CLOSED")]:
        tile, d, _ = patch(name, cell, (94, 96, 84), 4, 5, (2, 1) if name == "service" else (1, 1))
        width = tile.width
        d.rectangle((4, 5, width-5, 54), outline=(143, 142, 119), width=2)
        text(d, (width//2, 22), label, (202, 196, 166), centered=True)
        place(name, tile)
    IMAGE.save(output)
