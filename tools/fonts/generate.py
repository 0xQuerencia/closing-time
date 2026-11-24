"""Rebuild the original Marlow Terminal bitmap face from its authored row masks."""
from pathlib import Path
import json,struct,zlib,binascii
root=Path(__file__).resolve().parents[2]
glyphs=json.loads((Path(__file__).with_name("glyphs.json")).read_text())
chars=sorted(glyphs,key=ord)
w,h=128,((len(chars)+15)//16)*10
raw=bytearray(h*(1+4*w))
rows=[]
for i,ch in enumerate(chars):
    x,y=i%16*8,i//16*10
    vals=bytes.fromhex(glyphs[ch])
    occupied=[c for v in vals for c in range(5) if v&(1<<(4-c))]
    l=min(occupied,default=5)
    r=max(occupied,default=-1)
    width=max(0,r-l+1)
    for row,v in enumerate(vals):
        for c in range(l,r+1):
            if v&(1<<(4-c)):
                p=(y+row)*(1+4*w)+1+4*(x+c-l)
                raw[p:p+4]=bytes([255]*4)
    rows.append(f"char id={ord(ch)} x={x} y={y} width={width} height={len(vals)} xoffset=0 yoffset=1 xadvance={width+1 if width else 3} page=0 chnl=15")
def chunk(kind,body):
    data=kind+body
    return struct.pack(">I",len(body))+data+struct.pack(">I",binascii.crc32(data)&0xffffffff)
n=len(raw)
compressed=b"\x78\x01\x01"+struct.pack("<HH",n,65535-n)+raw+struct.pack(">I",zlib.adler32(raw)&0xffffffff)
png=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,6,0,0,0))+chunk(b"IDAT",compressed)+chunk(b"IEND",b"")
out=root/"assets/fonts/original"
out.mkdir(parents=True,exist_ok=True)
(out/"marlow.png").write_bytes(png)
header='info face="Marlow Terminal" size=10 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0\n'+f'common lineHeight=11 base=8 scaleW={w} scaleH={h} pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0\npage id=0 file="marlow.png"\nchars count={len(chars)}\n'
(out/"marlow.fnt").write_text(header+"\n".join(rows)+"\n")
