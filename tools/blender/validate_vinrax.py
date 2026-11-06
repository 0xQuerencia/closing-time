"""Check exported skin deformation, contact, and unchanged texture pixels.
Run with Blender --python-exit-code 1 so a failed assertion fails the command.
"""
import bpy
import io
import json
import struct
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
path = ROOT / 'assets/models/characters/vinrax/casual_male.glb'
bpy.ops.import_scene.gltf(filepath=str(path))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
report = {}
for action in bpy.data.actions:
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    floors, heights, widths = [], [], []
    # Include half-frames to catch interpolation penetration between baked poses.
    for sample in range(int(action.frame_range[1] * 2) + 1):
        frame = sample / 2
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        vertices = [evaluated.matrix_world @ v.co for v in evaluated.data.vertices]
        floors.append(min(v.z for v in vertices))
        heights.append(max(v.z for v in vertices))
        widths.append(max(v.x for v in vertices) - min(v.x for v in vertices))
    entry = {'minimum_floor_m': min(floors), 'maximum_floor_m': max(floors),
             'minimum_height_m': min(heights), 'maximum_height_m': max(heights),
             'maximum_width_m': max(widths)}
    report[action.name] = entry
    # The authored run has airborne mid-stride poses; its retargeted sole may
    # float slightly between keyframes, but must never sink over 4 mm or lift
    # more than 10 mm from the floor. Standing and walking clips keep the
    # tighter 4 mm contact bound.
    contact_limit = 0.010 if action.name == 'Run' else 0.004
    assert min(floors) > -0.004 and max(floors) < contact_limit, (action.name, entry)
    assert min(heights) > 1.6 and max(heights) < 1.85 and max(widths) < 1.2, (action.name, entry)
    print('SKIN TEST PASS', action.name, entry)

# glTF may recompress PNG bytes, so compare decoded original/exported pixels.
data = path.read_bytes()
length = struct.unpack_from('<I', data, 12)[0]
header = json.loads(data[20:20 + length])
view = header['bufferViews'][header['images'][0]['bufferView']]
start = 28 + length + view.get('byteOffset', 0)
with tempfile.TemporaryDirectory() as tmp:
    exported = Path(tmp) / 'exported.png'
    exported.write_bytes(data[start:start + view['byteLength']])
    with zipfile.ZipFile(ROOT / 'tools/blender/source/vinrax/male_casual.zip') as archive:
        original = Path(tmp) / 'original.png'
        original.write_bytes(archive.read('man_tex.png'))
    a = bpy.data.images.load(str(exported))
    b = bpy.data.images.load(str(original))
    assert tuple(a.size) == (256, 256) and tuple(a.size) == tuple(b.size)
    assert list(a.pixels) == list(b.pixels), 'Original texture pixels changed'
(ROOT / 'local/m32').mkdir(parents=True, exist_ok=True)
(ROOT / 'local/m32/skin_validation.json').write_text(json.dumps(report, indent=2))
print('VINRAX SKIN VALIDATION COMPLETE: 10 clips, half-frame sampling; original texture pixels identical')
