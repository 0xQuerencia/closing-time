#!/usr/bin/env python3
"""Original Marlow's Market PSX props. Python 3 + Pillow + numpy. Y-up, meters, +Z front."""
from pathlib import Path
import math, json, struct, hashlib, io, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parent
MODELS=ROOT/'models'; TEX=ROOT/'textures'; SRC=ROOT/'source'; PRE=ROOT/'renders'
for p in (MODELS,TEX,SRC,PRE):p.mkdir(exist_ok=True)
F=ImageFont.load_default()
PALETTE={'cream':'#b4aa91','beige':'#8d8167','dark':'#353837','steel':'#696c64','wood':'#77604a','red':'#813e36','blue':'#4b536b','green':'#4b5945','glass':'#253438','rubber':'#30302e','paper':'#d1c3a0','white':'#b9b6a4','brown':'#66513e','gold':'#b29a58','black':'#222624','light':'#d7c79a','skin':'#ba9780'}
def rgb(c):
 c=PALETTE.get(c,c).lstrip('#');return tuple(int(c[i:i+2],16) for i in (0,2,4))
def shift(c,d): return tuple(max(0,min(255,x+d)) for x in c)
def texture(name,key,base,pattern):
 seed=int.from_bytes(hashlib.sha256((name+key).encode()).digest()[:8],'little');rng=np.random.default_rng(seed);r=random.Random(seed);c=rgb(base)
 coarse=np.array(Image.fromarray(rng.integers(0,256,(12,12),dtype=np.uint8)).resize((64,64),Image.Resampling.BILINEAR),float)-128
 fine=rng.normal(0,5,(64,64)); noise=coarse*.13+fine
 a=np.clip(np.array(c)[None,None,:]+noise[:,:,None],0,255).astype('uint8');im=Image.fromarray(a);d=ImageDraw.Draw(im)
 # Wear is spatially directed: edge dirt, chips, streaks and seams, not uniform TV noise.
 for i in range(25):
  x,y=r.randrange(64),r.randrange(64);col=shift(c,r.choice([-28,-19,-12,17]));d.line((x,y,min(63,x+r.randint(1,5)),min(63,y+r.randint(0,3))),fill=col)
 if pattern=='wood':
  for y in range(2,64,8):d.line((0,y,63,y),fill=shift(c,-22));d.line((0,y+1,63,y+1),fill=shift(c,9))
  for _ in range(25):
   x,y=r.randrange(56),r.randrange(64);d.line((x,y,x+r.randrange(4,9),y),fill=shift(c,-13))
 elif pattern=='plaid':
  for x in range(0,64,16):d.rectangle((x,0,x+4,63),fill=shift(c,15));d.line((x+7,0,x+7,63),fill=shift(c,-17))
  for y in range(0,64,16):d.rectangle((0,y,63,y+3),fill=shift(c,11));d.line((0,y+7,63,y+7),fill=shift(c,-22))
 elif pattern=='fabric':
  for y in range(0,64,3):
   for x in range((y%2),64,4):d.point((x,y),fill=shift(c,r.choice([-18,12])))
 elif pattern=='vents':
  for y in range(12,54,5):d.rectangle((7,y,56,y+2),fill=shift(c,-46));d.line((7,y+3,56,y+3),fill=shift(c,13))
 elif pattern=='screen':
  d.rectangle((0,0,63,63),fill=rgb('glass'));d.rectangle((2,2,61,61),outline=(69,83,71));
  for y in range(5,60,4):d.line((3,y,60,y),fill=(37,52,47))
  for y in (10,16,22,36,42):d.line((7,y,r.randint(21,54),y),fill=(104,139,91))
 elif pattern=='keyboard':
  d.rectangle((2,3,61,59),fill=shift(c,-24));
  for y in range(6,46,10):
   for x in range(5,60,5):d.rectangle((x,y,x+3,y+6),fill=shift(c,18));d.point((x+1,y+2),fill=shift(c,-60))
  d.rectangle((17,49,43,55),fill=shift(c,20))
 elif pattern=='phone':
  d.rectangle((10,4,53,15),fill=rgb('glass'));d.rectangle((13,6,50,12),fill=(112,126,87))
  for y in range(22,57,9):
   for x in (13,27,41):d.rectangle((x,y,x+9,y+6),fill=shift(c,32));d.point((x+4,y+2),fill=shift(c,-32))
 elif pattern=='crate':
  for y in (5,19,33,47):
   for x in (5,19,33,47):d.rectangle((x,y,x+9,y+8),fill=shift(c,-39));d.line((x,y+9,x+9,y+9),fill=shift(c,22))
 elif pattern=='peg':
  for y in range(3,64,5):
   for x in range(3,64,5):d.point((x,y),fill=shift(c,-48))
 elif pattern=='products':
  cols=['#a88c52','#6c4035','#475e73','#56684c','#9e9574','#783c3d']
  for x in range(2,64,8):
   k=rgb(r.choice(cols));d.rectangle((x,5,x+6,57),fill=k);d.rectangle((x,15,x+6,27),fill=shift(k,32));d.rectangle((x+1,33,x+5,44),fill=shift(k,-16));d.line((x,58,x+6,58),fill=(40,36,30))
 elif pattern=='gauges':
  d.rectangle((0,0,63,63),fill=(32,35,32));
  for x in (18,45):
   d.ellipse((x-12,10,x+12,34),outline=(130,126,98));
   for ang in np.linspace(-math.pi*.8,math.pi*.8,9):
    p=(x+int(10*math.sin(ang)),22-int(10*math.cos(ang)));d.point(p,fill=(199,182,136))
   d.line((x,22,x-6,16),fill=(195,98,52),width=1)
  d.rectangle((22,43,41,49),fill=(86,103,66))
 elif pattern=='radio':
  d.rectangle((4,7,59,20),fill=(36,46,37));d.line((10,13,43,13),fill=(117,134,81));
  for x in range(6,58,9):d.rectangle((x,31,x+6,37),fill=shift(c,25))
  for x in (12,50):d.ellipse((x-6,45,x+6,57),fill=shift(c,-24),outline=shift(c,22))
 elif pattern=='label':
  d.rectangle((8,9,55,53),fill=rgb('paper'));d.rectangle((8,9,55,15),fill=rgb('red'));d.text((13,17),'ABC',fill=(64,53,40),font=F)
  for y in range(29,46,4):d.line((12,y,49-r.randint(0,12),y),fill=(105,95,75))
 elif pattern=='ice':
  d.rectangle((4,5,59,58),outline=shift(c,-27),width=2);d.text((20,23),'ICE',font=F,fill=(53,73,116));d.line((5,48,58,48),fill=shift(c,-22))
 elif pattern=='sign':
  d.rectangle((2,2,61,61),outline=shift(c,-35),width=2);d.text((8,12),"MARLOW'S",font=F,fill=(123,43,35));d.text((13,27),'MARKET',font=F,fill=(123,43,35));d.rectangle((6,44,57,55),fill=(110,43,35));d.text((10,44),'MIDNIGHT',font=F,fill=(220,204,168))
 elif pattern=='route':
  d.rectangle((2,2,61,61),outline=(184,184,151));d.text((8,10),'ROUTE 9',font=F,fill=(207,205,176));d.text((8,25),'BYPASS',font=F,fill=(207,205,176));d.line((18,45,45,45),fill=(207,205,176),width=2);d.line((39,39,45,45,39,51),fill=(207,205,176),width=2)
 elif pattern=='photo':
  d.rectangle((5,5,58,58),fill=(126,135,128));d.rectangle((5,38,58,58),fill=(75,94,70));
  for x,k in [(22,(149,103,85)),(43,(177,137,108))]:d.ellipse((x-7,14,x+7,30),fill=k);d.rectangle((x-10,31,x+10,53),fill=(59,63,68));d.arc((x-8,11,x+8,30),180,360,fill=(59,43,36),width=4)
 elif pattern=='notice':
  d.text((5,5),'RENT DUE',font=F,fill=(65,52,40));d.line((5,17,58,17),fill=rgb('red'));d.text((5,22),'DEC 1',font=F,fill=(65,52,40));
  for y in (36,40,44,48):d.line((5,y,r.randrange(37,59),y),fill=(126,112,89))
 elif pattern=='tire':
  for y in range(0,64,8):d.line((0,y,31,y+4,63,y),fill=shift(c,-19),width=2)
 elif pattern=='door':
  d.rectangle((4,3,59,60),outline=shift(c,-30),width=2);d.line((5,31,58,31),fill=shift(c,-34),width=2);d.line((48,15,48,25),fill=shift(c,-49),width=3);d.line((48,38,48,49),fill=shift(c,-49),width=3)
 elif pattern=='stripe':
  d.rectangle((0,8,63,17),fill=rgb('red'));d.line((0,18,63,18),fill=shift(c,-18))
 elif pattern=='grille':
  d.rectangle((4,5,59,58),fill=(45,45,40));
  for y in range(7,57,5):d.line((6,y,57,y),fill=shift(c,13),width=2)
 elif pattern=='buttons':
  for x in (12,26,40):d.rectangle((x,15,x+8,22),fill=shift(c,-40));d.point((x+3,17),fill=(181,96,58))
 # Border scuffs and occasional oxidized chips on hard surfaces; keep artwork legible.
 if pattern not in ('screen','photo','notice','gauges','products','plaid'):
  d.line((0,0,63,0),fill=shift(c,15));d.line((0,63,63,63),fill=shift(c,-31));d.line((0,0,0,63),fill=shift(c,-12))
 return im

class Model:
 def __init__(self,name):self.name=name;self.tiles={};self.atlas=Image.new('RGB',(256,256));self.parts={'Body':[]};self.part='Body'
 def tile(self,k,base,pattern='plain'):
  if k not in self.tiles:
   i=len(self.tiles);assert i<16,(self.name,k);self.tiles[k]=i;self.atlas.paste(texture(self.name,k,base,pattern),((i%4)*64,(i//4)*64))
  return k
 def group(self,name):self.part=name;self.parts.setdefault(name,[])
 def face(self,vs,mat,uv=None):
  vs=np.array(vs,float);n=np.cross(vs[1]-vs[0],vs[2]-vs[0]);l=np.linalg.norm(n)
  if uv is None:
   if len(vs)==4:uv=[(0,1),(1,1),(1,0),(0,0)]
   else:
    axes=np.argsort(np.ptp(vs,axis=0))[-2:];coords=vs[:,axes];lo=coords.min(0);uv=((coords-lo)/np.maximum(np.ptp(coords,axis=0),1e-9)).tolist()
  if l<1e-9:return
  n=n/l;idx=self.tiles[mat];u0=(idx%4)*64;v0=(idx//4)*64
  uv=np.array([((u0+1.5+u*61)/256,(v0+1.5+v*61)/256) for u,v in uv])
  for i in range(1,len(vs)-1):self.parts[self.part].append((vs[[0,i,i+1]],uv[[0,i,i+1]],n))
 def loft(self,rings,mat,axis=1,center=(0,0,0),sides=8,cap=True,front=None,angle=0):
  # rings: (height, half-width, half-depth, bevel); rectangular chamfered cross-sections.
  arr=[];co=math.cos(angle);si=math.sin(angle)
  for y,w,d,b in rings:
   if sides==4:pts=[(-w,-d),(w,-d),(w,d),(-w,d)]
   else:
    b=min(b,w*.9,d*.9);pts=[(-w+b,-d),(w-b,-d),(w,-d+b),(w,d-b),(w-b,d),(-w+b,d),(-w,d-b),(-w,-d+b)]
   a=[]
   for x,z in pts:
    if axis==1:v=(x,y,z)
    elif axis==2:v=(x,-z,y)
    else:v=(y,-x,z)
    x,yv,z=v;a.append((x*co+z*si+center[0],yv+center[1],-x*si+z*co+center[2]))
   arr.append(a)
  n=len(arr[0]);mats=mat if isinstance(mat,tuple) else (mat,mat,mat)
  for i in range(len(arr)-1):
   for j in range(n):
    k=(j+1)%n;material=front if front is not None and j==(2 if n==4 else 4) else mats[0]
    self.face([arr[i][j],arr[i+1][j],arr[i+1][k],arr[i][k]],material,[(1,1),(1,0),(0,0),(0,1)])
  if cap:
   for arrx,mt,rev in [(arr[0],mats[1],False),(arr[-1],mats[2],True)]:
    # Cap UV projected to cross section, with fixed orientation.
    coords=np.array(arrx)[:,[0,2] if axis==1 else ([0,1] if axis==2 else [1,2])];uv=((coords-coords.min(0))/np.maximum(np.ptp(coords,axis=0),1e-9)).tolist()
    if rev:arrx=arrx[::-1];uv=uv[::-1]
    self.face(arrx,mt,uv)
 def box(self,p,s,m,bevel=0,front=None,angle=0):
  w,h,d=np.array(s)/2;self.loft([(-h,w,d,bevel),(h,w,d,bevel)],m,center=p,sides=8 if bevel else 4,front=front,angle=angle)
 def cyl(self,p,rings,mat,n=8,axis=1):
  # circular polygon profile with flat normals and cylindrical UVs
  arr=[]
  for y,r in rings:
   a=[]
   for i in range(n):
    t=2*math.pi*i/n; x,z=r*math.cos(t),r*math.sin(t)
    v=(x,y,z) if axis==1 else ((x,-z,y) if axis==2 else (y,-x,z));a.append(tuple(np.array(v)+p))
   arr.append(a)
  for i in range(len(arr)-1):
   for j in range(n):
    k=(j+1)%n;self.face([arr[i][j],arr[i+1][j],arr[i+1][k],arr[i][k]],mat,[(j/n,1),(j/n,0),((j+1)/n,0),((j+1)/n,1)])
  uv=[(.5+.48*math.cos(2*math.pi*j/n),.5+.48*math.sin(2*math.pi*j/n)) for j in range(n)];self.face(arr[0],mat,uv);self.face(arr[-1][::-1],mat,uv[::-1])
 def beam(self,a,b,w,d,mat):
  a,b=np.array(a),np.array(b);v=b-a;length=np.linalg.norm(v);y=v/length;x=np.cross(y,[0,0,1]);
  if np.linalg.norm(x)<1e-5:x=np.cross(y,[1,0,0])
  x=x/np.linalg.norm(x);z=np.cross(x,y);p=(a+b)/2
  pts=[p+x*i*w/2+y*j*length/2+z*k*d/2 for i,j,k in [(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1),(-1,1,-1),(1,1,-1),(1,1,1),(-1,1,1)]]
  for face in [(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0),(0,1,2,3),(7,6,5,4)]:self.face([pts[i] for i in face],mat)
 def plane(self,pts,m):self.face(pts,m)
 def export(self):
  # One atlas material; separate mesh nodes only for animated or live-display parts.
  png=TEX/(self.name+'.png');self.atlas.save(png,optimize=True)
  binary=bytearray();views=[];access=[];meshes=[];nodes=[];obj=['mtllib '+self.name+'.mtl'];offset=1;total=0;allpos=[]
  def add(data,target=None):
   while len(binary)%4:binary.append(0)
   v={'buffer':0,'byteOffset':len(binary),'byteLength':len(data)}
   if target:v['target']=target
   views.append(v);binary.extend(data);return len(views)-1
  def acc(a,typ,ct,target):
   idx=add(a.tobytes(),target);v={'bufferView':idx,'componentType':ct,'count':len(a),'type':typ}
   if typ=='VEC3' and target==34962:v.update(min=a.min(0).tolist(),max=a.max(0).tolist())
   access.append(v);return len(access)-1
  for part,tri in self.parts.items():
   if not tri:continue
   # Deduplicate by position/normal/UV, preserving intentional flat seams.
   p=[];n=[];uv=[];ix=[];seen={}
   for verts,us,normal in tri:
    for pt,u in zip(verts,us):
     key=tuple(np.round(np.r_[pt,normal,u],6));i=seen.get(key)
     if i is None:i=len(p);seen[key]=i;p.append(pt);n.append(normal);uv.append(u)
     ix.append(i)
   p=np.array(p,np.float32);n=np.array(n,np.float32);uv=np.array(uv,np.float32);ix=np.array(ix,np.uint16);allpos.append(p);total+=len(ix)//3
   attrs={'POSITION':acc(p,'VEC3',5126,34962),'NORMAL':acc(n,'VEC3',5126,34962),'TEXCOORD_0':acc(uv,'VEC2',5126,34962)}
   meshes.append({'name':part,'primitives':[{'attributes':attrs,'indices':acc(ix,'SCALAR',5123,34963),'material':0}]});nodes.append({'name':part,'mesh':len(meshes)-1})
   obj+=['o '+part]+['v %.6f %.6f %.6f'%tuple(x) for x in p]+['vt %.6f %.6f'%(x,1-y) for x,y in uv]+['vn %.6f %.6f %.6f'%tuple(x) for x in n]+['usemtl Atlas']
   for face in ix.reshape(-1,3):obj.append('f '+' '.join(f'{i+offset}/{i+offset}/{i+offset}' for i in face))
   offset+=len(p)
  img=add(png.read_bytes());g={'asset':{'version':'2.0','generator':'Marlow PSX asset workshop'},'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],'nodes':nodes,'meshes':meshes,'materials':[{'name':'Atlas','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':.92}}],'textures':[{'sampler':0,'source':0}],'samplers':[{'magFilter':9728,'minFilter':9984,'wrapS':33071,'wrapT':33071}],'images':[{'bufferView':img,'mimeType':'image/png'}],'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':access}
  j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);binary+=b'\0'*((-len(binary))%4);blob=struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary;(MODELS/(self.name+'.glb')).write_bytes(blob)
  (SRC/(self.name+'.obj')).write_text('\n'.join(obj)+'\n');(SRC/(self.name+'.mtl')).write_text('newmtl Atlas\nKd 1 1 1\nKa 0.15 0.15 0.15\nKs 0 0 0\nmap_Kd ../textures/'+self.name+'.png\n')
  p=np.concatenate(allpos);return {'name':self.name,'triangles':total,'vertices':offset-1,'atlas':'256x256','materials':1,'nodes':[n['name'] for n in nodes],'bounds_m':[np.round(p.min(0),4).tolist(),np.round(p.max(0),4).tolist()],'bytes':len(blob)}

assets=[]
def new(name,spec):
 m=Model(name);assets.append(m)
 for k,v in spec.items():m.tile(k,*v) if isinstance(v,tuple) else m.tile(k,v)
 return m
# Store equipment. Sizes and origins follow the existing game placements.
m=new('crt',{'shell':('cream','plain'),'side':('beige','vents'),'bezel':'beige','glass':('glass','screen'),'base':'dark','badge':'gold'})
m.loft([(0,.095,.09,.012),(.04,.11,.10,.012)],'base');m.loft([(.045,.16,.15,.018),(.08,.19,.19,.018),(.35,.19,.19,.018),(.365,.16,.16,.015)],('shell','side','shell'),center=(0,0,-.008));m.box((0,.218,.171),(.365,.285,.04),'bezel',.014);m.box((0,.212,.191),(.303,.225,.012),'base',.01);m.group('OriginalCRTGlass');m.plane([(-.145,.1095,.201),(.145,.1095,.201),(.145,.3145,.201),(-.145,.3145,.201)],'glass');m.group('Body');m.box((.153,.077,.195),(.018,.01,.008),'badge');m.box((0,.192,-.203),(.26,.17,.008),'side')
m=new('keyboard',{'case':'beige','keys':('cream','keyboard'),'edge':'dark'});m.loft([(0,.20,.077,.008),(.012,.20,.077,.008),(.036,.19,.073,.008)],('case','edge','keys'));m.box((0,.02,.078),(.37,.01,.004),'edge')
m=new('computer',{'shell':('cream','plain'),'front':('beige','vents'),'dark':'dark','light':'gold'});m.loft([(0,.095,.18,.008),(.015,.10,.19,.008),(.37,.10,.19,.008),(.385,.09,.18,.008)],'shell',front='front');m.box((0,.30,.194),(.165,.042,.009),'dark');m.box((0,.247,.194),(.165,.032,.009),'dark');m.box((.055,.055,.196),(.025,.022,.01),'light')
m=new('desk',{'wood':('wood','wood'),'drawer':('beige','door'),'steel':'steel','dark':'dark'});m.box((0,.738,0),(1.55,.07,.78),'wood',.016);m.box((0,.51,-.34),(1.39,.28,.04),'wood');
for x in [-.53,.53]:
 m.box((x,.343,0),(.40,.686,.68),'wood',.008);m.box((x,.34,.344),(.37,.61,.014),'drawer');m.box((x,.045,0),(.36,.09,.65),'dark');
m.box((-.53,.53,.36),(.15,.018,.025),'steel');m.box((-.53,.23,.36),(.15,.018,.025),'steel')
m=new('chair',{'cloth':('blue','fabric'),'edge':'dark','steel':'steel','rubber':'rubber'});m.loft([(.421,.21,.20,.03),(.44,.235,.22,.045),(.507,.23,.215,.045),(.52,.19,.18,.035)],'cloth');m.loft([(-.185,.18,.045,.025),(-.15,.22,.045,.025),(.15,.22,.04,.025),(.18,.18,.035,.02)],'cloth',center=(0,.727,-.205));m.beam((0,.45,-.12),(0,.68,-.22),.045,.05,'steel');m.cyl((0,0,0),[(.08,.045),(.42,.026)],'steel',8)
for i in range(5):
 a=2*math.pi*i/5;x,z=math.sin(a),math.cos(a);m.beam((0,.10,0),(x*.245,.05,z*.245),.047,.05,'edge');m.cyl((x*.245,.035,z*.245),[(-.025,.031),(.025,.031)],'rubber',6)
m=new('phone',{'body':'dark','panel':('beige','phone'),'handle':'rubber'});m.loft([(0,.106,.085,.008),(.022,.106,.085,.008),(.061,.10,.077,.008)],('body','body','panel'));m.loft([(-.073,.025,.027,.008),(-.05,.025,.023,.006),(.045,.019,.021,.005),(.075,.027,.029,.008)],'handle',axis=2,center=(-.073,.069,0));
m=new('wall_phone',{'body':'cream','panel':('beige','phone'),'handle':'dark','cable':'rubber'});m.box((0,.18,0),(.22,.34,.065),'body',.01,front='panel');m.loft([(-.13,.034,.033,.008),(-.09,.036,.03,.008),(.09,.024,.024,.006),(.13,.035,.034,.008)],'handle',center=(-.065,.18,.047));
for a,b in zip([(-.065,.05,.06),(-.07,-.05,.06),(.03,-.10,.06),(.09,-.02,.04)],[(-.07,-.05,.06),(.03,-.10,.06),(.09,-.02,.04),(.09,.02,.04)]):m.beam(a,b,.009,.009,'cable')
m=new('camera',{'housing':('cream','plain'),'plate':'steel','lens':'glass','dark':'dark'});m.loft([(-.13,.062,.05,.012),(-.10,.067,.056,.01),(.10,.064,.052,.01),(.125,.056,.045,.01)],('housing','plate','dark'),axis=2);m.box((0,.065,.02),(.145,.018,.265),'housing');m.cyl((0,0,.129),[(-.005,.038),(.008,.034),(.014,.026)],'lens',8,axis=2);m.beam((0,.03,-.095),(0,.15,-.16),.035,.035,'plate');m.box((0,.15,-.18),(.11,.12,.025),'plate',.006)
m=new('scanner',{'case':'dark','lens':'red','base':'steel'});m.box((0,.025,0),(.13,.05,.15),'base',.012);m.beam((0,.045,0),(0,.15,-.04),.045,.055,'case');m.loft([(-.065,.047,.032,.01),(.045,.06,.039,.008),(.065,.05,.031,.006)],('case','case','lens'),axis=2,center=(0,.17,-.04));m.group('ScanWindow');m.plane([(-.04,.147,.026),(.04,.147,.026),(.04,.19,.026),(-.04,.19,.026)],'lens')
m=new('cash_drawer',{'metal':'dark','front':'steel','tray':'rubber','coin':'gold'});m.box((0,.02,0),(.41,.04,.37),'metal');m.box((0,.07,-.166),(.41,.08,.038),'metal');
for x in (-.19,.19):m.box((x,.07,0),(.025,.08,.34),'metal')
m.group('Drawer');m.box((0,.055,.045),(.36,.025,.31),'tray');m.box((0,.075,.21),(.39,.073,.025),'front',.004);m.cyl((0,.075,.224),[(-.004,.012),(.003,.012)],'coin',8,axis=2)
for x in [-.12,-.04,.04,.12]:m.box((x,.075,.045),(.009,.038,.28),'tray')
m=new('extinguisher',{'body':('red','label'),'cap':'steel','hose':'rubber','base':'red'});m.cyl((0,0,0),[(0,.052),(.018,.075),(.315,.075),(.35,.067),(.38,.032)],'body',10);m.cyl((0,0,0),[(.38,.026),(.405,.024)],'cap',8);m.box((0,.421,.02),(.135,.02,.04),'cap',.005);m.beam((.035,.402,0),(.105,.34,0),.022,.022,'hose');m.beam((.105,.34,0),(.105,.16,0),.021,.021,'hose');m.beam((.105,.16,0),(.08,.10,.02),.022,.022,'hose')
m=new('crate',{'red':('red','crate'),'rim':'red','bottle':'green','cap':'gold','base':'dark'});m.box((0,.02,0),(.54,.04,.36),'base');
for x in [-.25,.25]:m.box((x,.12,0),(.025,.20,.36),'red');m.box((x,.225,0),(.04,.035,.36),'rim')
for z in [-.16,.16]:m.box((0,.12,z),(.52,.20,.025),'red');m.box((0,.225,z),(.54,.035,.035),'rim')
for x in [-.16,0,.16]:
 for z in [-.08,.08]:m.cyl((x,0,z),[(.04,.04),(.22,.04),(.27,.022),(.31,.017)],'bottle',6);m.cyl((x,0,z),[(.31,.019),(.327,.019)],'cap',6)
m=new('mug',{'ceramic':'cream','coffee':'brown'});m.cyl((0,0,0),[(0,.036),(.01,.047),(.089,.047),(.095,.044)],'ceramic',10);m.cyl((0,0,0),[(.095,.039),(.096,.039)],'coffee',10);p=[(.044,.024,0),(.079,.025,0),(.085,.052,0),(.074,.074,0),(.045,.076,0)];
for a,b in zip(p,p[1:]):m.beam(a,b,.013,.016,'ceramic')
m=new('counter',{'panel':('cream','stripe'),'top':('beige','plain'),'base':'dark','end':'beige','poster':('paper','label')});m.box((0,.44,0),(2.6,.88,.78),'panel',.02);m.box((0,.90,0),(2.67,.055,.85),'top',.02);m.box((0,.06,0),(2.56,.12,.76),'base');m.box((-.58,.46,.397),(.40,.28,.006),'poster');m.box((.62,.46,.397),(.34,.24,.006),'poster')
m=new('shelf',{'metal':'cream','peg':('beige','peg'),'goods':('red','products'),'base':'dark'});m.box((0,.09,0),(1.20,.18,.72),'base');m.box((0,.9,0),(1.18,1.58,.045),'peg');
for y in (.22,.62,1.02,1.42):
 m.box((0,y,0),(1.22,.045,.68),'metal');
 for z in (-.19,.19):m.box((0,y+.13,z),(1.07,.215,.235),'goods')
for x in (-.61,.61):m.box((x,.90,0),(.045,1.8,.62),'metal')
m=new('cooler',{'body':('cream','stripe'),'goods':('dark','products'),'frame':'steel','vent':('dark','vents'),'glass':'glass'});m.box((0,1.03,-.28),(1.80,2.06,.18),'body');m.box((0,.12,0),(1.8,.24,.63),'vent');m.box((0,1.97,0),(1.80,.22,.63),'body');
for x in [-.9,0,.9]:m.box((x,1.05,0),(.045,1.8,.63),'frame')
for x in [-.45,.45]:
 m.box((x,1.02,-.12),(.84,1.56,.025),'goods');
 for y in [.30,.70,1.1,1.5,1.79]:m.box((x,y,.0),(.84,.027,.52),'frame')
 m.box((x+.39,1.05,.33),(.033,.36,.045),'frame')
# Apartment assets
m=new('bed',{'wood':('wood','wood'),'sheet':'cream','blanket':('blue','plaid'),'pillow':('cream','fabric'),'metal':'steel'});m.box((0,.28,0),(1.43,.13,2.08),'wood',.025)
for x in [-.64,.64]:
 for z in [-.92,.92]:m.box((x,.16,z),(.075,.32,.075),'wood',.008)
 m.box((x,.54,-.98),(.055,1.08,.06),'metal')
m.box((0,.98,-.98),(1.34,.055,.065),'metal');m.box((0,.69,-.98),(1.34,.035,.045),'metal');m.loft([(.35,.69,1.0,.07),(.41,.72,1.03,.075),(.51,.69,1.0,.06)],'sheet');m.loft([(.51,.70,.72,.03),(.56,.70,.72,.04),(.58,.65,.68,.06)],'blanket',center=(0,0,.23));m.loft([(.52,.36,.18,.07),(.58,.39,.20,.08),(.65,.34,.16,.08)],'pillow',center=(0,0,-.70))
m=new('apartment_desk',{'wood':('wood','wood'),'drawer':('wood','door'),'dark':'dark','steel':'steel'});m.box((0,.72,0),(1.7,.075,.76),'wood',.02);m.box((-.78,.34,0),(.09,.68,.67),'wood');m.box((.58,.34,0),(.46,.68,.67),'wood');m.box((.58,.35,.34),(.42,.57,.025),'drawer');m.box((0,.54,-.34),(1.4,.22,.035),'wood');m.box((.58,.5,.365),(.16,.02,.025),'steel');m.box((.58,.23,.365),(.16,.02,.025),'steel')
m=new('fridge',{'shell':'cream','door':('cream','door'),'dark':'dark','steel':'steel'});m.loft([(0,.36,.34,.04),(.06,.40,.38,.035),(1.60,.40,.38,.035),(1.65,.36,.34,.035)],'shell',front='door');m.box((0,1.13,.384),(.73,.015,.008),'dark');m.box((.28,1.39,.414),(.04,.18,.045),'steel',.006);m.box((.28,.90,.414),(.04,.21,.045),'steel',.006)
m=new('kitchen',{'wood':('beige','door'),'top':('cream','plain'),'sink':'steel','dark':'dark'});m.box((0,.43,0),(.93,.86,2.6),'wood',.01);m.box((0,.90,0),(1.02,.08,2.68),'top',.015);m.box((0,.947,-.65),(.56,.018,.63),'sink',.04);m.box((0,.958,-.65),(.42,.01,.49),'dark',.05);m.beam((.34,.95,-.65),(.34,1.17,-.65),.035,.035,'sink');m.beam((.34,1.17,-.65),(.10,1.17,-.65),.035,.035,'sink');m.beam((.10,1.17,-.65),(.10,1.10,-.65),.035,.035,'sink')
m=new('keyring',{'metal':'steel','tag':'red'});n=12
for i in range(n):
 a=2*math.pi*i/n;b=2*math.pi*(i+1)/n;m.beam((.023*math.cos(a),.013,.023*math.sin(a)),(.023*math.cos(b),.013,.023*math.sin(b)),.003,.003,'metal')
for x,z in [(-.013,.038),(.017,.032)]:m.box((x,.008,z),(.014,.006,.055),'metal',.002);m.box((x,.008,z-.025),(.024,.009,.019),'metal',.004);m.box((x+.007,.008,z+.015),(.013,.006,.012),'metal')
m.box((.033,.009,-.015),(.028,.008,.045),'tag',.006,angle=.4);m.beam((.019,.012,-.013),(.032,.012,-.015),.003,.003,'metal')
m=new('photo_frame',{'wood':('wood','wood'),'photo':('paper','photo'),'back':'dark'});m.box((0,.115,0),(.19,.23,.025),'wood',.008);m.box((0,.115,.014),(.158,.198,.005),'photo');m.beam((0,.16,-.013),(0,.01,-.072),.025,.01,'back')
m=new('rent_notice',{'paper':('paper','notice')});m.plane([(-.11,0,-.145),(-.11,0,.145),(.11,0,.145),(.11,0,-.145)],'paper')
m=new('vest',{'cloth':('red','fabric'),'trim':'dark','badge':'cream'});# hanging vest, open front and shoulders, thickness via separate back panel
m.plane([(-.24,.03,.005),(-.23,.40,.005),(-.13,.54,.005),(-.07,.48,.005),(-.04,.32,.005),(-.04,.03,.005)][::-1],'cloth');m.plane([(.04,.03,.005),(.04,.32,.005),(.07,.48,.005),(.13,.54,.005),(.23,.40,.005),(.24,.03,.005)][::-1],'cloth');m.plane([(-.23,.03,-.025),(.23,.03,-.025),(.23,.40,-.025),(.13,.54,-.025),(-.13,.54,-.025),(-.23,.40,-.025)][::-1],'cloth');m.box((.13,.34,.009),(.10,.05,.006),'badge');m.beam((-.16,.50,0),(0,.60,0),.015,.015,'trim');m.beam((0,.60,0),(.16,.50,0),.015,.015,'trim')
# Road and exterior
m=new('dashboard',{'vinyl':('dark','fabric'),'trim':'steel','gauges':('dark','gauges'),'radio':('dark','radio'),'vents':('dark','vents')});m.loft([(.36,.81,.14,.06),(.58,.83,.22,.05),(.74,.83,.23,.06),(.80,.78,.19,.06)],'vinyl',center=(0,0,-.65));m.box((-.38,.78,-.48),(.47,.16,.20),'vinyl',.035);m.box((-.38,.77,-.367),(.40,.115,.012),'gauges',.008);m.box((.15,.58,-.412),(.28,.23,.025),'radio',.012)
for x in (-.70,.62):m.box((x,.68,-.407),(.16,.09,.016),'vents',.01)
m.box((.46,.42,-.42),(.42,.18,.012),'trim',.012)
m=new('steering_wheel',{'rim':('rubber','fabric'),'hub':'dark','trim':'steel'});n=12
for i in range(n):
 a=2*math.pi*i/n;b=2*math.pi*(i+1)/n;m.beam((.15*math.cos(a),.15*math.sin(a),0),(.15*math.cos(b),.15*math.sin(b),0),.025,.028,'rim')
for a in [math.pi/6,math.pi*5/6,math.pi*1.5]:m.beam((.025*math.cos(a),.025*math.sin(a),0),(.139*math.cos(a),.139*math.sin(a),0),.038,.022,'hub')
m.box((0,0,.016),(.115,.084,.035),'hub',.02)
m=new('rearview_mirror',{'case':'dark','glass':'glass','stem':'steel'});m.box((0,0,0),(.245,.074,.024),'case',.009);m.box((0,0,.014),(.222,.055,.005),'glass',.006);m.beam((0,.02,-.01),(0,.08,-.05),.02,.02,'stem')
m=new('wagon',{'paint':('beige','plain'),'wood':('wood','wood'),'glass':'glass','trim':'dark','tire':('rubber','tire'),'hub':'steel','light':'light','tail':'red','grille':('dark','grille')});# one shaped body with tapered ends and broad, faceted roof
# horizontal rings in Z; body origin on ground; wheels on X axis
m.loft([(-2.10,.71,.20,.04),(-1.94,.84,.25,.05),(-1.47,.88,.29,.05),(.95,.88,.30,.05),(1.88,.84,.26,.05),(2.07,.73,.21,.04)],'paint',axis=2,center=(0,.52,0));
# A-pillars lean rearward, D-pillars slope forward; four planar glass faces.
b=[(-.81,.80,-1.06),(.81,.80,-1.06),(.81,.80,1.80),(-.81,.80,1.80)];t=[(-.69,1.31,-.62),(.69,1.31,-.62),(.69,1.31,1.37),(-.69,1.31,1.37)]
for j in range(4):
 k=(j+1)%4;m.plane([b[j],t[j],t[k],b[k]],'glass');m.beam(b[j],t[j],.055,.045,'paint')
m.box((0,1.325,.375),(1.40,.04,2.02),'paint',.025)
for x in [-.86,.86]:
 m.box((math.copysign(.885,x),.55,.03),(.025,.19,3.32),'wood');
 for z in [-.48,.40,1.20]:m.beam((x*.93,.80,z),(x*.81,1.30,z),.045,.04,'paint')
 for z in [-1.38,1.35]:
  m.cyl((x,.30,z),[(-.10,.29),(.10,.29)],'tire',10,axis=0);m.cyl((x+math.copysign(.108,x),.30,z),[(-.008,.16),(.008,.16)],'hub',8,axis=0)
 for z in [-.14,.78]:m.box((x*1.018,.68,z),(.025,.035,.14),'trim')
 m.box((x,.91,-.67),(.16,.105,.16),'trim',.018)
for z in [-2.08,2.08]:m.box((0,.29,z),(1.54,.15,.18),'trim',.018)
for x in [-.54,.54]:m.box((x,.56,-2.114),(.32,.15,.035),'light',.008);m.box((x,.53,2.082),(.27,.17,.04),'tail',.006)
m.box((0,.51,-2.116),(.69,.16,.03),'grille');m.box((0,.49,2.10),(.34,.11,.018),'light')
m=new('ice_machine',{'shell':'white','front':('cream','ice'),'metal':'steel','dark':'dark'});m.loft([(0,.47,.29,.02),(.08,.48,.30,.02),(.89,.48,.30,.02),(1.17,.46,.24,.02),(1.25,.42,.23,.02)],'shell',front='front');m.box((0,.84,.31),(.38,.04,.035),'metal',.007);m.box((0,.075,.30),(.85,.06,.018),'dark')
m=new('dumpster',{'body':'green','lid':('dark','vents'),'metal':'steel','rust':'red'});m.loft([(.10,.58,.86,.04),(.16,.64,.92,.04),(1.17,.72,.99,.05)],'body');m.box((0,1.20,0),(1.48,.13,2.02),'lid',.035)
for x in [-.67,.67]:
 for z in [-.70,0,.70]:m.box((x,.65,z),(.055,.88,.06),'metal')
for x in [-.52,.52]:
 for z in [-.72,.72]:m.cyl((x,.07,z),[(-.045,.07),(.045,.07)],'metal',6,axis=0)
m=new('roadside_sign',{'sign':('green','route'),'steel':'steel','back':'dark'});m.box((0,1.65,0),(1.9,.78,.075),'back',.012,front='sign');
for x in [-.65,.65]:m.box((x,.75,-.04),(.075,1.50,.075),'steel')
m=new('store_sign',{'sign':('cream','sign'),'steel':'steel','back':'red'});m.box((0,0,0),(2.1,1.25,.14),'back',.025,front='sign');m.box((0,-.52,.08),(1.91,.09,.025),'steel')
# Additional authored modules: small fixtures, road furniture and cockpit details.
m=new('coffee_machine',{'steel':('steel','plain'),'black':'dark','panel':('dark','buttons'),'glass':'brown','handle':'rubber'});m.box((0,.045,0),(.46,.09,.35),'black',.012);m.box((0,.28,-.145),(.46,.47,.07),'steel');m.box((0,.46,0),(.46,.17,.35),'steel',.014,front='panel')
for x in [-.115,.115]:
 m.cyl((x,0,.055),[(.09,.069),(.12,.08),(.22,.065),(.25,.047)],'glass',8);m.cyl((x,0,.055),[(.25,.048),(.268,.052)],'black',8);m.beam((x+.067,.14,.055),(x+.098,.15,.055),.013,.018,'handle');m.beam((x+.098,.15,.055),(x+.084,.23,.055),.013,.018,'handle');m.beam((x+.084,.23,.055),(x+.052,.238,.055),.013,.018,'handle')
m=new('window',{'wood':('wood','wood'),'glass':'glass','fabric':('beige','plaid')});m.box((0,.55,-.025),(1.26,1.06,.055),'glass');m.box((0,.04,0),(1.38,.09,.14),'wood');m.box((0,1.06,0),(1.38,.09,.14),'wood')
for x in [-.65,0,.65]:m.box((x,.55,0),(.065,1.02,.12),'wood')
for x in [-.58,.58]:
 for i in range(4):m.box((x+math.copysign(i*.055,x),.57,.075),(.067,1.0,.045+(.025 if i%2 else 0)),'fabric')
m=new('wiper',{'arm':'steel','rubber':'rubber'});m.beam((0,0,0),(-.19,.12,0),.018,.018,'arm');m.beam((-.19,.12,0),(-.43,.24,0),.015,.014,'arm');m.beam((-.19,.105,.005),(-.59,.30,.005),.025,.016,'rubber')
m=new('car_seat',{'cloth':('blue','plaid'),'edge':('dark','fabric'),'metal':'steel'});m.loft([(.14,.21,.23,.045),(.20,.24,.25,.055),(.29,.23,.24,.06),(.32,.20,.21,.05)],'cloth');m.loft([(.29,.23,.065,.04),(.37,.24,.065,.035),(.73,.21,.06,.04),(.81,.18,.05,.045)],'cloth',center=(0,0,-.20));m.box((0,.87,-.20),(.30,.15,.12),'cloth',.035)
for x in [-.16,.16]:m.box((x,.09,0),(.045,.18,.39),'metal')
m=new('gear_lever',{'boot':'rubber','shaft':'steel','knob':'dark'});m.loft([(0,.092,.085,.012),(.03,.077,.073,.012),(.10,.035,.032,.008)],'boot');m.beam((0,.08,0),(0,.24,-.015),.02,.02,'shaft');m.cyl((0,0,-.015),[(.225,.032),(.24,.045),(.28,.041),(.294,.026)],'knob',8)
m=new('parking_stop',{'concrete':'gold','dark':'steel'});m.loft([(0,.80,.115,.03),(.12,.73,.065,.02)],'concrete');m.box((0,.008,0),(1.55,.016,.20),'dark')
m=new('lamp_post',{'post':'steel','base':'beige','lamp':'dark','lit':'light'});m.box((0,.18,0),(.39,.36,.39),'base',.03);m.loft([(.36,.065,.065,.008),(5.2,.045,.045,.006)],'post');m.beam((0,5.16,0),(0,5.38,.59),.085,.085,'post');m.box((0,5.38,.74),(.33,.12,.62),'lamp',.025);m.box((0,5.312,.74),(.27,.014,.47),'lit',.015)
m=new('fence_segment',{'wood':('wood','wood'),'end':'brown'});
for x in [-1.15,1.15]:m.loft([(0,.075,.07,.008),(1.20,.075,.07,.008),(1.26,.052,.048,.006)],'wood',center=(x,0,0))
for y in [.39,.84]:m.box((0,y,0),(2.30,.15,.055),'wood',.006)
m=new('road_barrier',{'wood':('wood','wood'),'red':'red','paper':'cream'});
for x in [-.56,.56]:
 m.beam((x,0,-.27),(x,.85,0),.065,.065,'wood');m.beam((x,0,.27),(x,.85,0),.065,.065,'wood')
m.box((0,.69,.035),(1.50,.26,.055),'paper',.008)
for x in [-.50,0,.50]:m.plane([(x-.16,.56,.065),(x+.03,.56,.065),(x+.22,.82,.065),(x+.03,.82,.065)],'red')
m=new('payphone',{'case':'steel','panel':('beige','phone'),'black':'dark','sign':'blue'});m.box((0,.28,-.10),(.42,.55,.11),'case',.012)
for x in [-.20,.20]:m.box((x,.28,0),(.04,.55,.25),'case')
m.box((0,.55,0),(.44,.09,.27),'sign');m.box((0,.29,-.025),(.28,.35,.07),'panel',.01);m.box((-.085,.30,.025),(.052,.27,.055),'black',.012);m.beam((-.09,.165,.03),(-.11,.08,.03),.012,.012,'black');m.beam((-.11,.08,.03),(.05,.08,.03),.012,.012,'black')
m=new('curb',{'concrete':'beige','edge':'gold'});m.loft([(0,1.25,.30,.025),(.09,1.25,.30,.025),(.16,1.25,.24,.025)],'concrete',front='edge')
m=new('pine_tree',{'bark':('wood','wood'),'foliage':('green','fabric')});m.cyl((0,0,0),[(0,.13),(4,.08)],'bark',6)
for y,r in [(1.1,1.0),(2.0,.83),(2.8,.61),(3.5,.42)]:m.cyl((0,0,0),[(y,r),(y+.17,r*.9),(y+1.5,.035)],'foliage',6)

if __name__=='__main__':
 manifest=[m.export() for m in assets];(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('Exported',len(manifest),'models,',sum(x['triangles'] for x in manifest),'triangles');print('\n'.join(f"{x['name']}: {x['triangles']} tris" for x in manifest))
