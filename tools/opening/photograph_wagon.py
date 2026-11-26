"""Run Blender in background with -t 2 and pass an absolute PNG path after --."""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
arguments = sys.argv[sys.argv.index("--") + 1:]
output = Path(arguments[0]).resolve()
rear = len(arguments) > 1 and arguments[1] == "rear"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/models/opening/route9_wagon.glb"))
scene = bpy.context.scene

def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.004))
concrete = bpy.data.materials.new("Studio floor")
concrete.diffuse_color = (.048, .055, .058, 1)
bpy.context.object.data.materials.append(concrete)
scene.world = bpy.data.worlds.new("Neutral studio")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.17, .19, .22, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .42

for name, xyz, power, size, color in [
    ("Warm key", (1, 3, 5), 750, 4.0, (1.0, .86, .68)),
    ("Cool fill", (3, -5, 2.2), 450, 3.0, (.70, .84, 1.0)),
    ("Roof strip", (-3, 0, 4), 550, 2.6, (1, .94, .84)),
]:
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size, data.color = power, size, color
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = xyz
    aim(obj, (0, 0, .5))

camera = bpy.data.objects.new("Wagon study camera", bpy.data.cameras.new("Wagon study lens"))
scene.collection.objects.link(camera)
camera.location = (5.0, -6.5 if rear else 6.5, 2.8)
aim(camera, (0, 0, .75))
camera.data.lens = 55
scene.camera = camera
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 20
scene.cycles.use_denoising = True
scene.render.threads_mode = "FIXED"
scene.render.threads = 2
scene.render.resolution_x = 960
scene.render.resolution_y = 600
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(output)
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.render.render(write_still=True)
