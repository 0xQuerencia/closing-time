"""Deterministic, original pixel textures; no reference-image pixels are used."""
from pathlib import Path
import math
import random
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[2] / 'assets/materials/opening'
rng = random.Random(92124)
font = ImageFont.load_default()
pal = [(72,43,29),(112,71,43),(72,77,82),(154,139,118),(70,69,63),(141,113,83),
       (23,33,57),(165,152,114),(51,66,85),(133,107,55),(32,45,52),(177,157,107),
       (84,58,41),(86,96,98),(161,119,67),(158,139,111)]
def mix(base, bump):
    return tuple(min(255,max(0,round(i+bump))) for i in base)
def plane(w,h,size):
    im=Image.new('RGB',(w,w))
    px=im.load()
    for y in range(w):
        for x in range(w):
            s=(math.sin(x*.16+y*.09) + math.sin(x*.071-y*.14))*size
            px[x,y]=mix(h,s+rng.randint(-4,4))
    return im
def tile(n,base):
    im=plane(64,base,3);d=ImageDraw.Draw(im)
    if n in (0,1,12):
        for y in range(64):
            a=rng.randint(8,25)
            d.line((a,y,min(63,a+rng.randint(16,48)),y),fill=mix(base,rng.choice([-11,-3,7])))
        for x,y in [(26,16),(4,51),(54,36)]:
            d.line((x,y,x+8,y),fill=mix(base,18))
    if n in (2,3):
        if n==2:
            for x in range(64):
                for y in range(64):
                    plaid=((x%18<4)+(y%18<4))*12+((x%18 in (8,9))+(y%18 in (8,9)))*13
                    c=(83,74,61) if (x//18+y//18)%3==0 else base
                    if x%18==2 or y%18==2: c=(121,95,76)
                    im.putpixel((x,y),mix(c,plaid+rng.randint(-7,7)))
        else:
            for y in range(0,64,2):d.line((0,y,63,y),fill=mix(base,-5))
    if n==5:
        for y in range(4,64,10):
            for x in range(3+((y//10)%2)*4,64,8):
                d.line((x-2,y+3,x+1,y-1),fill=(93,88,56))
                d.rectangle((x-1,y-1,x+1,y+1),fill=rng.choice([(117,72,56),(155,119,94),(94,78,64)]))
                d.point((x,y),fill=(187,148,113))
    if n==6:
        for y in range(64):
            for x in range(64):
                im.putpixel((x,y),mix(base,.21*y+rng.choice((-3,-1,0,2))))
        for x,bottom,height in [(7,63,29),(20,63,18),(37,63,41),(48,63,30),(57,63,48)]:
            for j in range(5):
                top=bottom-height+j*height*.12
                d.polygon([(x,top),(x-3-j,top+height*.40),(x+4+j,top+height*.40)],fill=(17,25,39))
        d.rectangle((41,40,53,54),fill=(40,38,41))
        for x in (45,50):d.rectangle((x,44,x+1,46),fill=(180,130,74))
    if n in (7,11):
        d.rectangle((5,6,57,57),outline=mix(base,-24))
        d.line((11,14,50,14),fill=mix(base,-67),width=2)
        for y in range(20,52,4):
            d.line((11,y,rng.randint(32,52),y),fill=mix(base,-47))
    if n==8:
        for y in range(1,64,3):d.line((0,y,63,y),fill=mix(base,-4))
        d.line((5,0,5,63),fill=mix(base,20))
        d.rectangle((36,19,55,24),fill=(137,132,112));d.rectangle((40,21,52,22),fill=(65,64,59))
    if n==10:
        d.rectangle((9,5,55,43),fill=(104,126,118),outline=(29,35,33),width=3)
        d.text((14,17),'DINA',font=font,fill=(27,57,52))
        for x in (13,30,46):d.rectangle((x,47,x+7,53),fill=(106,115,109))
    if n==13:
        d.rectangle((2,2,61,61),fill=(135,118,88));d.rectangle((5,6,58,56),fill=(101,116,127))
        d.polygon([(5,40),(20,28),(36,36),(48,23),(58,39),(58,56),(5,56)],fill=(62,74,64))
        d.line((6,50,58,44),fill=(158,143,106),width=2)
    return im

atlas=Image.new('RGB',(256,256))
for i,c in enumerate(pal):
    atlas.paste(tile(i,c),(i%4*64,i//4*64))
atlas.save(OUT/'apartment_night_atlas.png')
plaster=plane(128,(136,118,103),5)
d=ImageDraw.Draw(plaster)
for _ in range(78):
    x,y=rng.randrange(128),rng.randrange(128);d.point((x,y),fill=rng.choice([(106,92,81),(119,104,94),(153,133,112)]))
plaster.save(OUT/'apartment_night_plaster.png')
carpet=plane(128,(75,66,59),4)
d=ImageDraw.Draw(carpet)
for y in range(0,128,2):
    for x in range(y%3,128,3):
        d.point((x,y),fill=mix((82,72,65),rng.randint(-16,12)))
carpet.save(OUT/'apartment_night_carpet.png')
rug=plane(128,(118,89,64),3);d=ImageDraw.Draw(rug)
for off,c in [(4,(70,49,38)),(7,(149,113,73)),(10,(97,72,52)),(14,(160,123,85))]:
    d.rectangle((off,off,127-off,127-off),outline=c,width=2)
for y in range(21,114,13):
    for x in range(19,114,13):
        d.polygon([(x-3,y),(x,y-3),(x+3,y),(x,y+3)],outline=(144,108,73))
rug.save(OUT/'apartment_night_rug.png')
