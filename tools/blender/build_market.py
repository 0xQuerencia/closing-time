"""Rebuild original market meshes: blender -b --python tools/blender/build_market.py.
Coordinates below are Godot meters (x, height, z); conversion happens once here.
Beveled fixtures, lathed packaging, UV labels; no external model dependencies.
"""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/models'; OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
r=random.Random(38); mats={}; colliders=[]; group='shell'; batches={}
def mat(name,c,rough=.7,metal=0,texture=None,scale=1,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*c,1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal
 if emission: b.inputs['Emission Color'].default_value=(*c,1);b.inputs['Emission Strength'].default_value=emission
 if texture:
  t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'assets/materials'/f'{texture}.png'));m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color'])
 if texture in ['tile','asphalt','wood']:
  t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'assets/materials'/f'{texture}_rough.png'));t.image.colorspace_settings.name='Non-Color';m.node_tree.links.new(t.outputs['Color'],b.inputs['Roughness'])
  t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'assets/materials'/f'{texture}_normal.png'));t.image.colorspace_settings.name='Non-Color'
  n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.35;m.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],b.inputs['Normal'])
 mats[name]=m;return m
mat('tile',(.5,.47,.41),.52,texture='tile');mat('ceiling',(.7,.68,.6),.94,texture='ceiling');mat('plaster',(.6,.57,.48),texture='plaster');mat('brick',(.3,.24,.18),texture='brick')
mat('asphalt',(.1,.12,.13),.27,texture='asphalt');mat('wood',(.29,.21,.14),.56,texture='wood')
for n,c,rough,metal in [('shelf',(.32,.38,.37),.52,.35),('steel',(.38,.4,.39),.3,.8),('dark',(.025,.032,.029),.7,.1),('cream',(.68,.65,.53),.65,0),('paper',(.75,.72,.62),.9,0),('red',(.36,.065,.035),.6,0),('cardboard',(.37,.25,.13),.94,0),('yellow',(.68,.51,.18),.7,0),('car',(.6,.6,.54),.4,.45),('rubber',(.018,.021,.02),.95,0),('car_glass',(.025,.05,.065),.16,.6),('green',(.1,.2,.13),.6,.25)]:mat(n,c,rough,metal)
mat('tube',(.85,.82,.65),.5,emission=3);mat('taillight',(.9,.05,.04),.4,emission=1.8);mat('laser',(.9,.1,.08),.4,emission=2.2);mat('screen',(.12,.24,.21),.4,emission=.7);mat('packaging',(1,1,1),.6,texture='packaging')
for i,c in enumerate([(132,60,39),(167,137,67),(131,47,35),(48,94,101),(82,65,44),(79,103,58),(188,150,71),(56,92,115),(80,54,42),(91,116,130),(166,94,36),(66,100,67),(132,119,96),(130,59,40),(97,73,44),(165,133,76)]):mat('pack%d'%i,tuple(v/255 for v in c),.53)
for n in ['register','cctv_standby','coffee_poster','shipping','price']:mat(n,(1,1,1),.65,texture=n)
for n in ['register','cctv_standby']:
 b=mats[n].node_tree.nodes.get('Principled BSDF');t=next(n for n in mats[n].node_tree.nodes if n.type=='TEX_IMAGE');mats[n].node_tree.links.new(t.outputs['Color'],b.inputs['Emission Color']);b.inputs['Emission Strength'].default_value=.5

def xyz(p):return (p[0],-p[2],p[1])
def register(o,name,material):
 o.name=name;o.data.materials.append(mats[material]);batches.setdefault(group,[]).append(o);return o
def box(name,p,s,m,bevel=0,collision=False,uvscale=1):
 sx,sy,sz=s[0]/2,s[2]/2,s[1]/2
 vs=[(x,y,z) for x in [-sx,sx] for y in [-sy,sy] for z in [-sz,sz]]
 fs=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
 if bevel:
  bm=bmesh.new();bm.from_mesh(me);bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=2,affect='EDGES');bm.to_mesh(me);bm.free()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.location=xyz(p)
 if m in ['tile','ceiling','asphalt','plaster','brick','wood']:
  me.uv_layers.new()
  for poly in me.polygons:
   axis=max(range(3),key=lambda a:abs(poly.normal[a]));axes=[a for a in range(3) if a!=axis]
   for li in poly.loop_indices:
    v=me.vertices[me.loops[li].vertex_index].co+o.location
    me.uv_layers.active.data[li].uv=(v[axes[0]]/uvscale,v[axes[1]]/uvscale)
 register(o,name,m)
 if collision:colliders.append({'name':name,'p':p,'s':s})
 return o
def cyl(name,p,radius,depth,m,vertices=16,axis='y'):
 vs=[]
 for h in [-depth/2,depth/2]:
  for j in range(vertices):
   a=j*math.tau/vertices;v=(radius*math.cos(a),radius*math.sin(a),h)
   if axis=='x':v=(h,v[0],v[1])
   if axis=='z':v=(v[0],h,v[1])
   vs.append(v)
 fs=[tuple(reversed(range(vertices))),tuple(range(vertices,vertices*2))]
 fs += [(j,(j+1)%vertices,(j+1)%vertices+vertices,j+vertices) for j in range(vertices)]
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.location=xyz(p)
 for f in me.polygons:f.use_smooth=len(f.vertices)==4
 return register(o,name,m)
def lathe(name,p,profile,m,vertices=20):
 # Profile is a closed radial cross-section in meters; retain crisp horizontal rims.
 vs=[xyz((p[0]+radius*math.cos(j*math.tau/vertices),p[1]+h,p[2]+radius*math.sin(j*math.tau/vertices))) for h,radius in profile for j in range(vertices)]
 fs=[]
 for ring in range(len(profile)-1):
  for j in range(vertices):fs.append((ring*vertices+j,(ring+1)*vertices+j,(ring+1)*vertices+(j+1)%vertices,ring*vertices+(j+1)%vertices))
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 for f in me.polygons:
  ring=f.index//vertices
  f.use_smooth=abs(profile[ring+1][0]-profile[ring][0])>.001
 return register(o,name,m)
def tube_path(name,points,radius,m,vertices=8):
 vs=[]
 for i,p in enumerate(points):
  tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
  tangent.normalize();normal=tangent.cross(Vector((0,0,1))).normalized();binormal=tangent.cross(normal).normalized()
  for j in range(vertices):vs.append(xyz(Vector(p)+radius*(normal*math.cos(j*math.tau/vertices)+binormal*math.sin(j*math.tau/vertices))))
 fs=[tuple(reversed(range(vertices)))]
 for i in range(len(points)-1):
  for j in range(vertices):fs.append((i*vertices+j,i*vertices+(j+1)%vertices,(i+1)*vertices+(j+1)%vertices,(i+1)*vertices+j))
 fs.append(tuple(range((len(points)-1)*vertices,len(points)*vertices)))
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 return register(o,name,m)
def label(p,w,h,index,side=1):
 # Front-facing UV rectangle, atlas cell inset prevents bleeding.
 x,y,z=p;verts=[xyz((x-w/2,y-h/2,z)),xyz((x+w/2,y-h/2,z)),xyz((x+w/2,y+h/2,z)),xyz((x-w/2,y+h/2,z))]
 me=bpy.data.meshes.new('Printed label');me.from_pydata(verts,[],[(0,1,2,3)] if side==1 else [(3,2,1,0)]);me.uv_layers.new()
 u=(index%4)/4;v=1-(index//4+1)/4;uv=[(u+.006,v+.006),(u+.244,v+.006),(u+.244,v+.244),(u+.006,v+.244)]
 for poly in me.polygons:
  for li in poly.loop_indices:me.uv_layers.active.data[li].uv=uv[me.loops[li].vertex_index]
 o=bpy.data.objects.new('Fictional product print',me);bpy.context.collection.objects.link(o);register(o,'Fictional product print','packaging')
def wrap_label(x,y,z,radius,height,index,arc=1.05):
 vs=[];segments=12
 for h in [-height/2,height/2]:
  for j in range(segments+1):
   a=-arc+j*2*arc/segments;vs.append(xyz((x+math.sin(a)*radius,y+h,z+math.cos(a)*radius)))
 fs=[(j,j+1,j+segments+2,j+segments+1) for j in range(segments)]
 me=bpy.data.meshes.new('Curved printed label');me.from_pydata(vs,[],fs);me.uv_layers.new();u=index%4/4;v=1-(index//4+1)/4
 for poly in me.polygons:
  for li in poly.loop_indices:
   vi=me.loops[li].vertex_index;me.uv_layers.active.data[li].uv=(u+.006+(vi%(segments+1))/segments*.238,v+.006+(vi//(segments+1))*.238)
 o=bpy.data.objects.new('Curved printed label',me);bpy.context.collection.objects.link(o);register(o,'Curved printed label','packaging')
def pillow_bag(x,y,z,index):
 vs=[]
 for h,w,d in [(0,.085,.018),(.04,.098,.043),(.16,.099,.06),(.28,.09,.035),(.32,.087,.012)]:
  for j in range(8):
   a=j*math.tau/8;vs.append(xyz((x+math.cos(a)*w,y+h,z+math.sin(a)*d)))
 fs=[tuple(reversed(range(8)))]
 for ring in range(4):
  for j in range(8):fs.append((ring*8+j,ring*8+(j+1)%8,(ring+1)*8+(j+1)%8,(ring+1)*8+j))
 fs.append(tuple(range(32,40)));me=bpy.data.meshes.new('Shaped foil bag');me.from_pydata(vs,[],[tuple(reversed(face)) for face in fs])
 o=bpy.data.objects.new('Shaped foil bag',me);bpy.context.collection.objects.link(o);register(o,'Shaped foil bag','pack%d'%index)
 me.materials.append(mats['packaging']);me.uv_layers.new()
 u=index%4/4;v=1-(index//4+1)/4
 for poly in me.polygons:
  if 1<=poly.index<=32 and (poly.index-1)%8<4:
   poly.material_index=1
   for li in poly.loop_indices:
    vi=me.loops[li].vertex_index;ring,j=divmod(vi,8)
    me.uv_layers.active.data[li].uv=(u+.006+(.5+.5*math.cos(j*math.tau/8))*.238,v+.006+[0,.125,.5,.875,1][ring]*.238)

def art_panel(p,w,h,material,angle=0):
 me=bpy.data.meshes.new('Printed artwork');me.from_pydata([xyz((-w/2,-h/2,0)),xyz((w/2,-h/2,0)),xyz((w/2,h/2,0)),xyz((-w/2,h/2,0))],[],[(0,1,2,3)]);me.uv_layers.new()
 for li,uv in enumerate([(0,0),(1,0),(1,1),(0,1)]):me.uv_layers.active.data[li].uv=uv
 o=bpy.data.objects.new('Printed '+material,me);bpy.context.collection.objects.link(o);o.location=xyz(p);o.rotation_euler[2]=angle;register(o,'Printed '+material,material)
 return o

def product(x,y,z,kind,idx,side=1):
 # Keep each fictional label on a plausible container (no water in foil snack bags).
 labels={'bag':[0,1,7,14,15],'can':[2,10,11,13],'bottle':[3,5,9,10,11],'box':[1,4,6,8,12,13,15]}
 choices=labels[kind];idx=choices[idx%len(choices)]
 if kind=='can':
  lathe('Pressed tin body',(x,y,z),[(0,0),(.003,.059),(.014,.065),(.025,.067),(.207,.067),(.22,.064),(.228,.064),(.228,0)],'pack%d'%idx,16)
  for h in [.008,.226]:
   lathe('Rolled tin seam',(x,y+h,z),[(-.004,.063),(-.004,.068),(0,.07),(.004,.068),(.004,.063)],'steel',16)
  cyl('Recessed tin lid',(x,y+.23,z),.061,.003,'steel',16)
  wrap_label(x,y+.118,z,.0675,.185,idx)
 elif kind=='bottle':
  lathe('Contoured drink bottle',(x,y,z),[(0,0),(.004,.048),(.012,.06),(.026,.064),(.21,.064),(.235,.06),(.257,.047),(.28,.026),(.305,.024),(.305,0)],'green',16)
  lathe('Bottle foot moulding',(x,y,z),[(.016,.061),(.02,.066),(.027,.066),(.031,.064)],'green',16)
  lathe('Screw cap',(x,y,z),[(.299,0),(.299,.028),(.304,.029),(.329,.029),(.334,.025),(.334,0)],'cream',16)
  cyl('Tamper seal',(x,y+.296,z),.027,.008,'cream',16)
  for j in range(12):
   angle=j*math.tau/12
   cyl('Cap grip',(x+.029*math.cos(angle),y+.316,z+.029*math.sin(angle)),.0015,.021,'cream',6)
  wrap_label(x,y+.127,z,.0645,.16,idx)
 elif kind=='bag':
  pillow_bag(x,y,z,idx)
  for h in [.008,.313]:
   box('Crimped foil seal',(x,y+h,z),(.176,.014,.025),'pack%d'%idx,.002)
   for j in range(8):box('Seal pleat',(x-.075+j*.021,y+h,z+side*.014),(.003,.012,.003),'pack%d'%idx)
 else:
  box('Carton',(x,y+.18,z),(.18,.36,.13),'pack%d'%idx,.004)
  label((x,y+.18,z+side*.066),.175,.345,idx,side)
  box('Folded carton lid',(x,y+.359,z),(.172,.003,.12),'pack%d'%idx,.001)
  box('Carton tuck seam',(x,y+.361,z+.032),(.169,.001,.0015),'cardboard')
  box('Carton side fold',(x+.091,y+.18,z-.049),(.001,.34,.003),'cardboard')
# Shell: retail 12.5m wide, staff wing 5.5m; 18x12m total.
box('Sales floor',(0,-.11,0),(18,.22,12),'tile',collision=True,uvscale=2.4)
box('Ceiling',(0,3.24,0),(18,.1,12),'ceiling',uvscale=2.4)
for x in [-9,9]:box('Side wall',(x,1.6,0),(.22,3.2,12),'plaster',collision=True,uvscale=2)
for x,w in [(-2.65,12.7),(6.9,4.2)]:box('Rear masonry',(x,1.6,-6),(w,3.2,.22),'plaster',collision=True,uvscale=2)
box('Rear doorway header',(4.25,2.7,-6),(1.1,1,.22),'plaster',collision=True)
# Front glazing spans retail; solid staff facade.
box('Front knee wall',(-3, .3,6),(12,.6,.2),'brick',collision=True,uvscale=2)
# Open entrance x1.2..2.4. Remove knee wall there by shortened glazing boundary at x.5.
colliders.pop()
# Replace knee wall with geometry split for the entrance.
o=bpy.data.objects.get('Front knee wall');batches[group].remove(o);bpy.data.objects.remove(o,do_unlink=True)
box('Window base',(-4.05,.3,6),(9.9,.6,.2),'brick',collision=True,uvscale=2)
box('Door right base',(3,.3,6),(1.2,.6,.2),'brick',collision=True,uvscale=2)
box('Front lintel',(0,2.96,6),(18,.5,.25),'plaster',collision=True)
box('Staff facade',(6.3,1.5,6),(5.4,3,.25),'brick',collision=True,uvscale=2)
for x in [-8.9,-6.5,-4.1,-1.7,.9,2.5,3.5]:box('Window mullion',(x,1.68,6),(.055,2.15,.08),'steel',.008)
for y in [.61,2.73]:box('Glazing rail',(-2.7,y,6),(12.5,.045,.08),'steel')
box('Entrance threshold',(1.7,.015,6),(1.55,.03,.28),'steel')
box('Entry mat',(1.7,.013,5.1),(1.5,.022,1.15),'rubber',.02)
# Internal staff partition with open doorways, frames and a real corridor.
for z,l in [(-5.55,.9),(-2.3,3.3),(3.3,5.4)]:box('Retail staff partition',(3.5,1.6,z),(.13,3.2,l),'plaster',collision=True,uvscale=2)
for z in [-4.3,0]:
 box('Staff doorway header',(3.5,2.7,z),(.13,1,1.2),'plaster',collision=True)
 for dz in [-.58,.58]:box('Door jamb',(3.5,1.1,z+dz),(.19,2.2,.065),'wood',.008)
# Office on right, 3.9 x 3.5; stockroom below.
for z,l in [(-5.55,.9),(-3.1,1.25),(-1.55,1.7),(2.85,4.5)]:box('Corridor partition',(5,1.6,z),(.12,3.2,l),'plaster',collision=True,uvscale=2)
box('Office entry header',(5,2.7,-4.3),(.12,1,1.25),'plaster',collision=True)
box('Office divider',(7,1.6,-2.45),(4,3.2,.13),'plaster',collision=True,uvscale=2)
# Office, rear and front doors are runtime Door objects (gameplay/security/door.gd).
# Rear steel door and push bar are runtime Door objects (gameplay/security/door.gd).
for x in [3.7,4.8]:box('Rear door frame',(x,1.1,-5.94),(.075,2.2,.1),'steel',.008)
box('Rear frame header',(4.25,2.21,-5.94),(1.17,.075,.1),'steel',.008)
# Baseboards and wainscot.
for x in [-8.86,3.4,8.86]:box('Skirting',(x,.08,0),(.035,.16,11.7),'wood')
box('Rear skirting',(-2.8,.08,-5.86),(12.1,.16,.04),'wood')
# Fluorescent ceiling practicals.
for x in [-6,-2,1.4,6.9]:
 for z in [-3.8,.1,3.6] if x<3 else [-4,1.5]:
  box('Fluorescent housing',(x,3.13,z),(.29,.10,1.28),'steel',.018)
  for dx in [-.075,.075]:box('Fluorescent diffuser',(x+dx,3.066,z),(.065,.035,1.16),'tube',.015)
# Entrance leaves are runtime Door objects (gameplay/security/door.gd).
# Checkout with toe kick, laminate edge, panelled front and equipment.
group='retail'
box('Checkout carcass',(-6,.43,4.25),(4.1,.86,.8),'wood',.035,True,uvscale=1.5)
box('Countertop',(-6,.91,4.25),(4.25,.09,.96),'cream',.035)
box('Counter toe kick',(-6,.08,3.82),(3.9,.15,.045),'dark')
for x in [-7.4,-6,-4.6]:box('Counter front inset',(x,.46,3.839),(1.2,.56,.018),'wood',.018)
box('Cash drawer',(-5.8,1.005,4.3),(.48,.12,.43),'dark',.02)
box('Receipt printer',(-6.4,1.08,4.25),(.21,.22,.27),'cream',.03)
box('Printer mouth',(-6.4,1.155,4.395),(.15,.018,.009),'dark')
box('Printer lid',(-6.4,1.195,4.25),(.225,.03,.285),'dark',.008)
cyl('Paper roll',(-6.4,1.255,4.21),.052,.15,'paper',20,'x')
box('Printer LED',(-6.4,1.115,4.387),(.012,.012,.006),'tube')
box('Receipt curl',(-6.4,1.17,4.48),(.1,.003,.16),'paper')
box('Scanner pedestal',(-5.1,1,4.25),(.18,.07,.15),'dark',.02)
cyl('Scanner upright',(-5.1,1.1,4.25),.026,.17,'dark')
box('Scanner head',(-5.1,1.23,4.25),(.12,.09,.16),'dark',.02)
box('Scanner lens',(-5.1,1.23,4.159),(.08,.025,.005),'laser')
box('Scanner window',(-5.1,1.279,4.25),(.095,.006,.11),'laser')
box('Card reader',(-4.7,1.04,3.96),(.14,.11,.22),'dark',.02)
for j in range(4):
 for k in range(3):box('Terminal key',(-4.74+k*.04,1.099,3.92+j*.035),(.025,.005,.023),'cream',.003)
cyl('Clerk coffee cup',(-7.6,1.03,4.5),.045,.16,'paper',24)
cyl('Cup lid',(-7.6,1.116,4.5),.048,.015,'dark',24)
for j in range(3):
 o=box('Loose receipt',(-7.2+j*.035,.959+j*.002,4.3+j*.02),(.07,.002,.17),'paper');o.rotation_euler[2]=j*.12
# Small, contained impulse rack: wrapped sweets and gum beside the scanner.
# Keep its footprint inside the counter and clear of the customer's scan area.
box('Counter impulse tray',(-7.03,1.035,4.62),(.42,.15,.43),'red',.025)
for x in [-7.22,-6.84]:box('Counter tray divider',(x,1.12,4.62),(.018,.16,.4),'cream',.006)
for row in range(2):
 for j in range(3):
  idx=(row*3+j+2)%16;x=-7.15+j*.12;z=4.50+row*.19
  box('Counter gum pack',(x,1.19,z),(.092,.16,.045),'pack%d'%idx,.006)
  label((x,1.19,z+.024),.084,.125,idx)
# A restrained service label and card-reader receipt slot make the transaction
# hardware read as a small-town checkout instead of a plain black block.
box('Card reader display',(-4.7,1.11,3.845),(.095,.045,.008),'screen',.006)
box('Card reader slot',(-4.7,1.135,3.832),(.042,.004,.003),'dark')
# 3 gondolas, shelves 1.72m high. Irregular stock in coherent brand runs.
for ai,x in enumerate([-6,-3,0]):
 box('Gondola base',(x,.12,-.9),(.91,.24,4.9),'shelf',.025,True)
 colliders[-1]['p']=(x,.9,-.9);colliders[-1]['s']=(.91,1.8,4.9)
 box('Gondola spine',(x,.9,-.9),(.055,1.6,4.8),'shelf',.01)
 for z in [-3.28,1.48]:box('Upright',(x,.91,z),(.08,1.8,.065),'steel',.009)
 box('Aisle sign board',(x,2.04,1.51),(1.02,.24,.045),'green',.012)
 for dx in [-.35,.35]:box('Aisle sign bracket',(x+dx,1.85,1.48),(.018,.3,.025),'steel')
 for side in [-1,1]:
  # Products face along x; rotate all generated stock around aisle pivot.
  for level,h in enumerate([.28,.68,1.08,1.48]):
   box('Shelf pan',(x+side*.23,h,-.9),(.46,.035,4.85),'shelf',.008)
   box('Price rail',(x+side*.455,h+.018,-.9),(.025,.055,4.84),'cream',.004)
   for j in range(19):
    if r.random()<.22 or (level==2 and 5<j<9):continue
    z=-3.1+j*.241+r.uniform(-.012,.012)
    start=len(batches[group]);product(0,h+.02,r.uniform(-.045,.04),['bag','box','can'][ai],(ai*4+level+(1 if j>12 else 0))%16)
    # Default front is +z. Rotate front to aisle's side x.
    for o in batches[group][start:]:
     old=o.location.copy();ang=side*math.pi/2
     o.location=(x+side*.25+old.x*math.cos(ang)-old.y*math.sin(ang),-z+old.x*math.sin(ang)+old.y*math.cos(ang),old.z)
     o.rotation_euler[2]+=ang
   for z in [-2.8,-1.5,-.2,1.1]:art_panel((x+side*.472,h+.02,z),.19,.041,'price',side*math.pi/2)
# End-cap displays at the front of each gondola (own RNG so existing stock layout is unchanged).
r2=random.Random(91)
for ai,x in enumerate([-6,-3,0]):
 box('End cap base',(x,.2,1.98),(.92,.4,.5),'red',.02,True)
 colliders[-1]['p']=(x,.2,1.98);colliders[-1]['s']=(.92,.4,.5)
 box('End cap lip',(x,.42,2.24),(.92,.06,.03),'cream',.006)
 for row in range(3):
  for j in range(4):
   if row==2 and j in (0,3):continue
   product(x-.33+j*.22+r2.uniform(-.01,.01)+(.11 if row==1 else 0)*0,.4+row*.37,1.98+r2.uniform(-.03,.03),'box',(ai*5+row*3+j*2+7)%16)
box('Cooler sign backing',(-3.2,2.53,-5.1),(9.45,.32,.06),'green',.015)
# Cooler row across back wall: frame, stock, transparent glass supplied in Godot.
for i in range(6):
 x=-7.1+i*1.57
 box('Cooler cabinet',(x,1.17,-5.45),(1.52,2.34,.9),'dark',.025,True)
 box('Cooler interior',(x,1.2,-4.982),(1.38,1.95,.025),'cream')
 for h in [.34,.78,1.22,1.66]:
  box('Cooler rack',(x,h,-4.88),(1.37,.025,.34),'steel',.004)
  for j in range(6):product(x-.56+j*.22,h+.02,-4.86,'bottle',(i+3)%12)
 for dx in [-.736,.736]:box('Fridge stile',(x+dx,1.17,-4.69),(.045,2.31,.06),'steel',.008)
 for h in [.09,2.28]:box('Fridge crossbar',(x,h,-4.69),(1.47,.05,.07),'steel',.008)
 box('Cooler handle',(x+.59,1.2,-4.62),(.025,.56,.07),'steel',.009)
 box('Cooler light',(x-.68,1.2,-4.73),(.025,1.9,.03),'tube',.006)
# Coffee station left wall behind aisle.
box('Coffee cabinet',(-8.35,.46,-.6),(.9,.92,2.2),'wood',.02,True)
box('Coffee worktop',(-8.33,.95,-.6),(1,.055,2.3),'cream',.02)
mat('coffee_glass',(.23,.14,.07),.24,.05)
mat('appliance_metal',(.39,.41,.38),.42,.35)
for z in [-1.3,-.6]:
 box('Coffee warmer base',(-8.33,.997,z),(.47,.04,.43),'dark',.018)
 cyl('Warmer inset',(-8.23,1.021,z),.105,.012,'steel',24)
 box('Coffee tower',(-8.55,1.27,z),(.16,.56,.38),'appliance_metal',.025)
 box('Coffee head',(-8.37,1.51,z),(.46,.15,.4),'cream',.03)
 box('Coffee fascia',(-8.131,1.51,z),(.012,.105,.34),'red',.009)
 for k in [-1,1]:
  cyl('Coffee rocker switch',(-8.12,1.515,z+k*.095),.015,.012,'dark',12,'x')
 cyl('Coffee ready lamp',(-8.12,1.48,z),.007,.013,'tube',8,'x')
 lathe('Brew basket',(-8.23,1.365,z),[(0,.06),(.025,.082),(.065,.088),(.07,0)],'dark',20)
 cyl('Coffee spout',(-8.23,1.352,z),.012,.03,'steel',12)
 lathe('Rounded coffee carafe',(-8.23,1.03,z),[(0,0),(.008,.066),(.025,.09),(.055,.102),(.13,.1),(.17,.08),(.19,.057),(.205,.057),(.205,0)],'coffee_glass',24)
 lathe('Carafe base band',(-8.23,1.03,z),[(.005,.065),(.012,.085),(.024,.09),(.028,.089)],'steel',24)
 lathe('Carafe lid',(-8.23,1.03,z),[(.197,0),(.197,.064),(.209,.068),(.219,.054),(.222,0)],'dark',24)
 tube_path('Carafe open handle',[(-8.175,1.23,z),(-8.10,1.23,z),(-8.073,1.205,z),(-8.073,1.125,z),(-8.10,1.10,z),(-8.14,1.10,z)],.013,'dark')
 box('Carafe collar',(-8.17,1.221,z),(.045,.025,.038),'dark',.008)
for j in range(5):
 z=.05+j*.1
 lathe('Tapered paper cup',(-8.2,.978,z),[(0,0),(0,.029),(.125,.042),(.129,.043),(.132,.042),(.132,.038),(.125,.038),(.006,.025),(.006,0)],'paper',16)
 for h in [.08,.093,.106]:
  radius=.029+h*.1
  lathe('Nested cup rim',(-8.2,.978,z),[(h,radius),(h+.003,radius+.002),(h+.005,radius)],'paper',16)
art_panel((-8.875,1.98,-.6),.43,.58,'coffee_poster',math.pi/2)
for y in [1.7,2.26]:
 for z in [-.79,-.41]:box('Poster tape',(-8.867,y,z),(.008,.04,.075),'cream')
# Office furniture and stockroom.
group='backrooms'
# A working ceiling fluorescent over the inventory aisle, distinct from the
# darker rear office and active only while the store circuit has power.
box('Stockroom fluorescent housing',(6.9,3.13,3.0),(.25,.09,1.05),'steel',.014)
for dx in [-.06,.06]:box('Stockroom fluorescent diffuser',(6.9+dx,3.075,3.0),(.045,.025,.94),'tube',.01)
# Keep the desk collision in the original footprint while using a sourced model for its visuals.
colliders.append({'name':'Office desk','p':[7.6,.74,-5.25],'s':[2.1,.075,.75]})
for x in [6.7,8.5]:colliders.append({'name':'Desk leg','p':[x,.37,-5.25],'s':[.065,.74,.62]})
colliders.append({'name':'Chair seat','p':[7.6,.5,-4.22],'s':[.45,.08,.44]})
box('Notice board',(8.89,1.65,-3.6),(.035,.8,1.2),'cardboard',.02)
for z in [-3.9,-3.4]:box('Pinned notice',(8.86,1.7,z),(.005,.32,.23),'paper')
for z in [-1.2,1.5,4.5]:
 box('Stock rack base',(8.3,.1,z),(1.2,.2,1.9),'shelf',.015,True)
 for x in [7.75,8.85]:
  for zz in [z-.85,z+.85]:box('Stock rack upright',(x,1.2,zz),(.055,2.4,.055),'steel',.007)
 for y in [.25,1,1.75]:
  box('Stock rack shelf',(8.3,y,z),(1.2,.045,1.9),'wood',.01)
  for j in range(3):
   if r.random()<.2:continue
   zz=z-.6+j*.58
   # Alternate case sizes and rotate a few labels to break up the repeated
   # identical-box pattern while keeping each carton securely on its shelf.
   width,depth,height=[(.72,.46,.42),(.82,.50,.48),(.62,.44,.38)][(j+int(y*10)+int(z))%3]
   cx=8.25+(-.035 if j==1 else .025 if j==2 else 0)
   cy=y+height/2+.045
   box('Sealed carton',(cx,cy,zz),(width,height,depth),'cardboard',.018)
   box('Packing tape',(cx,cy+height/2+.004,zz),(.085,.006,depth*.96),'cream',.002)
   # Folded top flaps and a narrow case seam catch the overhead practicals.
   box('Carton top seam',(cx,cy+height/2+.006,zz),(.012,.004,depth*.92),'cardboard')
   art_panel((cx-width/2-.004,cy,zz),.24,.15,'shipping',-math.pi/2)
box('Breaker box',(4.91,1.52,2.8),(.13,.55,.35),'shelf',.018)
for z in [2.69,2.78,2.87]:box('Breaker switch',(4.829,1.5,z),(.025,.065,.04),'dark')
# Low-key evidence of a working shift: wall clock, bin, cup, floor carton.
cyl('Clock rim',(6.4,2.35,-5.85),.17,.035,'dark',32,'z')
cyl('Clock dial',(6.4,2.35,-5.825),.151,.008,'paper',32,'z')
box('Clock minute hand',(6.4,2.4,-5.817),(.008,.1,.005),'dark')
box('Clock hour hand',(6.35,2.35,-5.816),(.1,.008,.005),'dark')
cyl('Wastebasket',(8.6,.22,-5.3),.17,.43,'dark',24)
box('Open delivery carton',(5.75,.18,1.35),(.6,.36,.43),'cardboard',.01,True)
for x in [5.43,6.07]:
 o=box('Carton flap',(x,.4,1.35),(.23,.018,.43),'cardboard');o.rotation_euler[1]=-.35 if x<5.75 else .35
# Mop bucket and angled handle.
cyl('Mop bucket',(5.8,.19,4.4),.22,.36,'yellow');o=cyl('Mop handle',(5.9,.9,4.4),.018,1.6,'wood');o.rotation_euler[1]=.16
box('Inventory table',(6,.76,2.9),(1.2,.07,.65),'wood',.02,True)
for x in [5.5,6.5]:box('Table leg',(x,.38,2.9),(.06,.76,.5),'steel',.006)
box('Inventory sheet',(6,.801,2.9),(.25,.003,.32),'paper')
# Working stockroom details: hand truck parked beside the inventory table,
# with rubber wheels, a toe plate, solid uprights and a curved grip.
box('Hand truck toe plate',(6.63,.09,.52),(.48,.045,.36),'steel',.025)
for x in [6.43,6.83]:
 box('Hand truck rail',(x,.67,.33),(.035,1.18,.045),'steel',.014)
 cyl('Hand truck wheel',(x,.16,.31),.145,.065,'rubber',16,'x')
 cyl('Hand truck hub',(x+(-.034 if x<6.6 else .034),.16,.31),.045,.008,'steel',12,'x')
for y in [.43,.78,1.05]:box('Hand truck crossbar',(6.63,y,.33),(.43,.035,.04),'steel',.012)
tube_path('Hand truck grip',[(6.43,1.25,.33),(6.43,1.32,.33),(6.83,1.32,.33),(6.83,1.25,.33)],.025,'dark')
# A small open picking carton on the inventory table, with folded flaps and
# three visible cans to suggest the active restock chore.
box('Open picking carton',(6,.84,2.82),(.4,.12,.48),'cardboard',.012)
for x,ang in [(5.79,-.34),(6.21,.34)]:
 flap=box('Picking carton flap',(x,.92,2.82),(.025,.012,.46),'cardboard',.004);flap.rotation_euler[1]=ang
for index,z in enumerate([2.67,2.82,2.97]):
 lathe('Restock tin',(6,.79,z),[(0,0),(.003,.036),(.01,.04),(.11,.04),(.12,.038),(.12,0)],'pack%d'%[2,10,13][index],16)
 cyl('Restock tin lid',(6,.911,z),.037,.003,'steel',16)
 wrap_label(6,.845,z,.0405,.075,[2,10,13][index],.9)
# Exterior pavement and bounded lot; road + modest terrain silhouettes.
group='exterior'
box('Parking asphalt',(0,-.23,15),(28,.22,18),'asphalt',collision=True,uvscale=3)
box('Sidewalk',(0,-.08,7),(20,.16,1.8),'plaster',.04,True,uvscale=2)
# Accessible curb ramp connects the parking surface to the entry sidewalk.
pts=[(.9,-.12,7.9),(2.5,-.12,7.9),(2.5,-.12,9.15),(.9,-.12,9.15),(.9,0,7.9),(2.5,0,7.9)]
me=bpy.data.meshes.new('Curb ramp');me.from_pydata([xyz(p) for p in pts],[],[(0,3,2,1),(0,1,5,4),(0,4,3),(1,2,5),(4,5,2,3)]);me.update()
o=bpy.data.objects.new('Curb ramp',me);bpy.context.collection.objects.link(o);register(o,'Curb ramp','plaster')
colliders.append({'name':'Curb ramp','points':pts})
box('Side pavement',(10.1,-.1,0),(2,.16,14),'asphalt',collision=True,uvscale=3)
box('Rear loading pad',(4,-.07,-7),(4,.18,2),'plaster',.025,True)
box('Surrounding ground',(0,-.32,0),(90,.15,90),'dark',collision=True)
box('Road',(0,-.205,26),(65,.1,7),'asphalt',uvscale=4)
for x in range(-30,32,8):box('Road dashed line',(x,-.147,26),(3,.005,.1),'paper')
for x in [-7,-4,-1,2]:box('Parking stripe',(x,-.111,12),(.095,.008,4.8),'cream')
for x in [-5.5,-2.5,.5]:box('Wheel stop',(x,-.01,9.65),(1.6,.19,.16),'plaster',.035,True)
# Fascia, canopy and practical fascia sign.
box('Canopy',(0,3.3,6.5),(18.7,.2,1.5),'cream',.025)
box('Fascia',(0,3.62,6.95),(18.7,.6,.15),'green',.02)
for x in [-8.5,8.5]:box('Canopy column',(x,1.6,7),(.16,3.2,.16),'cream',.01,True)
# Fascia gooseneck sign lamps.
for x in [-4,3]:
 cyl('Sign lamp stem',(x,4.03,7.18),.018,.34,'steel')
 box('Sign lamp arm',(x,4.18,7.43),(.035,.035,.5),'steel',.01)
 box('Sign lamp hood',(x,4.12,7.68),(.28,.12,.18),'green',.025)
# Car: tapered body mesh, glass cabin, wheel arches suggested by fenders.
def hull(name,levels,m):
 vs=[]
 for y,w,z0,z1 in levels:vs.extend([xyz((-4.9-w/2,y,z0)),xyz((-4.9+w/2,y,z0)),xyz((-4.9+w/2,y,z1)),xyz((-4.9-w/2,y,z1))])
 fs=[(3,2,1,0)]
 for k in range(len(levels)-1):
  for j in range(4):fs.append((k*4+j,k*4+(j+1)%4,(k+1)*4+(j+1)%4,(k+1)*4+j))
 fs.append(tuple(range((len(levels)-1)*4,len(levels)*4)))
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);register(o,name,m)
 mod=o.modifiers.new('Body seams softened','BEVEL');mod.width=.055;mod.segments=3;bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)
hull('Compact body',[(.22,1.54,11,15.1),(.72,1.7,10.95,15.12),(.84,1.59,11.15,14.95)],'car')
hull('Cabin glass',[(.79,1.48,11.9,14.3),(1.38,1.25,12.4,13.92)],'car_glass')
box('Car roof',(-4.9,1.4,13.15),(1.31,.07,1.56),'car',.045)
for x in [-5.68,-4.12]:
 box('B pillar',(x,1.1,13.24),(.06,.59,.1),'car')
 for z in [11.74,14.29]:
  cyl('Tire',(x,.29,z),.31,.18,'rubber',24,'x');cyl('Hubcap',(x+(-.1 if x<-4.9 else .1),.29,z),.19,.018,'steel',16,'x')
 for z in [12.7,13.7]:box('Car door handle',(x,.77,z),(.04,.04,.19),'steel',.012)
box('Car front bumper',(-4.9,.38,15.13),(1.55,.18,.12),'dark',.035)
for x in [-5.46,-4.34]:box('Headlamp',(x,.65,15.14),(.38,.15,.02),'cream',.03)
box('Car rear bumper',(-4.9,.38,10.97),(1.55,.18,.12),'dark',.035)
for x in [-5.48,-4.32]:box('Tail light',(x,.65,10.955),(.3,.14,.02),'taillight',.02)
box('License plate',(-4.9,.52,15.205),(.32,.13,.012),'paper')
colliders.append({'name':'Parked compact','p':[-4.9,.6,13],'s':[1.8,1.4,4.3]})
for x,z in [(-10,15),(11,23)]:
 cyl('Light pole',(x,2.7,z),.065,5.6,'steel');box('Pole base',(x,.18,z),(.38,.5,.38),'plaster',.03,True)
 box('Pole arm',(x+.5,5.4,z),(1,.08,.08),'steel',.02);box('Street lamp',(x+1,5.37,z),(.48,.13,.32),'dark',.04);box('Lamp lens',(x+1,5.29,z),(.4,.025,.25),'tube',.02)
# Side dumpster with lid hinge and bins.
box('Dumpster',(10.5,.65,-3.7),(1.4,1.3,2),'green',.07,True)
box('Dumpster lid',(10.5,1.35,-3.7),(1.48,.12,2.08),'dark',.04)
for z in [-4.35,-3.05]:box('Dumpster reinforcement',(11.22,.65,z),(.06,1.05,.08),'steel')
# Boundary fence, physically bounded playable area.
for z in [-9,23]:
 for x in range(-14,15,2):box('Fence post',(x,.9,z),(.09,1.8,.09),'wood',.008,True)
 for h in [.5,1.25]:box('Fence rail',(0,h,z),(28,.1,.09),'wood')
 colliders.append({'name':'Lot boundary','p':[0,.9,z],'s':[28,1.8,.1]})
for x in [-14,14]:
 colliders.append({'name':'Side boundary','p':[x,1,7],'s':[.1,2,32]})
 for z in range(-9,24,2):box('Side fence post',(x,.9,z),(.09,1.8,.09),'wood',.008)
 for h in [.5,1.25]:box('Side fence rail',(x,h,7),(.09,.1,32),'wood')
# Distant unlit tree silhouettes, organic branching crowns.
for i in range(32):
 x=r.uniform(-38,38);z=r.choice([-1,1])*r.uniform(30,42);h=r.uniform(5,10)
 cyl('Distant trunk',(x,h/2,z),.15,h,'dark',7)
 for j in range(3):
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=h*.32,location=xyz((x+r.uniform(-1,1),h*.7+j*.7,z)));o=bpy.context.object;o.scale=(1,.85,1.2);register(o,'Distant canopy','dark')
# Join per material per area: keeps runtime draw calls modest and export reproducible.
for category,objects in batches.items():
 for o in bpy.context.selected_objects:o.select_set(False)
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=category
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 # Remove unused duplicate slots by exporter; glTF splits by material automatically.
 bpy.ops.export_scene.gltf(filepath=str(OUT/f'{category}.glb'),use_selection=True,export_format='GLB',export_yup=True,export_materials='EXPORT')
(ROOT/'assets/models/collisions.json').write_text(json.dumps(colliders,indent=2)+'\n')
print('MARKET EXPORT COMPLETE',len(colliders),'colliders')
