"""Small Y-up glTF writer. Face order follows glTF counterclockwise winding."""
import json
from math import cos, sin, sqrt, tau
import struct

from atlas import REGIONS, SIZE


class Mesh:
    def __init__(self, name, material=0):
        self.name = name
        self.material = material
        self.vertices = []
        self.normals = []
        self.uvs = []
        self.indices = []

    def face(self, points, paint, coords=None):
        if coords is None:
            coords = [(0, 1), (1, 1), (1, 0), (0, 0)]
        a, b, c = points[:3]
        u = [end - start for end, start in zip(b, a)]
        v = [end - start for end, start in zip(c, a)]
        normal = (u[1]*v[2] - u[2]*v[1], u[2]*v[0] - u[0]*v[2], u[0]*v[1] - u[1]*v[0])
        length = sqrt(sum(n*n for n in normal))
        start = len(self.vertices)
        for i in range(1, len(points) - 1):
            self.indices.extend((start, start + i, start + i + 1))
        x, y, w, h = REGIONS[paint]
        self.vertices.extend(points)
        self.normals.extend([tuple(n / length for n in normal)] * len(points))
        self.uvs.extend(((x + .5 + u * (w - 1)) / SIZE, (y + .5 + v * (h - 1)) / SIZE) for u, v in coords)

    def front(self, x0, y0, x1, y1, z, paint):
        self.face([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], paint)

    def floor(self, x0, z0, x1, z1, y, paint, turn=0):
        coords = [(0, 1), (1, 1), (1, 0), (0, 0)]
        points = [(x0, y, z1), (x1, y, z1), (x1, y, z0), (x0, y, z0)]
        self.face(points, paint, coords[turn:] + coords[:turn])

    def box(self, center, size, paint, front=None, top=None):
        x, y, z = center
        w, h, d = (edge * .5 for edge in size)
        a, b, c, e = (x-w,y-h,z+d), (x+w,y-h,z+d), (x+w,y+h,z+d), (x-w,y+h,z+d)
        A, B, C, E = (x-w,y-h,z-d), (x+w,y-h,z-d), (x+w,y+h,z-d), (x-w,y+h,z-d)
        for vertices, texture in [
            ((a,b,c,e), front or paint), ((b,B,C,c), paint), ((B,A,E,C), paint),
            ((A,a,e,E), paint), ((e,c,C,E), top or paint), ((A,B,b,a), paint),
        ]:
            self.face(vertices, texture)

    def lathe(self, profile, paints, sides, x_scale=1, z_scale=1):
        def point(radius, height, i):
            theta = (i / sides - .5) * tau
            return (sin(theta) * radius * x_scale, height, cos(theta) * radius * z_scale)

        for ring, paint in enumerate(paints):
            r0, y0 = profile[ring]
            r1, y1 = profile[ring + 1]
            # A sheet of label artwork spans a single printed band. Metal rings use a swatch.
            for i in range(sides):
                u, v = i / sides, (i + 1) / sides
                lower = [point(r0, y0, i), point(r0, y0, i + 1)]
                upper = [point(r1, y1, i + 1), point(r1, y1, i)]
                if r1 == 0:
                    self.face(lower + upper[:1], paint, [(u, 1), (v, 1), (v, 0)])
                else:
                    self.face(lower + upper, paint, [(u, 1), (v, 1), (v, 0), (u, 0)])


class Scene:
    def __init__(self):
        metal = {"baseColorTexture": {"index": 0}, "metallicFactor": 0.10, "roughnessFactor": 0.70}
        self.data = {
            "asset": {"version": "2.0", "generator": "Marlow Market cooler source"},
            "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "accessors": [],
            "bufferViews": [], "buffers": [],
            "images": [{"uri": "cooler_atlas.png"}], "textures": [{"source": 0, "sampler": 0}],
            "samplers": [{"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071}],
            "materials": [
                {"name": "CoolerEnamelAndStock", "pbrMetallicRoughness": metal},
                {"name": "CoolerSafetyGlass", "pbrMetallicRoughness": dict(metal, roughnessFactor=.27),
                 "alphaMode": "BLEND"},
                {"name": "CoolerFluorescent", "pbrMetallicRoughness": dict(metal, metallicFactor=0.0),
                 "emissiveFactor": [.58, .71, .65], "emissiveTexture": {"index": 0}},
            ],
        }
        self.buffer = bytearray()

    def accessor(self, values, spec, element_type, component_type, bounds=False):
        encoded = struct.Struct("<" + spec)
        start = len(self.buffer)
        for value in values:
            self.buffer.extend(encoded.pack(*value))
        view = {"buffer": 0, "byteOffset": start, "byteLength": len(self.buffer) - start,
                "target": 34963 if element_type == "SCALAR" else 34962}
        entry = {"bufferView": len(self.data["bufferViews"]), "componentType": component_type,
                 "count": len(values), "type": element_type}
        if bounds:
            entry["min"] = [min(col) for col in zip(*values)]
            entry["max"] = [max(col) for col in zip(*values)]
        self.data["bufferViews"].append(view)
        self.data["accessors"].append(entry)
        return len(self.data["accessors"]) - 1

    def mesh(self, model):
        assert len(model.vertices) == len(model.normals) == len(model.uvs)
        primitive = {
            "attributes": {
                "POSITION": self.accessor(model.vertices, "fff", "VEC3", 5126, bounds=True),
                "NORMAL": self.accessor(model.normals, "fff", "VEC3", 5126),
                "TEXCOORD_0": self.accessor(model.uvs, "ff", "VEC2", 5126),
            },
            "indices": self.accessor([(i,) for i in model.indices], "I", "SCALAR", 5125),
            "material": model.material,
        }
        self.data["meshes"].append({"name": model.name, "primitives": [primitive]})
        return len(self.data["meshes"]) - 1

    def node(self, name, mesh=None, parent=None, position=None, yaw=0):
        index = len(self.data["nodes"])
        node = {"name": name}
        if mesh is not None:
            node["mesh"] = mesh
        if position is not None:
            node["translation"] = position
        if yaw:
            node["rotation"] = (0, sin(yaw * .5), 0, cos(yaw * .5))
        self.data["nodes"].append(node)
        tree = self.data["scenes"][0] if parent is None else self.data["nodes"][parent]
        tree.setdefault("nodes" if parent is None else "children", []).append(index)
        return index

    def save(self, output):
        self.data["buffers"] = [{"byteLength": len(self.buffer)}]
        output.write_bytes(glb(self.data, self.buffer))


def glb(data, buffer):
    payload = json.dumps(data, separators=(",", ":")).encode()
    payload += b" " * (-len(payload) % 4)
    buffer = bytes(buffer) + bytes(-len(buffer) % 4)
    header = struct.pack("<4sII", b"glTF", 2, 28 + len(payload) + len(buffer))
    return header + struct.pack("<I4s", len(payload), b"JSON") + payload + struct.pack("<I4s", len(buffer), b"BIN\0") + buffer
