"""Paint repeating wet asphalt and aggregate for the opening road and parking lot."""
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "assets/materials/opening"
SIZE = 256


def asphalt(rng):
    road = Image.new("RGB", (SIZE, SIZE))
    values = []
    for y in range(SIZE):
        for x in range(SIZE):
            pore = rng.choices([-9, -3, 0, 8, 17], [5, 27, 55, 11, 2])[0]
            mottled = (x // 7 ^ y // 9) % 7 - 3
            values.append((59+pore+mottled, 63+pore+mottled, 65+pore+mottled))
    road.putdata(values)
    d = ImageDraw.Draw(road)
    for _ in range(26):
        x,y = rng.randrange(SIZE),rng.randrange(SIZE)
        d.line((x,y,x+rng.randrange(1,5),y+rng.randrange(2,11)),fill=(72,74,73))
    for points in [
        [(13,221),(39,211),(52,215),(72,203),(89,199),(101,186)],
        [(183,9),(179,17),(184,24),(172,39),(175,53),(161,64)],
    ]:
        d.line(points,fill=(45,48,50),width=1)
    return road


def aggregate(rng):
    gravel = Image.new("RGB", (SIZE, SIZE))
    gravel.putdata([
        (112+v,111+v,97+v)
        for v in (rng.randrange(-24,17) for _ in range(SIZE*SIZE))
    ])
    d = ImageDraw.Draw(gravel)
    for _ in range(850):
        x,y = rng.randrange(SIZE),rng.randrange(SIZE)
        shade = rng.randrange(76,148)
        d.rectangle((x,y,x+rng.randrange(1,4),y+rng.randrange(1,3)),fill=(shade,shade-2,shade-11))
    for _ in range(190):
        x,y = rng.randrange(SIZE),rng.randrange(SIZE)
        d.line((x,y,x+rng.randrange(-2,3),y+3),fill=(83,87,72))
    return gravel


if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    asphalt(Random(9153)).save(OUT / "route9_asphalt.png")
    aggregate(Random(417)).save(OUT / "route9_aggregate.png")
