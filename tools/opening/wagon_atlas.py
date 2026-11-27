"""Paint the original wagon's 512 px material atlas."""

from math import cos, radians, sin
from random import Random

from PIL import Image, ImageDraw, ImageFont

SIZE = 512
PALETTES = {
    "paint": (153, 133, 99), "edge": (173, 153, 114), "sill": (117, 103, 82),
    "rubber": (48, 47, 44), "trim": (67, 60, 49), "alloy": (143, 141, 126),
    "glass": (51, 69, 75), "head": (211, 197, 152), "tail": (133, 48, 40),
    "amber": (179, 110, 50), "plate": (163, 153, 113), "vinyl": (86, 73, 58),
    "fabric": (99, 79, 58), "gauges": (41, 44, 39), "console": (53, 54, 49),
    "grille": (69, 71, 66),
}
REGIONS = {key: (i % 4 * 128 + 3, i // 4 * 128 + 3, 122, 122) for i, key in enumerate(PALETTES)}


def _cluster(draw):
    marking = (138, 169, 102)
    font = ImageFont.load_default(size=9)
    draw.rectangle((4,4,124,124),fill=(29,32,29))
    for x,y,rx,ry,numbers in [(38,65,21,54,("0", "15", "30", "45", "60")), (97,58,13,35,("E", "F"))]:
        draw.ellipse((x-rx,y-ry,x+rx,y+ry), fill=(23,27,25), outline=(85,83,67), width=1)
        steps = 12 if x == 38 else 6
        for tick in range(steps+1):
            a = radians(149 + tick*240/steps)
            inset = 5 if tick % 3 == 0 else 3
            draw.line((x+(rx-inset)*cos(a),y+(ry-inset*2)*sin(a),x+(rx-2)*cos(a),y+(ry-4)*sin(a)),
                      fill=marking, width=1)
        for i,value in enumerate(numbers):
            a = radians(149+i*240/(len(numbers)-1))
            draw.text((x+(rx-8)*cos(a),y+(ry-20)*sin(a)),value,fill=marking,font=font,anchor="mm")
    draw.text((39,94),"MPH",fill=(137,151,102),font=font,anchor="mm")
    draw.line((97,58,99,36),fill=(162,91,45),width=2)
    draw.rectangle((65,99,109,116),fill=(20,28,25),outline=(83,78,60))
    draw.text((69,102),"147286",fill=(145,147,117),font=font)
    draw.rectangle((65,43,73,48),fill=(56,69,45))
    draw.rectangle((65,57,73,62),fill=(89,51,35))


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
        if key == "vinyl":
            for y in range(2,128,3):
                for x in range(1+(y%5),128,4):
                    v = rng.choice((-7,-3,4,8))
                    d.point((x,y),fill=tuple(ch+v for ch in color))
            for x,y in [(14,18),(80,94),(47,111),(106,52)]:
                d.line((x,y,x+7,y+1),fill=(108,87,64))
        if key in ("fabric", "rubber", "grille"):
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
            d.rectangle((23,22,105,63),fill=(25,35,30),outline=(70,75,62))
            d.text((64,42),"87.9 FM",fill=(150,177,111),font=ImageFont.load_default(size=15),anchor="mm")
            for x in (26,44,62,80,98):
                d.rectangle((x-5,83,x+5,103),fill=(37,40,36),outline=(75,76,67))
        atlas.paste(tile, (i % 4 * 128, i // 4 * 128))
    return atlas
