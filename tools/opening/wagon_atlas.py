"""Paint the original wagon's 512 px material atlas."""

from math import cos, radians, sin
from random import Random

from PIL import Image, ImageDraw, ImageFont

SIZE = 512
PALETTES = {
    "paint": (153, 133, 99), "edge": (173, 153, 114), "sill": (117, 103, 82),
    "rubber": (48, 47, 44), "trim": (63, 66, 65), "alloy": (143, 141, 126),
    "glass": (51, 69, 75), "head": (211, 197, 152), "tail": (133, 48, 40),
    "amber": (179, 110, 50), "plate": (163, 153, 113), "vinyl": (90, 82, 67),
    "fabric": (104, 92, 73), "gauges": (41, 44, 39), "console": (53, 54, 49),
    "grille": (69, 71, 66),
}
REGIONS = {key: (i % 4 * 128 + 3, i // 4 * 128 + 3, 122, 122) for i, key in enumerate(PALETTES)}


def _cluster(draw):
    marking = (197, 181, 122)
    font = ImageFont.load_default(size=10)
    for x, numbers in [(38, ("0", "15", "30", "45", "60")), (94, ("E", "F"))]:
        y = 66
        r = 31 if x == 38 else 17
        draw.ellipse((x-r,y-r,x+r,y+r), fill=(31,35,32), outline=(93,92,74), width=2)
        for tick in range(0, 11 if x == 38 else 7):
            a = radians(146 + tick * (24 if x == 38 else 40))
            draw.line((x+(r-8)*cos(a),y+(r-8)*sin(a),x+(r-3)*cos(a),y+(r-3)*sin(a)),
                      fill=marking, width=2)
        for i, value in enumerate(numbers):
            a = radians(149+i*60) if x == 38 else radians(145+i*240)
            draw.text((x+(r-14)*cos(a),y+(r-14)*sin(a)), value, fill=marking, font=font, anchor="mm")
        if x != 38:
            draw.line((x,y,x+7,y-7),fill=(182,84,44),width=2)
    draw.text((18,104),"MPH",fill=marking,font=font)
    draw.rectangle((75,100,112,115),fill=(27,36,32),outline=(94,87,58))
    draw.text((78,101),"147286",fill=(148,152,117),font=ImageFont.load_default(size=8))
    draw.line((19,22,113,22),fill=(69,70,58),width=2)


def build_atlas():
    rng = Random(901147)
    atlas = Image.new("RGB", (SIZE, SIZE))
    for i, (key, color) in enumerate(PALETTES.items()):
        tile = Image.new("RGB", (128, 128))
        low = Image.new("L", (9, 9))
        low.putdata([rng.randrange(256) for _ in range(81)])
        macro = low.resize((128,128), Image.Resampling.BICUBIC)
        tile.putdata([
            tuple(max(0,min(255,channel+((value-128)//16)+p)) for channel in color)
            for value, p in zip(macro.tobytes(), (rng.randint(-4,4) for _ in range(128*128)))
        ])
        d = ImageDraw.Draw(tile)
        if key in ("paint", "edge", "sill"):
            for _ in range(90):
                x,y = rng.randrange(128),rng.randrange(128)
                if key == "sill" or y > 83:
                    d.line((x,y,x+1,y+rng.randint(0,9)),fill=(102,84,63))
                elif rng.random() < .25:
                    d.line((x,y,x+rng.randint(2,14),y),fill=(183,167,128))
            for x,y in [(38,94),(89,111),(17,53)]:
                d.line((x,y,x+6,y+1),fill=(71,62,52))
                d.point((x,y+2),fill=(198,178,137))
        if key in ("vinyl", "fabric", "rubber", "grille"):
            for y in range(5,128,4 if key != "grille" else 13):
                d.line((0,y,127,y),fill=tuple(ch-10 for ch in color),width=1 if key != "grille" else 5)
            if key == "fabric":
                for x in range(0,128,8):
                    d.line((x,0,x,127),fill=(116,104,82))
            if key == "rubber":
                for x in range(4,128,18):
                    d.line((x,0,x+24,128),fill=(37,37,35),width=3)
        if key == "glass":
            for y in range(128):
                tint = (52-(y//8),75-(y//6),85-(y//5))
                d.line((0,y,127,y),fill=tint)
            for _ in range(78):
                x,y = rng.randrange(128),rng.randrange(128)
                d.line((x,y,x-1,y+2),fill=rng.choice([(65,78,79),(77,87,84),(54,66,69)]))
        if key in ("head", "tail", "amber"):
            for x in range(5,128,8):
                d.line((x,0,x,127),fill=tuple(ch-22 for ch in color),width=2)
            for y in (16,110):
                d.line((0,y,127,y),fill=tuple(min(ch+17,255) for ch in color),width=3)
        if key == "plate":
            d.rounded_rectangle((7,10,120,118),radius=7,fill=(190,178,132),outline=(94,83,58),width=4)
            d.text((33,20),"BELLWICK",fill=(73,75,64),font=ImageFont.load_default(size=12))
            d.text((17,47),"KX 4091",fill=(57,59,50),font=ImageFont.load_default(size=24))
            d.line((29,91,99,91),fill=(118,104,72),width=4)
        if key == "gauges":
            _cluster(d)
        if key == "console":
            for y in range(12,51,10):
                d.line((8,y,120,y),fill=(29,33,32),width=4)
            d.rectangle((18,63,111,84),fill=(27,35,31),outline=(77,76,57))
            d.text((41,65),"87.9 FM",fill=(162,155,100),font=ImageFont.load_default(size=13))
            for x in (23,50,76,103):
                d.ellipse((x-7,98,x+7,113),fill=(37,40,35),outline=(83,81,68),width=2)
        atlas.paste(tile, (i % 4 * 128, i // 4 * 128))
    return atlas
