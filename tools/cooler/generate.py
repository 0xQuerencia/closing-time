"""Rebuild the original cooler aisle GLB and atlas with Python and Pillow."""
from pathlib import Path
from random import Random

from atlas import build_atlas
from mesh import Mesh, Scene

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/models"
CENTERS = tuple(-7.10 + i * 1.57 for i in range(6))
TIERS = (.34, .78, 1.31, 1.76)


def build_case():
    body = Mesh("Enamel cabinet, rails and fittings")
    panes = Mesh("Six safety glass panes", 1)
    tubes = Mesh("Cold white fluorescent diffusers", 2)
    for bay, x in enumerate(CENTERS[::2]):
        middle = x + .785
        body.box((middle, .144, -5.24), (3.104, .248, 1.014), "enamel", front="vent")
        body.box((middle, .029, -5.27), (3.079, .056, .971), "shadow")
        body.box((middle, .278, -5.21), (3.104, .061, 1.073), "enamel", top="steel")
        body.box((middle, 2.275, -5.245), (3.104, .112, 1.068), "enamel")
        body.box((middle, 2.338, -5.252), (3.082, .029, 1.026), "enamel", front="steel")
        body.box((middle + 1.34, 2.278, -4.697), (.16, .075, .038), "shadow", front="controller")
        body.front(middle-.15, 2.255, middle+.15, 2.302, -4.708, "maker")
        for column, width in ((x-.79,.09), (x+.785,.054)):
            body.box((column, 1.27, -5.253), (width, 1.985, 1.026), "enamel")
        if bay == 2:
            body.box((x+2.335, 1.27, -5.253), (.054, 1.985, 1.026), "enamel")
        for door in [bay * 2, bay * 2 + 1]:
            center = CENTERS[door]
            body.box((center, 1.27, -5.712), (1.492, 1.965, .085), "liner", front="perforation")
            body.box((center, 2.159, -5.18), (1.46, .062, .98), "liner")
            body.box((center, 2.13, -4.944), (1.24, .031, .096), "shelf")
            tubes.box((center, 2.111, -4.944), (1.167, .016, .059), "diffuser")
            for tier, height in enumerate(TIERS):
                depth = .83 if tier == 0 else .73
                body.box((center, height - .018, -5.193), (1.444, .036, depth), "shelf", top="liner")
                body.box((center, height - .026, -5.193 + depth / 2), (1.46, .052, .035), "lip")
                if not (door % 2 == 0 and tier == 2):
                    label_x = center + (-.38 if tier % 2 else .29)
                    body.front(label_x-.047, height-.043, label_x+.047, height-.015,
                               -5.193 + depth / 2 + .019, "price")
            for side in (-1, 1):
                body.box((center + side * .728, 1.264, -4.709), (.07, 1.943, .099), "enamel")
                body.box((center + side * .688, 1.262, -4.722), (.018, 1.843, .062), "rubber")
            for height in (.317, 2.212):
                body.box((center, height, -4.708), (1.474, .072, .10), "enamel", front="steel")
            panes.front(center-.683, .346, center+.683, 2.172, -4.715, "glass")
            handle_x = center + (.65 if door % 2 == 0 else -.65)
            for height in (1.11, 1.46):
                body.box((handle_x, height, -4.633), (.055, .062, .073), "enamel", front="hinge")
            body.box((handle_x, 1.285, -4.579), (.035, .36, .039), "steel")
            for height in (.448, 2.075):
                hinge_x = center + (-.717 if door % 2 == 0 else .717)
                body.box((hinge_x, height, -4.653), (.057, .071, .035), "hinge")
            if door % 2 == 0:
                key = "row_" + "abc"[bay]
                # The original interactable centers are at y 1.23, z -4.64.
                body.box((center, 1.315, -4.884), (.591, .027, .25), "shelf")
                body.box((center, 1.23, -4.702), (.59, .076, .123), "enamel")
                body.front(center-.082, 1.195, center+.082, 1.265, -4.639, key)
                for side in (-1, 1):
                    body.box((center + side*.295, 1.36, -4.914), (.016, .073, .206), "lip")
            else:
                body.front(center-.23, .371, center+.23, .407, -4.713, "service")
    return [body, panes, tubes]


def build_card():
    board = Mesh("Hardboard inventory clipboard")
    x = -5.90
    board.box((x, 1.288, -4.566), (.266, .363, .025), "board")
    board.front(x-.116, 1.125, x+.116, 1.452, -4.552, "card")
    board.box((x, 1.454, -4.547), (.116, .03, .018), "steel")
    board.box((x, 1.475, -4.554), (.073, .026, .013), "hinge")
    board.box((x, 1.495, -4.572), (.023, .023, .034), "steel")
    board.box((x-.071, 1.499, -4.600), (.167, .012, .068), "rubber")
    return board


def build_surround():
    shell = Mesh("Rear aisle linoleum, plaster and old shelf ends")
    rng = Random(727)
    # The linoleum patch finishes at the existing gondola ends and the staff doorway.
    for col in range(22):
        x = -8.88 + col * .56
        for row in range(4):
            z = -5.55 + row * .56
            tile = ((col + row) % 2) * 2 + rng.randrange(2)
            shell.floor(x, z, x+.56, z+.56, .004, f"tile_{tile}", rng.randrange(4))
    shell.floor(-8.88, -3.314, 3.44, -3.284, .005, "kick")
    # The wall has the same band height as the rest of the market.
    for col in range(11):
        x = -8.88 + col * 1.116
        wall = "plaster_dark" if col in (0, 9, 10) else "plaster"
        shell.front(x, .7, x+1.116, 2.73, -5.873, wall)
        shell.front(x, 2.87, x+1.116, 3.17, -5.873, wall)
        for course in range(3):
            shell.front(x, .12+course*.194, x+1.116, .314+course*.194, -5.871, "brick")
    shell.front(-8.88, .005, 3.396, .12, -5.863, "kick")
    for x in (-6.0, -3.0, 0.0):
        for side in (-1, 1):
            shell.box((x+side*.428, .887, -3.36), (.041, 1.673, .042),
                      "rail", front="aisle_post")
        shell.box((x, .15, -3.365), (.86, .155, .041), "kick")
        shell.box((x, 1.69, -3.365), (.86, .055, .049), "rail", front="lip")
    return shell


def carton(name):
    model = Mesh(name)
    model.box((0, .094, 0), (.144, .188, .109), "carton_fold", front=name)
    model.face([(-.072,.188,.0545), (.072,.188,.0545), (.061,.248,0), (-.061,.248,0)], "carton_fold")
    model.face([(.072,.188,-.0545), (-.072,.188,-.0545), (-.061,.248,0), (.061,.248,0)], "carton_fold")
    model.face([(.072,.188,.0545), (.072,.188,-.0545), (.061,.248,0)], name,
               [(0,1), (1,1), (.5,0)])
    model.face([(-.072,.188,-.0545), (-.072,.188,.0545), (-.061,.248,0)], name,
               [(0,1), (1,1), (.5,0)])
    model.box((0, .25, 0), (.123, .015, .014), "carton_fold")
    return model


def can(name):
    model = Mesh(name)
    profile = [(.05,0), (.055,.012), (.055,.168), (.05,.18), (.048,.184), (0,.184)]
    model.lathe(profile, ["can_metal", name, "can_metal", "can_metal", "can_metal"], 8)
    return model


def bottle(name, plastic, small=False):
    model = Mesh(name)
    if small:
        profile = [(.034,0), (.037,.025), (.037,.06), (.037,.123), (.037,.16),
                   (.015,.19), (.017,.195), (.017,.214), (0,.214)]
        model.lathe(profile, [plastic, plastic, name, plastic, plastic, "cap", "cap", "cap"], 10)
    else:
        profile = [(.055,0), (.058,.077), (.058,.193), (.022,.271), (.024,.303), (0,.303)]
        model.lathe(profile, [plastic, name, plastic, "cap", "cap"], 8)
    return model


def populate(scene):
    stock = scene.node("DisplayStock")
    counted = bottle("birch", "birch_plastic", small=True)
    scene.node("BirchSpring", scene.mesh(counted), stock)
    catalog = {
        "milk": carton("milk"), "coffee": carton("coffee"), "lime_carton": carton("lime"),
        **{key: can(key) for key in ("ocean", "grape", "lime", "cola", "orange")},
        "cola_pet": bottle("cola", "cola_pet"), "orange_pet": bottle("orange", "amber_pet"),
    }
    layout = (
        ("cola_pet", "coffee", None, "milk"), ("orange_pet", "grape", "ocean", "lime_carton"),
        ("orange_pet", "cola", None, "ocean"), ("cola_pet", "lime", "grape", "orange"),
        ("cola_pet", "lime_carton", None, "grape"), ("orange_pet", "ocean", "lime", "coffee"),
    )
    rng = Random(112)
    groups = {}
    for name, model in catalog.items():
        groups[name] = (scene.node(name + "_batch", parent=stock), scene.mesh(model))
    for door, lineup in enumerate(layout):
        for tier, name in enumerate(lineup):
            if name is None:
                continue
            group, stock_mesh = groups[name]
            wide = name in ("milk", "coffee", "lime_carton")
            count, step = (6, .205) if wide else (8, .167)
            for item in range(count):
                offset = (item - (count - 1) / 2) * step
                x = CENTERS[door] + offset + rng.uniform(-.012, .012)
                z = -4.961 + rng.uniform(-.02, .017) - (.037 if tier == 0 else 0)
                scene.node(name + "_facing", stock_mesh, group, (x, TIERS[tier], z), rng.uniform(-.18, .18))
                if item in (1, 3, count - 1) and tier in (0, 3):
                    scene.node(name + "_reserve", stock_mesh, group,
                               (x+.016, TIERS[tier], z-.173), rng.uniform(-.18, .18))
    unique = sum(len(model.indices)//3 for model in catalog.values()) + len(counted.indices)//3
    return unique


def main():
    build_atlas(OUTPUT / "cooler_atlas.png")
    scene = Scene()
    fixture = build_case() + [build_card()]
    for model, name in zip(fixture, ("Cabinet", "SafetyGlass", "Fluorescents", "Clipboard")):
        scene.node(name, scene.mesh(model))
    shell = build_surround()
    scene.node("AisleSurround", scene.mesh(shell))
    stock_triangles = populate(scene)
    scene.save(OUTPUT / "cooler_aisle.glb")
    fixture_triangles = sum(len(model.indices) // 3 for model in fixture)
    placements = sum("mesh" in node for node in scene.data["nodes"])
    print(f"Fixture: {fixture_triangles:,} triangles. Aisle dressing: {len(shell.indices)//3:,}.")
    print(f"Unique packaging: {stock_triangles:,}. GLB: {placements} mesh nodes, 3 materials, 1 atlas (512x512 RGBA).")
    assert fixture_triangles + stock_triangles <= 3000


if __name__ == "__main__":
    main()
