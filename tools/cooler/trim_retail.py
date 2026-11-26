"""Remove the six integrated coolers from draft #23's single retail mesh."""
import argparse
import json
from pathlib import Path
import struct

from mesh import glb


def trim(source, output):
    data = source.read_bytes()
    assert data[:4] == b"glTF"
    size, kind = struct.unpack_from("<I4s", data, 12)
    assert kind == b"JSON"
    model = json.loads(data[20:20+size])
    buffer = bytearray(data[28+size:])
    [retail] = model["nodes"]
    assert retail["name"] == "retail" and retail["translation"][0] == -6
    accessors = model["accessors"]
    views = model["bufferViews"]
    primitives = model["meshes"][retail["mesh"]]["primitives"]

    def inspect(index, layout):
        accessor = accessors[index]
        view = views[accessor["bufferView"]]
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        encoding = struct.Struct("<" + layout)
        return accessor, start, view.get("byteStride", encoding.size), encoding

    kept_primitives = []
    removed = 0
    for primitive in primitives:
        index = primitive["indices"]
        layout = {5123: "H", 5125: "I"}[accessors[index]["componentType"]]
        indices, index_start, stride, index_type = inspect(index, layout)
        assert stride == index_type.size
        vertices, start, step, vertex_type = inspect(primitive["attributes"]["POSITION"], "fff")
        inside = []
        for i in range(vertices["count"]):
            x, _, z = vertex_type.unpack_from(buffer, start + i * step)
            inside.append(-2.05 < x < 7.60 and z < -8.80)
        kept = []
        for i in range(0, indices["count"], 3):
            triangle = tuple(index_type.unpack_from(buffer, index_start + (i+j) * stride)[0] for j in range(3))
            flags = [inside[vertex] for vertex in triangle]
            assert all(flags) or not any(flags), "A triangle crosses the cooler removal bounds"
            if all(flags):
                removed += 1
            else:
                kept.extend(triangle)
        if kept:
            kept_primitives.append(primitive)
        if len(kept) != indices["count"]:
            packed = b"".join(index_type.pack(i) for i in kept)
            buffer[index_start:index_start + indices["count"] * stride] = packed.ljust(indices["count"] * stride, b"\0")
            if kept:
                indices["count"] = len(kept)
                indices["min"], indices["max"] = [min(kept)], [max(kept)]
    assert removed > 0, "Pass the unmodified draft retail GLB"
    model["meshes"][retail["mesh"]]["primitives"] = kept_primitives
    output.write_bytes(glb(model, buffer))
    print(f"Removed {removed:,} legacy cooler triangles. All other triangle indices are preserved.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    trim(args.source, args.output)
