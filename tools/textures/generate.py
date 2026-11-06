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
# Broad wear and bump variation rather than uniform surface gloss.
from PIL import ImageFilter
for name in ['tile','asphalt','wood']:
 noise=Image.new('L',(128,128));noise.putdata([r.randrange(80,190) for _ in range(128*128)])
 noise=noise.resize((1024,1024),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(5))
 rough=noise.point(lambda v: int(130+v*.3) if name=='tile' else (int(20+v*.6) if name=='asphalt' else int(130+v*.4)))
 if name=='asphalt':
  d=ImageDraw.Draw(rough)
  for _ in range(9):
   x,y=r.randrange(1024),r.randrange(1024);w,h=r.randrange(70,250),r.randrange(25,90)
   d.ellipse((x,y,x+w,y+h),fill=22)
 rough.convert('RGBA').save(OUT/f'{name}_rough.png')
 bump=Image.new('RGB',(1024,1024),(128,128,255));p=bump.load();np=noise.load()
 for y in range(1024):
  for x in range(1024):
   dx=(np[(x+1)%1024,y]-np[(x-1)%1024,y])*.5;dy=(np[x,(y+1)%1024]-np[x,(y-1)%1024])*.5
   p[x,y]=(max(0,min(255,int(128-dx))),max(0,min(255,int(128-dy))),255)
 bump.convert('RGBA').save(OUT/f'{name}_normal.png')
for p in OUT.glob('*.png'):
 with Image.open(p) as src: image=src.convert('RGBA')
 image.save(p)
def sign(name,size,bg,lines):
 im=Image.new('RGBA',size,bg);d=ImageDraw.Draw(im)
 for text,xy,fs,color in lines:d.text(xy,text,font=font(fs),fill=color,anchor='mm')
 im.save(OUT/f'{name}.png')
sign('register',(512,384),(17,29,25),[("MARLOW'S MARKET",(256,45),28,(143,180,139)),('REGISTER 01      23:46',(256,85),18,(143,180,139)),('------------------------------',(256,116),20,(143,180,139)),('NO SALE',(256,186),38,(163,196,151)),('CASH DRAWER CLOSED',(256,244),18,(143,180,139)),('TOTAL          $ 0.00',(256,320),24,(143,180,139))])
sign('cctv_standby',(512,384),(14,25,24),[('SECURITY MONITOR',(256,55),25,(95,126,109)),('STANDBY',(256,190),32,(95,126,109)),('LOCAL VIDEO SYSTEM',(256,326),17,(95,126,109))])
sign('coffee_poster',(384,512),(197,184,149),[("MARLOW'S",(192,65),36,(64,75,52)),('FRESH COFFEE',(192,150),31,(64,75,52)),('99¢',(192,270),100,(108,52,34)),('REGULAR CUP',(192,371),24,(64,75,52)),('BREWED UNTIL 10 PM',(192,452),21,(64,75,52))])
sign('shipping',(256,128),(190,183,157),[('MARLOW’S / DRY GOODS',(128,19),14,(40,40,33)),('DELIVERY  11/03',(128,45),13,(40,40,33)),('CASE 24   •   KEEP DRY',(128,107),12,(40,40,33))])
im=Image.open(OUT/'shipping.png');d=ImageDraw.Draw(im)
for x in range(22,234,3):
 if r.random()>.25:d.rectangle((x,62,x+r.choice([1,2]),87),fill=(40,40,33))
im.save(OUT/'shipping.png')
