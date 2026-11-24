#!/usr/bin/env python3
"""Install the prop pack into Closing Time; preserve interaction and collision code.
Dry run by default. Use --apply on a clean feature branch.
Tested against expected source patterns, not a running Godot installation.
"""
from pathlib import Path
import argparse, re, shutil, json, sys
HERE=Path(__file__).resolve().parent
ap=argparse.ArgumentParser();ap.add_argument('project',type=Path);ap.add_argument('--apply',action='store_true');args=ap.parse_args();root=args.project.resolve()
if not (root/'project.godot').is_file():sys.exit('Not a Godot project: '+str(root))
changes={};warnings=[]
def edit(path,fn,required=True):
 p=root/path
 if not p.is_file():
  if required:raise ValueError(f'Missing {path}')
  warnings.append(f'Skipped missing {path}');return
 old=p.read_text();new=fn(old)
 if new!=old:changes[path]=new

def sub(s,a,b):
 if a not in s:raise ValueError('Source pattern changed: '+a[:100])
 return s.replace(a,b,1)
def between(s,a,b,replacement):
 start=s.find(a);end=s.find(b,start+len(a))
 if start<0 or end<0:raise ValueError('Source pattern changed: '+a[:100])
 return s[:start]+replacement+s[end:]

LOADER='preload("res://assets/models/psx_pack/asset_loader.gd")'
loader='''extends RefCounted

static func make(id: String) -> Node3D:
	var packed := load("res://assets/models/psx_pack/%s.glb" % id) as PackedScene
	if packed == null:
		push_error("Missing PSX asset: " + id)
		return null
	var model := packed.instantiate() as Node3D
	model.name = id
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		if mesh.mesh.get_surface_count() == 1:
			var source := mesh.get_active_material(0) as BaseMaterial3D
			if source != null:
				var material := source.duplicate() as BaseMaterial3D
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				mesh.material_override = material
	return model

static func place(parent: Node, id: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var model := make(id)
	if model != null:
		model.position = at
		model.rotation.y = yaw
		parent.add_child(model)
	return model

static func hide_meshes(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).hide()
'''

def office(s):
 if 'psx_pack/asset_loader.gd' in s:return s
 return sub(s,'func make(kind: String) -> Node3D:\n','func make(kind: String) -> Node3D:\n\tif kind in ["desk","chair","crt","computer","keyboard","phone","mug","crate","extinguisher","camera"]:\n\t\tvar authored := '+LOADER+'.make(kind)\n\t\tif authored != null:\n\t\t\treturn authored\n')

def exterior(s):
 if 'psx_pack/asset_loader.gd' in s:return s
 s=between(s,'func _build_car(at: Vector3) -> void:\n','func _quad(',f'func _build_car(at: Vector3) -> void:\n\t{LOADER}.place(self,"wagon",at)\n\n')
 return between(s,'\tvar dumpster := _mat(Color("#444b3e"))','\nfunc _fence(',f'\t{LOADER}.place(self,"dumpster",Vector3(10.5,0,-3.7))\n')

def checkout(s):
 if 'psx_pack/asset_loader.gd' in s:return s
 # Keep interaction and existing scanner flash, using the dedicated mesh node.
 s=sub(s,'var scanner := _spawn_prop("res://assets/models/props/scanner.glb", Vector3(-6.22, COUNTER_TOP, 4.62))',f'var scanner := {LOADER}.place(self,"scanner",Vector3(-6.22, COUNTER_TOP, 4.62))')
 s=between(s,'\tfor mi in scanner.find_children(', '\nfunc _flash_scanner()', '''\tvar window := scanner.find_child("ScanWindow",true,false) as MeshInstance3D
	if window != null:
		var material := window.get_active_material(0).duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = Color(0.5,0.035,0.025)
		material.emission_energy_multiplier = 0.4
		window.material_override = material
		_scan_window = material
''')
 # New CRT glass is at +0.201 m. Move the register's text just in front.
 s=re.sub(r'CRT_POS \+ Vector3\(-0\.115, 0\.22, 0\.\d+\)', 'CRT_POS + Vector3(-0.115, 0.22, 0.203)',s,count=1)
 return s

def apartment(s):
 if 'psx_pack/asset_loader.gd' in s:return s
 s=sub(s,'extends Node3D\n','extends Node3D\n\nconst PSX = '+LOADER+'\n')
 s=between(s,'\t# Bed, blanket and pillow.','\t# Desk and paper/photo/phone', '''\t# Preserve the original collision pieces; replace only their visual geometry.
	var bed_parts: Array[Node3D] = [
		_box(Vector3(-2.35,.22,-2.45),Vector3(1.45,.4,2.10),wood),
		_box(Vector3(-2.35,.47,-2.45),Vector3(1.4,.16,2.02),Color("#a5a18e")),
		_box(Vector3(-2.35,.57,-2.18),Vector3(1.42,.06,1.45),fabric),
		_box(Vector3(-2.35,.61,-3.12),Vector3(.78,.13,.42),Color("#b3b0a0"))]
	for part in bed_parts:
		PSX.hide_meshes(part)
	PSX.place(self,"bed",Vector3(-2.35,0,-2.45))
''')
 s=between(s,'\t# Desk and paper/photo/phone','\t_target("shift_read"', '''\t# Desk and paper/photo/phone.
	var desk_parts: Array[Node3D] = [_box(Vector3(.65,.70,-3.91),Vector3(1.7,.10,.76),wood)]
	for x in [-.10,1.40]:
		desk_parts.append(_box(Vector3(x,.34,-3.91),Vector3(.09,.68,.64),wood))
	for part in desk_parts:
		PSX.hide_meshes(part)
	PSX.place(self,"apartment_desk",Vector3(.65,0,-3.91))
''')
 s=between(s,'\t# Kitchen cabinets and worn appliances.','\t# Entry table, keys and vest.', '''\t# Keep kitchen/fridge collision while using the textured visual models.
	var kitchen_parts: Array[Node3D] = [
		_box(Vector3(2.93,.43,-1.55),Vector3(.95,.86,2.6),wood),
		_box(Vector3(2.93,.90,-1.55),Vector3(1.02,.08,2.68),Color("#99978b")),
		_box(Vector3(2.95,1.0,-2.29),Vector3(.57,.12,.58),dark,false),
		_box(Vector3(3.02,.83,1.2),Vector3(.80,1.65,.76),Color("#a7a596")),
		_box(Vector3(2.60,1.12,1.2),Vector3(.06,.43,.04),dark,false)]
	for part in kitchen_parts:
		PSX.hide_meshes(part)
	PSX.place(self,"kitchen",Vector3(2.93,0,-1.55))
	PSX.place(self,"fridge",Vector3(3.02,0,1.2),-PI/2.0)
''')
 s=sub(s,'\ttargets[id] = {"verb":verb,"body":body,"node":node}', '''\ttargets[id] = {"verb":verb,"body":body,"node":node}
	var visuals := {"keys_taken":["keyring",Vector3(0,-.013,0),0.0],"vest_taken":["vest",Vector3(0,-.29,0),PI/2.0],"kay_photo":["photo_frame",Vector3(0,-.115,0),0.0],"rent_notice":["rent_notice",Vector3(0,.009,0),0.0],"epilogue_paper":["rent_notice",Vector3(0,.013,0),0.0]}
	if visuals.has(id):
		var spec: Array = visuals[id]
		PSX.hide_meshes(node)
		PSX.place(node,str(spec[0]),spec[1],spec[2])''')
 return s

def route(s):
 if 'psx_pack/asset_loader.gd' in s:return s
 s=sub(s,'extends Node3D\n','extends Node3D\n\nconst PSX = '+LOADER+'\n')
 s=sub(s,'\t_box(car,Vector3(0,.72,-.65),Vector3(1.65,.25,.42),dash)\n\t_box(car,Vector3(0,.44,-.86),Vector3(1.65,.48,.2),dash)', '\tPSX.place(car,"dashboard",Vector3.ZERO)')
 s=sub(s,'\t_box(car,Vector3(-.38,.84,-.50),Vector3(.39,.12,.12),Color("#242a26"))\n','')
 s=between(s,'\tvar torus := TorusMesh.new()','\twiper = Node3D.new()', '\tPSX.place(wheel,"steering_wheel",Vector3.ZERO)\n\tPSX.place(car,"rearview_mirror",Vector3(0,1.52,-.60))\n')
 s=sub(s,'\t_box(wiper,Vector3(-.30,.16,0),Vector3(.64,.022,.025),Color("#252a29"))','\tPSX.place(wiper,"wiper",Vector3.ZERO)')
 return s

try:
 edit('scenes/world/original_office_props.gd',office)
 edit('scenes/world/original_exterior.gd',exterior)
 edit('gameplay/store/checkout.gd',checkout)
 edit('scenes/apartment/apartment.gd',apartment,False)
 edit('scenes/route9/route9.gd',route,False)
except ValueError as e:sys.exit(str(e)+'\nNothing written. Use the pack manually or adapt this installer to the current source.')
models=list((HERE/'models').glob('*.glb'));assert len(models)==44
print(f'{"APPLY" if args.apply else "DRY RUN"}: {len(models)} GLBs, {len(changes)} source files')
for p in changes:print('  patch',p)
for w in warnings:print(w)
if args.apply:
 dest=root/'assets/models/psx_pack';dest.mkdir(parents=True,exist_ok=True)
 for model in models:shutil.copy2(model,dest/model.name)
 (dest/'asset_loader.gd').write_text(loader)
 shutil.copy2(HERE/'manifest.json',dest/'manifest.json')
 for path,s in changes.items():(root/path).write_text(s)
 print('Installed. Open Godot and import, then run gameplay checks. Use ordinary Web preset (not legacy art-reference).')
else:print('No files changed. Rerun with --apply on a clean feature branch.')
