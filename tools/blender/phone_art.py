"""Original pixel-painted navy candybar texture. Run with Python + Pillow."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import random
ROOT = Path(__file__).resolve().parents[2]
FONT = str(ROOT / 'assets/fonts/pixelify_sans/PixelifySans-Regular.ttf')
W, H = 160, 368
rng = random.Random(3310)
im = Image.new('RGB', (W,H)); pix=im.load()
for y in range(H):
    for x in range(W):
        n=rng.choice([-3,-1,0,0,1,3])
        pix[x,y]=(42+n,40+n,56+n)
d=ImageDraw.Draw(im); d.fontmode='1'
def px(x,z): return ((x+.025)*3200,(.0575-z)*3200)
def rect(cx,cz,w,h,fill,outline=None):
    x,y=px(cx,cz); hw,hh=w*1600,h*1600
    d.rounded_rectangle((x-hw,y-hh,x+hw-1,y+hh-1),radius=3,fill=fill,outline=outline)
# Sporadic abrasion follows the shell edge rather than uniform noise.
for i in range(350):
    y=rng.randrange(H); edge=8+int(max(0,abs(y-H/2)-120)*.18)
    x=rng.choice([edge+rng.randrange(5),W-edge-rng.randrange(5)])
    d.line((x,y,x+rng.randrange(-2,3),y+rng.randrange(1,5)),fill=rng.choice([(89,77,70),(111,94,77),(66,59,61)]))
rect(0,.027,.041,.039,(15,16,20),(95,83,73))
rect(0,.027,.0355,.0325,(110,135,78))
for z in (.0525,.0495):
    for x in (-.0035,.0035): rect(x,z,.0055,.0015,(12,13,17))
d.text(px(0,.0458),'NOKIA',font=ImageFont.truetype(FONT,9),fill=(160,149,141),anchor='mm')
for cx in (-.0145,.0145):
    rect(cx,0,.011,.0062,(28,27,32),(58,52,53))
    x,y=px(cx,0);d.arc((x-8,y-3,x+8,y+5),185,350,fill=(89,132,66) if cx<0 else (153,62,49),width=3)
rect(0,0,.0145,.0095,(119,100,82),(28,26,29))
rect(0,0,.012,.0075,(45,40,42),(155,133,108))
for z in (-.003,.003):
    x,y=px(0,z);d.polygon([(x-2,y),(x+2,y),(x,y-2 if z>0 else y+2)],fill=(151,133,110))
labels=['1','2 abc','3 def','4 ghi','5 jkl','6 mno','7 pqrs','8 tuv','9 wxyz','* +','0 _','#']
for i,label in enumerate(labels):
    cx=(-.0145,0,.0145)[i%3];cz=(-.0135,-.0255,-.0375,-.0495)[i//3]
    rect(cx,cz,.0118,.0088,(30,28,32),(66,56,52))
    d.text(px(cx,cz),label,font=ImageFont.truetype(FONT,9),fill=(184,160,138),anchor='mm')
out=ROOT/'assets/models/props/phone_face.png';im.save(out);print(out)
