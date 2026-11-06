"""Bake existing Cordatix clips onto Vinrax's original weighted mesh.

blender -b --factory-startup --python tools/blender/retarget_vinrax.py
Sources remain distinct: Vinrax mesh/texture, Cordatix animation motion.
"""
import bpy
import math
import tempfile
import zipfile
from pathlib import Path
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
MAP = {
    'pelvis': 'Hips', 'spine': 'Spine', 'chest': 'UpperChest',
    'neck': 'Neck', 'head': 'Head',
    'shoulder_left': 'LeftShoulder', 'upper_arm_left': 'LeftUpperArm',
    'forearm_left': 'LeftLowerArm', 'hand_left': 'LeftHand',
    'shoulder_right': 'RightShoulder', 'upper_arm_right': 'RightUpperArm',
    'forearm_right': 'RightLowerArm', 'hand_right': 'RightHand',
    'thigh_left': 'LeftUpperLeg', 'shin.L': 'LeftLowerLeg', 'foot_left': 'LeftFoot',
    'thigh_right': 'RightUpperLeg', 'shin.R': 'RightLowerLeg', 'foot_right': 'RightFoot',
}
CLIPS = ['Idle', 'IdleShift', 'IdleWait', 'CounterIdle', 'LookAround',
         'Walk', 'Run', 'Stroll', 'TurnLeft', 'TurnRight']

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
with tempfile.TemporaryDirectory() as tmp:
    with zipfile.ZipFile(ROOT / 'tools/blender/source/vinrax/male_casual.zip') as archive:
        archive.extractall(tmp)
    bpy.ops.import_scene.fbx(filepath=str(Path(tmp) / 'male_casual.fbx'))
    target = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    # Repair the original FBX's external image reference, without altering its pixels.
    image = bpy.data.images.load(str(Path(tmp) / 'man_tex.png'))
    image.pack()
    for material in mesh.data.materials:
        material.use_nodes = True
        nodes = material.node_tree.nodes
        shader = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
        texture = next((n for n in nodes if n.type == 'TEX_IMAGE'), None)
        if texture is None:
            texture = nodes.new('ShaderNodeTexImage')
        texture.image = image
        texture.interpolation = 'Closest'
        material.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
        shader.inputs['Roughness'].default_value = 0.92
        shader.inputs['Metallic'].default_value = 0.0

    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/models/characters/young_man.glb'))
    source = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE' and o != target)
    actions = {name: bpy.data.actions[name] for name in CLIPS}
    def set_action(action):
        source.animation_data.action = action
        source.animation_data.action_slot = action.slots[0]
    set_action(actions['Idle'])
    bpy.context.scene.frame_set(0)
    reference = {name: source.pose.bones[name].matrix.to_quaternion().copy() for name in MAP.values()}
    source_hip = source.pose.bones['Hips'].head.copy()
    rest = {b.name: b.matrix_local.to_quaternion().copy() for b in target.data.bones}
    scale = target.data.bones['pelvis'].head_local.z / source_hip.z
    target.animation_data_create()
    baked = []
    for name in CLIPS:
        action = actions[name]
        set_action(action)
        start, end = (round(value) for value in action.frame_range)
        output = bpy.data.actions.new('Vinrax_' + name)
        target.animation_data.action = output
        for frame in range(int(start), int(end) + 1):
            bpy.context.scene.frame_set(frame)
            desired = {}
            # Global rotation deltas from a relaxed reference compensate for each rig's
            # different axes, hierarchy and rest stance. Never copy raw local Euler angles.
            for bone in target.pose.bones:
                parent_rotation = desired[bone.parent.name] if bone.parent else Quaternion()
                if bone.name in MAP:
                    source_name = MAP[bone.name]
                    pose = source.pose.bones[source_name].matrix.to_quaternion()
                    rotation = pose @ reference[source_name].inverted() @ rest[bone.name]
                else:
                    parent_rest = rest[bone.parent.name] if bone.parent else Quaternion()
                    rotation = parent_rotation @ parent_rest.inverted() @ rest[bone.name]
                desired[bone.name] = rotation
                parent_rest = rest[bone.parent.name] if bone.parent else Quaternion()
                local_rest = parent_rest.inverted() @ rest[bone.name]
                bone.rotation_mode = 'QUATERNION'
                bone.rotation_quaternion = local_rest.inverted() @ parent_rotation.inverted() @ rotation
                bone.location = Vector((0, 0, 0))
                if bone.name == 'pelvis':
                    displacement = (source.pose.bones['Hips'].head - source_hip) * scale
                    bone.location = rest['pelvis'].inverted() @ displacement
            bpy.context.view_layer.update()
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            floor = min((evaluated.matrix_world @ vertex.co).z for vertex in evaluated.data.vertices)
            # Different leg proportions need a small vertical contact correction;
            # preserve the original weights and leave horizontal motion to gameplay.
            pelvis = target.pose.bones['pelvis']
            world_axes = target.matrix_world.to_quaternion() @ rest['pelvis']
            pelvis.location += world_axes.inverted() @ Vector((0, 0, -floor))
            for bone in target.pose.bones:
                bone.keyframe_insert('rotation_quaternion', frame=frame - start, group=bone.name)
                if bone.name == 'pelvis':
                    bone.keyframe_insert('location', frame=frame - start, group=bone.name)
        target.animation_data.action = None
        track = target.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, output)
        baked.append((name, int(end - start + 1)))
    # Only the Vinrax mesh and armature are exported. Keep the source's motion names.
    bpy.ops.object.select_all(action='DESELECT')
    target.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = target
    target.name = 'VinraxCasualMale'
    bpy.context.scene.render.fps = 30
    out = ROOT / 'assets/models/characters/vinrax/casual_male.glb'
    bpy.ops.export_scene.gltf(filepath=str(out), use_selection=True, export_format='GLB',
        export_animations=True, export_animation_mode='NLA_TRACKS', export_nla_strips=True,
        export_skins=True, export_yup=True, export_force_sampling=True)
    print('VINRAX RETARGET COMPLETE', baked, 'mesh', len(mesh.data.polygons), 'bones', len(target.data.bones))
