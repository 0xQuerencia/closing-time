"""Original deterministic surface and fictional packaging artwork. Requires Pillow."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import random, math
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/materials'; OUT.mkdir(parents=True,exist_ok=True)
r=random.Random(71)
FONT='/usr/share/fonts/TTF/DejaVuSans.ttf'
if not Path(FONT).exists(): FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(n): return ImageFont.truetype(FONT,n)
for name,base in [('tile',(140,133,119)),('ceiling',(181,178,158)),('asphalt',(45,49,50)),('plaster',(153,146,124)),('wood',(87,65,44)),('brick',(91,70,54))]:
 im=Image.new('RGB',(1024,1024)); p=im.load()
 for y in range(1024):
  for x in range(1024):
   n=r.gauss(0,3 if name!='asphalt' else 8)
   if name=='wood': n+=7*math.sin(y*.17+3*math.sin(x*.007))+4*math.sin(y*.8)
   if name=='tile': n+=3*math.sin(x*.04)*math.sin(y*.023)
   p[x,y]=tuple(max(0,min(255,int(v+n))) for v in base)
 d=ImageDraw.Draw(im)
 if name in ['tile','ceiling']:
  for x in range(0,1024,256):
   d.line((x,0,x,1024),fill=(76,75,68),width=3);d.line((0,x,1024,x),fill=(76,75,68),width=3)
  for _ in range(180):
   x,y=r.randrange(1024),r.randrange(1024);d.line((x,y,x+r.randrange(3,14),y+1),fill=tuple(int(v*.77) for v in base),width=1)
 if name=='brick':
  for y in range(0,1024,128):
   d.line((0,y,1024,y),fill=(118,112,98),width=9)
   for x in range(-256,1024,256): d.line((x+(128 if y//128%2 else 0),y,x+(128 if y//128%2 else 0),y+128),fill=(118,112,98),width=8)
 im.save(OUT/f'{name}.png')
# A shared 4x4 atlas: readable, original brands and price typography.
im=Image.new('RGB',(1024,1024));d=ImageDraw.Draw(im)
brands=[('RIDGE','SALT & VINEGAR',(132,60,39)),('HARVEST','OAT CRACKERS',(167,137,67)),('FIELD','TOMATO SOUP',(131,47,35)),('NORTH','SPRING WATER',(48,94,101)),('DAYBREAK','GROUND COFFEE',(82,65,44)),('ORCHARD','APPLE JUICE',(79,103,58)),('MILL','CORN FLAKES',(188,150,71)),('COAST','SEA SALT',(56,92,115)),('DUSK','DARK ROAST',(80,54,42)),('PLAIN','WHOLE MILK',(91,116,130)),('SUNRISE','ORANGE SODA',(166,94,36)),('CREEK','GINGER ALE',(66,100,67)),('HOME','PAPER GOODS',(132,119,96)),('MARLOW’S','PANTRY',(130,59,40)),('OAK','ROASTED NUTS',(97,73,44)),('SUNDAY','BUTTER BISCUITS',(165,133,76))]
for i,(brand,sub,c) in enumerate(brands):
 x=(i%4)*256;y=(i//4)*256
 d.rectangle((x,y,x+255,y+255),fill=c);d.rectangle((x+9,y+9,x+246,y+246),outline=(214,200,159),width=3)
 d.rectangle((x+10,y+51,x+246,y+113),fill=(223,211,177))
 d.text((x+128,y+80),brand,font=font(29 if len(brand)<8 else 24),fill=(44,48,40),anchor='mm')
 d.text((x+128,y+136),sub,font=font(17),fill=(245,231,197),anchor='mm')
 d.ellipse((x+95,y+159,x+161,y+208),fill=tuple(min(255,v+45) for v in c),outline=(221,205,156),width=2)
 d.text((x+128,y+228),'NET WT.  200 g',font=font(12),fill=(230,218,191),anchor='mm')
im.save(OUT/'packaging.png')
