"""Saturated, readable chip/cereal/drink brand colours for the shelf atlas (Pillow). Fictional brands only."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
FONT = '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'
if not Path(FONT).exists():
    FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(n): return ImageFont.truetype(FONT, n)
BRANDS = [('RIDGE','SALT & VINEGAR',(214,168,36)),('HARVEST','OAT CRACKERS',(196,42,34)),('FIELD','TOMATO SOUP',(176,36,30)),('NORTH','SPRING WATER',(44,110,176)),
 ('DAYBREAK','GROUND COFFEE',(92,58,36)),('ORCHARD','APPLE JUICE',(70,140,60)),('MILL','CORN FLAKES',(226,150,30)),('COAST','SEA SALT',(44,96,184)),
 ('DUSK','DARK ROAST',(96,48,40)),('PLAIN','WHOLE MILK',(76,120,170)),('SUNRISE','ORANGE SODA',(228,112,28)),('CREEK','GINGER ALE',(52,128,70)),
 ('HOME','PAPER GOODS',(150,130,96)),('MARLOW’S','PANTRY',(150,44,34)),('HOLLIS','CHEESE PUFFS',(236,176,34)),('SUNDAY','BERRY BISCUITS',(112,52,138))]
im = Image.new('RGB', (1024, 1024)); d = ImageDraw.Draw(im)
for i, (brand, sub, c) in enumerate(BRANDS):
    x = (i % 4) * 256; y = (i // 4) * 256
    light = tuple(min(255, v + 70) for v in c)
    d.rectangle((x, y, x + 255, y + 255), fill=c)
    d.rectangle((x, y + 150, x + 255, y + 255), fill=tuple(int(v * .72) for v in c))
    d.rectangle((x + 9, y + 9, x + 246, y + 246), outline=light, width=3)
    d.rectangle((x + 10, y + 46, x + 246, y + 118), fill=(238, 228, 196))
    d.text((x + 128, y + 82), brand, font=font(31 if len(brand) < 8 else 25), fill=tuple(int(v * .55) for v in c), anchor='mm')
    d.text((x + 128, y + 140), sub, font=font(17), fill=(250, 240, 210), anchor='mm')
    d.ellipse((x + 92, y + 160, x + 164, y + 218), fill=light, outline=(250, 236, 190), width=2)
    d.text((x + 128, y + 236), 'NET WT.  200 g', font=font(12), fill=(240, 228, 196), anchor='mm')
for folder, name in [('assets/materials', 'packaging.png'), ('assets/models', 'retail_packaging.png')]:
    im.save(ROOT / folder / name)
print('bright packaging written')
