"""Render the exported retail mesh independently of Godot for mesh/material QA."""
import bpy, math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root/'assets/models/retail.glb'))
bpy.ops.mesh.primitive_plane_add(size=40)
plane=bpy.context.object
m=bpy.data.materials.new('Studio floor');m.diffuse_color=(.15,.16,.15,1);plane.data.materials.append(m)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.world.color=(.15,.15,.15)
for p,power,size in [((-3,-1,6),1700,7),((-8,-7,4),900,5),((1,4,5),1200,4)]:
 bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((-3,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(-10,-9,4.8));camera=bpy.context.object;camera.rotation_euler=(Vector((-3,0,1))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=36;scene.camera=camera
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
out=root/'local/screenshots/blender-fixtures.png';out.parent.mkdir(parents=True,exist_ok=True);scene.render.filepath=str(out)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'local/fixture_review.blend'))
bpy.ops.render.render(write_still=True)
