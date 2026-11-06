"""Reproducible original handset. blender -b --python tools/blender/build_phone.py  ->  assets/models/props/phone.glb
Z-up in Blender: the phone's length runs along Z and its screen faces -Y, which exports to glTF facing +Z."""
import bpy, bmesh, math
from mathutils import Vector
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
W, T, L = 0.050, 0.022, 0.115
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, rough=0.7, image=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    if image:
        tex = m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(str(image)); tex.interpolation = 'Closest'
        m.node_tree.links.new(tex.outputs['Color'], b.inputs['Base Color'])
    return m

def box(bm, c, s, bevel=0.0):
    cx, cy, cz = c; sx, sy, sz = s
    v = bmesh.ops.create_cube(bm, size=1.0)['verts']
    for vert in v: vert.co = Vector((cx + vert.co.x * sx, cy + vert.co.y * sy, cz + vert.co.z * sz))
    if bevel > 0:
        edges = {e for vert in v for e in vert.link_edges}
        bmesh.ops.bevel(bm, geom=list(edges), offset=bevel, segments=2, affect='EDGES')
    return v

def make(name, bm, mats, parent):
    mesh = bpy.data.meshes.new(name); bm.to_mesh(mesh); bm.free()
    for p in mesh.polygons: p.use_smooth = False
    for m in mats: mesh.materials.append(m)
    ob = bpy.data.objects.new(name, mesh); bpy.context.collection.objects.link(ob); ob.parent = parent
    return ob

def project_uv(bm):
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            p = l.vert.co
            l[uv].uv = (min(1, max(0, (p.x + W / 2) / W)), min(1, max(0, (p.z + L / 2) / L)))

rig = bpy.data.objects.new('PhoneRig', None); bpy.context.collection.objects.link(rig)
face = material('face', (1, 1, 1), 0.55, ROOT / 'assets/models/props/phone_face.png')
case = material('case', (0.04, 0.045, 0.1), 0.6)
keycap = material('keycap', (1, 1, 1), 0.5, ROOT / 'assets/models/props/phone_face.png')
lcd = material('screen', (0.28, 0.4, 0.24), 0.4)
skin = material('skin', (0.28, 0.135, 0.085), 0.94)
sleeve = material('sleeve', (0.1, 0.13, 0.18), 0.9)

# Three twelve-sided contour rings form a tapered candybar shell.
outline = [(-.016,-.0575),(.016,-.0575),(.022,-.053),(.025,-.037),
           (.025,.035),(.020,.052),(.012,.0575),(-.012,.0575),
           (-.020,.052),(-.025,.035),(-.025,-.037),(-.022,-.053)]
bm = bmesh.new()
rings = []
for y, scale in ((-.011, .94),(-.007,1.0),(.007,1.0),(.011,.91)):
    rings.append([bm.verts.new((x*scale,y,z*scale)) for x,z in outline])
bm.faces.new(list(reversed(rings[0])))
bm.faces.new(rings[-1])
for a,b in zip(rings,rings[1:]):
    for i in range(len(a)):
        bm.faces.new((a[i],a[(i+1)%len(a)],b[(i+1)%len(a)],b[i]))
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
project_uv(bm)
make('PhoneBody', bm, [face], rig)

# raised key caps use the same plate texture so the numerals sit on top of them
bm = bmesh.new()
def cap(cx, cz, w, h): box(bm, (cx, -T / 2 - 0.0007, cz), (w, 0.0020, h), bevel=0.0015)
for cx in (-0.0145, 0.0145): cap(cx, 0.0, 0.011, 0.0062)
cap(0, 0.0, 0.0145, 0.0095)
for r, cz in enumerate((-0.0135, -0.0255, -0.0375, -0.0495)):
    for cx in (-0.0145, 0.0, 0.0145): cap(cx, cz, 0.0118, 0.0088)
project_uv(bm)
make('PhoneKeys', bm, [keycap], rig)

# the LCD, a quad just proud of the faceplate with 0..1 UVs, replaced in game by the message screen
bm = bmesh.new(); sw, sh, cz = 0.0355, 0.0325, 0.027
vs = [bm.verts.new(Vector(p)) for p in ((-sw / 2, -T / 2 - 0.0004, cz - sh / 2), (sw / 2, -T / 2 - 0.0004, cz - sh / 2), (sw / 2, -T / 2 - 0.0004, cz + sh / 2), (-sw / 2, -T / 2 - 0.0004, cz + sh / 2))]
f = bm.faces.new(vs); uv = bm.loops.layers.uv.verify()
for l, u in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))): l[uv].uv = u
make('PhoneScreen', bm, [lcd], rig)

# Anatomical grip: continuous tapered tubes for bent phalanges, merged with
# an asymmetric palm and wrist before decimation. No stacked cube fingers.
def tube(name, points, radii, material, sides=8):
    verts=[]; faces=[]
    for i, (point, radius) in enumerate(zip(points,radii)):
        c=Vector(point)
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        tangent.normalize()
        u=tangent.cross(Vector((0,1,0)))
        if u.length < .01: u=tangent.cross(Vector((1,0,0)))
        u.normalize();v=tangent.cross(u).normalized()
        rx,ry=radius if isinstance(radius,tuple) else (radius,radius)
        for j in range(sides):
            angle=2*math.pi*j/sides
            verts.append(c+u*math.cos(angle)*rx+v*math.sin(angle)*ry)
    faces.append(tuple(reversed(range(sides))))
    for i in range(len(points)-1):
        for j in range(sides):
            k=i*sides+j;n=i*sides+(j+1)%sides
            faces.append((k,n,n+sides,k+sides))
    faces.append(tuple(range((len(points)-1)*sides,len(points)*sides)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(material)
    ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);ob.parent=rig
    return ob
parts=[]
parts.append(tube('Palm',[(.012,.023,-.080),(.014,.025,-.057),(.012,.026,-.027),(.009,.023,.005),(.004,.022,.025)],[(.014,.011),(.018,.013),(.024,.013),(.024,.012),(.017,.009)],skin))
for z,r,length in ((.030,.0064,0),(.009,.007,.002),(-.013,.0065,.001),(-.033,.0055,-.003)):
    parts.append(tube('Finger',[(.010,.026,z),(-.011,.022,z+.002),(-.026,.012,z),(-.029,-.002,z-.002),(-.025,-.012,z-.005),(-.020-length,-.014,z-.007)], [r*1.2,r*1.15,r,r*.95,r*.82,r*.45],skin))
parts.append(tube('Thumb',[(.023,.023,-.048),(.034,.010,-.037),(.036,-.003,-.022),(.031,-.014,-.009),(.026,-.016,-.001)], [.013,.011,.009,.007,.004],skin))
bpy.ops.object.select_all(action='DESELECT')
for ob in parts: ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
hand=bpy.context.object;hand.name='Hand'
remesh=hand.modifiers.new('Joined anatomy','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.0016
bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth=hand.modifiers.new('Soft tissue','SMOOTH');smooth.factor=1.1;smooth.iterations=4
bpy.ops.object.modifier_apply(modifier=smooth.name)
dec=hand.modifiers.new('PSX facets','DECIMATE');dec.ratio=.13
bpy.ops.object.modifier_apply(modifier=dec.name)
# Warm flat-shaded facets, much lower contrast than the old white blocks.
import random
rng=random.Random(73)
for i in range(5):
    hand.data.materials.append(material('skin tone %d'%i,(.255+i*.012,.12+i*.007,.076+i*.005),.95))
for face_poly in hand.data.polygons:
    face_poly.material_index = 0
    face_poly.use_smooth = True
tube('Sleeve',[(.012,.025,-.073),(.013,.027,-.095),(.020,.045,-.20)],[(.017,.014),(.020,.017),(.027,.023)],sleeve,10)

for ob in bpy.data.objects:
    ob.select_set(ob.type in {'MESH', 'EMPTY'})
out = ROOT / 'assets/models/props/phone.glb'
bpy.ops.export_scene.gltf(filepath=str(out), export_format='GLB', export_yup=True, export_apply=True)
print('exported', out)
