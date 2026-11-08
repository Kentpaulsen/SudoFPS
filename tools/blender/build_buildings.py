"""SudoFPS enterable buildings (house, supermarket, church) + suit outfit for the character.
Run with Blender 4.2 Python: python build_buildings.py <outdir> <person_blend_dir>"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler
_d = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_d, "build_templates_v2.py")).read()
exec(_src[:_src.index("# ---------------------------------------------------------------- TIKE")])
PERSON_DIR = os.path.abspath(sys.argv[-1])
OUT = os.path.abspath(sys.argv[-2])
BLEND_DIR = os.path.join(OUT, "blender"); GLB_DIR = os.path.join(OUT, "glb")
os.makedirs(BLEND_DIR, exist_ok=True); os.makedirs(GLB_DIR, exist_ok=True)

def hull(m, pts, mi):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    m._push(bm, mi)
MB.hull = hull

class Kit:
    """Collects visible geometry and box/hull colliders for one building."""
    def __init__(self, c):
        self.c = c
        self.m = MB()
        self.cols = []
        self.hulls = []

    def box(self, size, loc, mi, rot=(0, 0, 0), col=True, bevel=0.0):
        self.m.box(size, loc, mi, rot=rot, bevel=bevel)
        if col:
            self.cols.append((size, loc, rot))

    def wall(self, a, b, t, h, mi, openings=(), z0=0.0, trim=None):
        """Axis-aligned wall from a to b (x,y) with openings [(offset from a, width, bottom, top)]."""
        a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
        L = (b - a).length
        u = (b - a).normalized()
        along_x = abs(u.x) > 0.5
        def put(s0, s1, z_lo, z_hi):
            if s1 - s0 < 0.02 or z_hi - z_lo < 0.02:
                return
            c = a + u * ((s0 + s1) / 2)
            size = (s1 - s0, t, z_hi - z_lo) if along_x else (t, s1 - s0, z_hi - z_lo)
            self.box(size, (c.x, c.y, z0 + (z_lo + z_hi) / 2), mi)
        # columns between every opening edge; in each column, fill the height outside the openings
        # covering it. This allows openings stacked above each other (door + belfry window).
        edges = sorted({0.0, L} | {max(0.0, min(L, o - w / 2)) for o, w, _, _ in openings} | {max(0.0, min(L, o + w / 2)) for o, w, _, _ in openings})
        for s0, s1 in zip(edges[:-1], edges[1:]):
            mid = (s0 + s1) / 2
            holes = sorted((bot, top) for o, w, bot, top in openings if o - w / 2 < mid < o + w / 2)
            z = 0.0
            for bot, top in holes:
                put(s0, s1, z, bot)
                z = max(z, top)
            put(s0, s1, z, h)
        if trim is not None:   # frame around each opening
            for off, w, bot, top in openings:
                c = a + u * off
                fs = (w + 0.12, t + 0.04, 0.08) if along_x else (t + 0.04, w + 0.12, 0.08)
                self.m.box(fs, (c.x, c.y, z0 + top + 0.04), trim)
                if bot > 0.05:
                    self.m.box(fs, (c.x, c.y, z0 + bot - 0.04), trim)

    def roof_hull(self, pts, mi, col=True):
        self.m.hull(pts, mi)
        if col:
            self.hulls.append(pts)

    def finish(self, name, mats, readme):
        root = self.m.finish(name, mats, self.c)
        for i, (size, loc, rot) in enumerate(self.cols):
            collider(f"{name}_COL{i:03d}", size, loc, self.c, rot=rot)
        for i, pts in enumerate(self.hulls):
            hm = MB()
            hm.hull(pts, 0)
            ob = hm.finish(f"{name}_HULL{i:02d}-convcolonly", [], self.c)
            ob.display_type = 'WIRE'
            ob.hide_render = True
        set_meta(readme)
        return root

def bmats(extra=()):
    base = [mat("Wall", (0.78, 0.72, 0.60), 0.9), mat("Roof", (0.35, 0.10, 0.07), 0.8),
            mat("Trim", (0.85, 0.85, 0.82), 0.6), mat("Floor", (0.32, 0.20, 0.11), 0.7),
            mat("Foundation", (0.30, 0.29, 0.28), 0.95), mat("Furniture", (0.40, 0.26, 0.14), 0.7),
            mat("Fabric", (0.20, 0.30, 0.45), 0.9), mat("Dark", (0.05, 0.05, 0.05), 0.8)]
    return base + [mat(*e) for e in extra]
WALL, ROOF, TRIM, FLOOR, FOUND, FURN, FAB, DARK = range(8)

def base_slab(k, w, d):
    k.box((w + 0.3, d + 0.3, 2.2), (0, 0, -1.1), FOUND)                      # foundation, top flush with the ground
    k.box((w - 0.1, d - 0.1, 0.02), (0, 0, 0.012), FLOOR, col=False)         # floor finish (walk/drive straight in)
    return 0.0

# ---------------------------------------------------------------- house
def house():
    reset(); M = bmats(); c = coll("House"); k = Kit(c)
    W, D, H, t = 8.0, 7.0, 2.7, 0.25
    z0 = base_slab(k, W, D)
    hx, hy = W / 2 - t / 2, D / 2 - t / 2
    # front (-Y) with door and two windows
    k.wall((-W / 2, -hy), (W / 2, -hy), t, H, WALL, [(4.0, 1.0, 0, 2.1), (1.6, 1.1, 0.9, 2.0), (6.4, 1.1, 0.9, 2.0)], z0, TRIM)
    k.wall((-W / 2, hy), (W / 2, hy), t, H, WALL, [(2.0, 1.1, 0.9, 2.0), (6.0, 1.1, 0.9, 2.0)], z0, TRIM)
    k.wall((-hx, -D / 2 + t), (-hx, D / 2 - t), t, H, WALL, [(3.25, 1.1, 0.9, 2.0)], z0, TRIM)
    k.wall((hx, -D / 2 + t), (hx, D / 2 - t), t, H, WALL, [(1.6, 1.1, 0.9, 2.0), (4.9, 1.1, 0.9, 2.0)], z0, TRIM)
    # interior partition with doorway
    k.wall((-W / 2 + t, 0.8), (W / 2 - t, 0.8), 0.12, H, WALL, [(5.5, 0.9, 0, 2.05)], z0)
    # ceiling and gable roof (ridge along X)
    k.box((W, D, 0.1), (0, 0, z0 + H + 0.05), TRIM, col=False)
    rh, ov = 1.9, 0.45
    for s in (-1, 1):
        k.roof_hull([(-W / 2 - ov, s * (D / 2 + ov), z0 + H - 0.15), (W / 2 + ov, s * (D / 2 + ov), z0 + H - 0.15),
                     (-W / 2 - ov, 0, z0 + H + rh), (W / 2 + ov, 0, z0 + H + rh),
                     (-W / 2 - ov, s * (D / 2 + ov), z0 + H - 0.0), (W / 2 + ov, s * (D / 2 + ov), z0 + H - 0.0),
                     (-W / 2 - ov, 0, z0 + H + rh + 0.15), (W / 2 + ov, 0, z0 + H + rh + 0.15)], ROOF)
    for s in (-1, 1):   # gable ends
        x = s * (W / 2 - t / 2)
        k.roof_hull([(x - t / 2, -D / 2, z0 + H), (x + t / 2, -D / 2, z0 + H), (x - t / 2, D / 2, z0 + H),
                     (x + t / 2, D / 2, z0 + H), (x - t / 2, 0, z0 + H + rh - 0.1), (x + t / 2, 0, z0 + H + rh - 0.1)], WALL, col=False)
    k.box((0.6, 0.6, 1.6), (2.2, 1.6, z0 + H + 1.5), FOUND)                 # chimney
    k.box((1.6, 0.9, 0.02), (0, -D / 2 - 0.6, 0.012), FOUND, col=False)     # doorstep
    # furniture
    k.box((1.6, 0.9, 0.06), (-1.8, -1.6, z0 + 0.75), FURN)
    for dx, dy in ((-0.9, 0.7), (0.9, 0.7), (-0.9, -0.7), (0.9, -0.7)):
        k.box((0.06, 0.06, 0.72), (-1.8 + dx * 0.8, -1.6 + dy * 0.45, z0 + 0.36), FURN, col=False)
    for dx in (-0.7, 0.7):
        k.box((0.45, 0.45, 0.45), (-1.8 + dx, -2.5, z0 + 0.225), FURN)
        k.box((0.45, 0.45, 0.45), (-1.8 + dx, -0.7, z0 + 0.225), FURN)
    k.box((2.0, 0.6, 0.9), (2.4, -2.95, z0 + 0.45), FURN)                    # kitchen counter
    k.box((2.0, 1.5, 0.45), (-2.4, 2.4, z0 + 0.225), FAB)                    # bed
    k.box((0.5, 1.5, 0.7), (-3.45, 2.4, z0 + 0.35), FURN)
    k.box((1.2, 0.5, 1.9), (2.8, 2.9, z0 + 0.95), FURN)                      # wardrobe
    root = k.finish("House", M, "HOUSE: 8 x 7 m, walls 2.7 m. Enterable: door on the front (-Y), open windows (shoot through).\n"
                    "Two rooms. Materials Wall and Roof are recoloured per house in game. Colliders are boxes per wall piece.")
    empty("DOOR", (0, -D / 2 - 0.6, 0), c, parent=root, size=0.3)
    save("bld_house")

# ---------------------------------------------------------------- supermarket
def supermarket():
    reset()
    M = bmats([("Glass", (0.55, 0.75, 0.85), 0.05), ("Shelf", (0.75, 0.76, 0.78), 0.4, 0.4),
               ("Sign", (0.75, 0.08, 0.05), 0.5), ("Goods1", (0.85, 0.55, 0.10), 0.7), ("Goods2", (0.15, 0.45, 0.70), 0.7),
               ("Goods3", (0.30, 0.60, 0.25), 0.7)])
    GLASS, SHELF, SIGN, G1, G2, G3 = range(8, 14)
    M[GLASS].blend_method = 'BLEND'
    try:
        M[GLASS].node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.3
    except Exception:
        pass
    c = coll("Supermarket"); k = Kit(c)
    W, D, H, t = 24.0, 16.0, 4.2, 0.3
    z0 = base_slab(k, W, D)
    hx, hy = W / 2 - t / 2, D / 2 - t / 2
    # front: pillars + glass, 3 m doorway in the middle
    k.wall((-W / 2, -hy), (W / 2, -hy), t, H, WALL, [(12.0, 3.0, 0, 2.6), (5.0, 7.0, 0.5, 3.4), (19.0, 7.0, 0.5, 3.4)], z0, TRIM)
    for cx in (-7.0, 7.0):
        k.box((7.0, 0.04, 2.9), (cx, -hy, z0 + 1.95), GLASS)                # glass blocks walking, shows inside
    k.wall((-W / 2, hy), (W / 2, hy), t, H, WALL, [(20.0, 3.0, 0, 3.0)], z0, TRIM)   # loading door
    k.wall((-hx, -D / 2 + t), (-hx, D / 2 - t), t, H, WALL, [(7.0, 1.0, 0, 2.1)], z0, TRIM)
    k.wall((hx, -D / 2 + t), (hx, D / 2 - t), t, H, WALL, [], z0)
    k.wall((-W / 2 + t, 4.0), (W / 2 - t, 4.0), 0.15, H, WALL, [(4.0, 1.2, 0, 2.2), (18.0, 1.2, 0, 2.2)], z0)   # storage
    k.box((W + 0.4, D + 0.4, 0.3), (0, 0, z0 + H + 0.15), TRIM)              # flat roof
    k.box((W + 0.4, 0.2, 0.5), (0, -D / 2 - 0.1, z0 + H + 0.55), TRIM, col=False)  # parapet
    k.box((10.0, 0.2, 1.2), (0, -D / 2 - 0.25, z0 + H - 0.3), SIGN)          # sign board
    for i in range(5):
        k.box((1.2, 0.05, 0.6), (-3.6 + i * 1.8, -D / 2 - 0.36, z0 + H - 0.3), TRIM, col=False)
    k.box((W - 1, 2.0, 0.02), (0, -D / 2 - 1.2, 0.012), FOUND, col=False)  # forecourt
    # shelves: 4 rows, 3 levels of goods
    goods = [G1, G2, G3]
    for r, x in enumerate((-7.5, -3.0, 1.5, 6.0)):
        k.box((1.0, 7.0, 0.1), (x, -0.5, z0 + 0.1), SHELF)
        k.box((0.06, 7.0, 1.8), (x, -0.5, z0 + 0.95), SHELF)
        for lvl in range(3):
            z = z0 + 0.25 + lvl * 0.6
            k.box((1.0, 7.0, 0.04), (x, -0.5, z), SHELF, col=False)
            for s in (-1, 1):
                for j in range(6):
                    k.box((0.36, 0.95, 0.32), (x + s * 0.27, -3.6 + j * 1.2, z + 0.18), goods[(r + lvl + j) % 3], col=False)
    for x in (-9.0, -6.0):   # checkouts
        k.box((0.8, 2.2, 0.95), (x, -5.4, z0 + 0.475), SHELF)
        k.box((0.5, 0.4, 0.3), (x, -6.2, z0 + 1.1), DARK, col=False)
    for i in range(4):       # storage boxes
        k.box((1.2, 1.0, 1.0 + (i % 2) * 0.6), (-8 + i * 4.5, 6.2, z0 + 0.5 + (i % 2) * 0.3), FURN)
    root = k.finish("Supermarket", M, "SUPERMARKET: 24 x 16 m, 4.2 m high, flat roof. Glass front with a 3 m doorway (-Y),\n"
                    "side door, loading door at the back, storage room behind the shelves. Four shelf rows, two checkouts.")
    empty("DOOR", (0, -D / 2 - 1.5, 0), c, parent=root, size=0.3)
    save("bld_supermarket")

# ---------------------------------------------------------------- church
def church():
    reset(); M = bmats([("Stone", (0.55, 0.53, 0.50), 0.9), ("Gold", (0.80, 0.60, 0.15), 0.3, 0.8)])
    STONE, GOLD = 8, 9
    c = coll("Church"); k = Kit(c)
    W, D, H, t = 10.0, 18.0, 6.0, 0.4
    k.box((W + 0.4, D + 0.4, 2.2), (0, 1.0, -1.1), FOUND)
    k.box((4.6, 4.6, 2.2), (0, -10.3, -1.1), FOUND)
    z0 = 0.0
    k.box((W - 0.2, D - 0.2, 0.02), (0, 1.0, 0.012), FLOOR, col=False)
    yb, yf = 1.0 + D / 2 - t / 2, 1.0 - D / 2 + t / 2
    hx = W / 2 - t / 2
    win = [(2.5 + i * 4.0, 0.9, 1.6, 4.6) for i in range(4)]
    k.wall((-hx, yf + t / 2), (-hx, yb - t / 2), t, H, STONE, win, z0, TRIM)
    k.wall((hx, yf + t / 2), (hx, yb - t / 2), t, H, STONE, win, z0, TRIM)
    k.wall((-W / 2, yb), (W / 2, yb), t, H, STONE, [(5.0, 1.2, 2.5, 5.0)], z0, TRIM)
    k.wall((-W / 2, yf), (W / 2, yf), t, H, STONE, [(5.0, 1.8, 0, 3.0)], z0, TRIM)
    # steep roof (ridge along Y)
    rh, ov = 4.5, 0.5
    for s in (-1, 1):
        k.roof_hull([(s * (W / 2 + ov), yf - 0.2, z0 + H - 0.3), (s * (W / 2 + ov), yb + 0.2, z0 + H - 0.3),
                     (0, yf - 0.2, z0 + H + rh), (0, yb + 0.2, z0 + H + rh),
                     (s * (W / 2 + ov), yf - 0.2, z0 + H - 0.1), (s * (W / 2 + ov), yb + 0.2, z0 + H - 0.1),
                     (0, yf - 0.2, z0 + H + rh + 0.2), (0, yb + 0.2, z0 + H + rh + 0.2)], ROOF)
    for y in (yf, yb):
        k.roof_hull([(-W / 2, y - t / 2, z0 + H), (W / 2, y - t / 2, z0 + H), (-W / 2, y + t / 2, z0 + H),
                     (W / 2, y + t / 2, z0 + H), (0, y - t / 2, z0 + H + rh - 0.1), (0, y + t / 2, z0 + H + rh - 0.1)], STONE, col=False)
    # bell tower in front (y from -12.4 to -8.4), open to the nave
    tw, ty, th = 4.2, -10.3, 14.0
    k.wall((-tw / 2, ty - tw / 2 + t / 2), (tw / 2, ty - tw / 2 + t / 2), t, th, STONE, [(2.1, 1.6, 0, 3.0), (2.1, 1.0, 11.0, 13.0)], z0, TRIM)
    for s in (-1, 1):
        k.wall((s * (tw / 2 - t / 2), ty - tw / 2 + t), (s * (tw / 2 - t / 2), ty + tw / 2 - t), t, th, STONE, [(1.7, 1.0, 11.0, 13.0)], z0, TRIM)
    k.box((tw - 2 * t, t, th - 6.2), (0, ty + tw / 2 - t / 2, z0 + 6.2 + (th - 6.2) / 2), STONE)   # tower back above nave roof
    k.roof_hull([(-tw / 2 - 0.2, ty - tw / 2 - 0.2, z0 + th), (tw / 2 + 0.2, ty - tw / 2 - 0.2, z0 + th),
                 (-tw / 2 - 0.2, ty + tw / 2 + 0.2, z0 + th), (tw / 2 + 0.2, ty + tw / 2 + 0.2, z0 + th),
                 (0, ty, z0 + th + 6.5)], ROOF)
    k.box((0.12, 0.12, 1.4), (0, ty, z0 + th + 7.1), GOLD, col=False)       # cross
    k.box((0.7, 0.12, 0.12), (0, ty, z0 + th + 7.3), GOLD, col=False)
    k.box((0.9, 0.9, 0.8), (0, ty, z0 + 11.4), GOLD, col=False)             # bell
    # pews, altar
    for r in range(7):
        for s in (-1, 1):
            y = yf + 3.0 + r * 1.6
            k.box((3.4, 0.45, 0.45), (s * 2.3, y, z0 + 0.225), FURN)
            k.box((3.4, 0.08, 0.5), (s * 2.3, y + 0.24, z0 + 0.7), FURN, col=False)
    k.box((W - 2 * t, 3.0, 0.3), (0, yb - 1.7, z0 + 0.15), STONE)
    k.box((2.4, 1.0, 1.0), (0, yb - 1.6, z0 + 0.8), TRIM)
    k.box((0.1, 0.1, 1.4), (0, yb - 0.5, z0 + 3.6), GOLD, col=False)
    k.box((0.8, 0.1, 0.1), (0, yb - 0.5, z0 + 3.9), GOLD, col=False)
    root = k.finish("Church", M, "CHURCH: nave 10 x 18 m, 6 m walls, steep roof; bell tower 4.2 m square, 14 m + spire.\n"
                    "Enter through the tower door (-Y). Tall open windows, seven rows of pews, altar at the back.")
    empty("DOOR", (0, -13.0, 0), c, parent=root, size=0.3)
    save("bld_church")

# ---------------------------------------------------------------- car dealership (abandoned)
def dealership():
    reset()
    M = bmats([("Glass", (0.55, 0.75, 0.85), 0.05), ("Tile", (0.62, 0.62, 0.60), 0.6), ("Sign", (0.12, 0.25, 0.55), 0.6),
               ("Rust", (0.40, 0.18, 0.08), 0.9), ("Rubber", (0.03, 0.03, 0.03), 0.95), ("Stain", (0.25, 0.23, 0.20), 0.95)])
    GLASS, TILE, SIGN, RUST, RUB, STAIN = range(8, 14)
    M[GLASS].blend_method = 'BLEND'
    try:
        M[GLASS].node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.3
    except Exception:
        pass
    M[WALL].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.60, 0.58, 0.52, 1)
    c = coll("Dealership"); k = Kit(c)
    W, D, H, t = 22.0, 14.0, 5.0, 0.3
    z0 = base_slab(k, W, D)
    k.box((W - 0.4, D - 0.4, 0.02), (0, 0, 0.014), TILE, col=False)
    hx, hy = W / 2 - t / 2, D / 2 - t / 2
    # front: 7 m wide vehicle opening in the middle, broken glass showroom windows either side
    k.wall((-W / 2, -hy), (W / 2, -hy), t, H, WALL, [(11.0, 7.0, 0, 3.8), (3.7, 5.4, 0.6, 3.8), (18.3, 5.4, 0.6, 3.8)], z0, TRIM)
    for cx, pieces in ((-7.3, [(-1.8, 1.0, 1.6), (0.6, 0.6, 1.0)]), (7.3, [(1.5, 1.6, 2.2)])):
        for dx, w, h in pieces:   # the panes that are still in place
            k.box((w, 0.03, h), (cx + dx, -hy, z0 + 0.6 + h / 2), GLASS)
    for i in range(6):            # broken glass on the floor
        k.box((0.3 + (i % 3) * 0.15, 0.25, 0.01), (-8 + i * 3.1, -hy + 0.6 + (i % 2) * 0.5, 0.025), GLASS, col=False)
    k.wall((-W / 2, hy), (W / 2, hy), t, H, WALL, [(17.0, 4.0, 0, 3.6)], z0, TRIM)            # back workshop door
    k.wall((-hx, -D / 2 + t), (-hx, D / 2 - t), t, H, WALL, [], z0)
    k.wall((hx, -D / 2 + t), (hx, D / 2 - t), t, H, WALL, [(9.0, 1.0, 0, 2.1)], z0, TRIM)
    # office in the back-left corner
    k.wall((-W / 2 + t, 2.5), (-4.0, 2.5), 0.15, 3.0, WALL, [(5.0, 0.9, 0, 2.1)], z0)
    k.wall((-4.0, 2.5), (-4.0, D / 2 - t), 0.15, 3.0, WALL, [], z0)
    k.box((1.6, 0.8, 0.75), (-7.5, 4.6, 0.375), FURN)
    k.box((0.5, 0.5, 0.5), (-7.5, 5.5, 0.25), FAB)
    k.box((0.5, 0.4, 1.6), (-10.3, 4.0, 0.8), RUST)                                            # filing cabinet
    # roof with a caved-in section over the right side
    k.box((14.0, D + 0.4, 0.3), (-4.0, 0, H + 0.15), TRIM)
    k.box((4.0, D + 0.4, 0.3), (9.0, 0, H + 0.15), TRIM)
    for i in range(3):
        k.box((1.8, 1.2, 0.2), (4.5 + i * 0.8, -1.5 + i * 2.0, 0.1 + i * 0.05), TRIM, rot=(8 * i, 12, 20 * i))  # roof debris
    k.box((W - 0.4, 0.4, 0.4), (0, 0, H - 0.2), RUST, col=False)                               # roof beam
    # faded sign, one side dropped
    k.box((12.0, 0.25, 1.4), (0, -D / 2 - 0.3, H + 0.2), SIGN, rot=(0, 4, 0))
    for i in range(4):
        k.box((1.6, 0.05, 0.5), (-4.0 + i * 2.6, -D / 2 - 0.45, H + 0.2 - i * 0.18), TRIM, col=False)
    # junk: tyre stacks, oil drums, stains, platforms where the cars stood
    for (x, y, n) in ((9.0, 4.5, 4), (8.0, 5.6, 2), (-1.0, 5.6, 3)):
        for j in range(n):
            k.m.cyl(0.34, 0.24, (x, y, 0.12 + j * 0.25), RUB, seg=14)
        k.cols.append(((0.7, 0.7, n * 0.25), (x, y, n * 0.125), (0, 0, 0)))
    for (x, y) in ((10.0, -3.0), (10.0, -2.2), (2.5, 5.8)):
        k.m.cyl(0.3, 0.9, (x, y, 0.45), RUST, seg=12)
        k.cols.append(((0.6, 0.6, 0.9), (x, y, 0.45), (0, 0, 0)))
    for (x, y, w, d) in ((-1.9, -1.5, 2.6, 3.4), (2.2, -1.5, 2.0, 3.0), (0.0, 3.5, 1.8, 1.5)):
        k.box((w, d, 0.01), (x, y, 0.026), STAIN, col=False)
    root = k.finish("Dealership", M, "ABANDONED CAR DEALERSHIP: 22 x 14 m, 5 m high. 7 m wide vehicle opening at the front (-Y),\n"
                    "4 m workshop door at the back, office corner, part of the roof caved in, broken showroom glass.\n"
                    "SPAWN_TIKE / SPAWN_BIKE: where the game parks the vehicles (facing out of the front opening).")
    empty("DOOR", (0, -D / 2 - 1.0, 0), c, parent=root, size=0.3)
    empty("SPAWN_TIKE", (-1.9, -1.5, 0), c, parent=root, size=0.4)
    empty("SPAWN_BIKE", (2.2, -1.5, 0), c, parent=root, size=0.4)
    save("bld_dealership")

# ---------------------------------------------------------------- pine tree
def pine():
    reset()
    bark = mat("Bark", (0.22, 0.13, 0.07), 0.9)
    needles = mat("Needles", (0.06, 0.20, 0.08), 0.9)
    needles2 = mat("NeedlesDark", (0.04, 0.14, 0.06), 0.9)
    c = coll("Pine")
    m = MB()
    m.cyl(0.2, 7.0, (0, 0, 3.5), 0, seg=8, r2=0.1)
    tiers = [(2.3, 2.6, 1.6), (1.9, 2.4, 3.1), (1.5, 2.2, 4.5), (1.05, 2.0, 5.8), (0.6, 1.6, 7.0)]
    for i, (r, h, z) in enumerate(tiers):
        m.cyl(r, h, (0, 0, z), 1 if i % 2 == 0 else 2, seg=9, r2=0.05)
    root = m.finish("Pine", [bark, needles, needles2], c)
    collider("Pine_COL_Trunk", (0.45, 0.45, 3.0), (0, 0, 1.5), c)
    empty("HARVEST_Point", (0, -0.25, 1.1), c, parent=root, size=0.2)
    set_meta("PINE: origin at ground, ~8 m tall. Trunk collider only. Harvested for wood like the other tree.")
    save("pine")

# ---------------------------------------------------------------- suit outfit on the character
def suit():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(PERSON_DIR, "person.blend"))
    arm = bpy.data.objects["Character"]
    M = {m.name: m for m in bpy.data.materials}
    tie = mat("Tie", (0.45, 0.04, 0.04), 0.5)
    shirt = mat("Shirt", (0.85, 0.85, 0.85), 0.6)
    tops = bpy.data.collections["Tops"]
    m = 0.02
    FC = ((0.90, 0.95, 1.0), (0, 0, 0)); FS = ((0.85, 0.95, 1.0), (0, 0, 0)); FA = ((1.0, 0.88, 0.88), (0, 0, 0))
    parts = [P((0.40 + 2 * m, 0.22 + 2 * m, 0.22 + 2 * m), (0, 0, 1.36), 0, bone="Chest", f=FC),
             P((0.36 + 2 * m, 0.20 + 2 * m, 0.20 + 2 * m), (0, 0, 1.15), 0, bone="Spine", f=FS),
             P((0.41, 0.25, 0.14), (0, 0, 1.0), 0, bone="Hips", f=((1.08, 1.02, 1.0), (0, 0, 0))),
             P((0.12, 0.012, 0.30), (0, -0.131, 1.34), 1, bone="Chest", f=((1, 1, 1), (0, 0.006, 0))),       # shirt V
             P((0.045, 0.014, 0.30), (0, -0.138, 1.30), 2, bone="Chest", f=((1, 1, 1), (0, 0.006, 0))),      # tie
             P((0.06, 0.016, 0.05), (0, -0.139, 1.465), 2, bone="Chest", f=((1, 1, 1), (0, 0.006, 0))),      # knot
             P((0.07, 0.012, 0.22), (0.075, -0.135, 1.37), 0, rot=(0, -14, 0), bone="Chest", f=((1, 1, 1), (0, 0.006, 0))),
             P((0.07, 0.012, 0.22), (-0.075, -0.135, 1.37), 0, rot=(0, 14, 0), bone="Chest", f=((1, 1, 1), (0, 0.006, 0))),
             P((0.18, 0.17, 0.05), (0, 0.005, 1.48), 1, bone="Chest")]                                       # collar
    for s, side in ((1, "Left"), (-1, "Right")):
        parts += [P((0.31, 0.10 + 2 * m, 0.10 + 2 * m), (s * 0.325, 0, 1.42), 0, bone=f"{side}UpperArm", f=FA),
                  P((0.24, 0.09 + 2 * m, 0.09 + 2 * m), (s * 0.60, 0, 1.42), 0, bone=f"{side}LowerArm", f=FA),
                  P((0.025, 0.10, 0.10), (s * 0.725, 0, 1.42), 1, bone=f"{side}LowerArm")]                  # cuffs
    build("Top_04_Suit", parts, tops, [M["Top"], shirt, tie], armature=arm)
    bots = bpy.data.collections["Bottoms"]
    bp = [P((0.40, 0.25, 0.14), (0, 0, 0.99), 0, bone="Hips", f=((1.08, 1.02, 1.0), (0, 0, 0)))]
    for s, side in ((1, "Left"), (-1, "Right")):
        bp += [P((0.18, 0.19, 0.45), (s * 0.10, 0, 0.725), 0, bone=f"{side}UpperLeg", f=((0.95, 1, 1), (s * 0.005, 0, 0))),
               P((0.15, 0.16, 0.42), (s * 0.10, 0, 0.30), 0, bone=f"{side}LowerLeg", f=FA),
               P((0.006, 0.006, 0.8), (s * 0.10, -0.096, 0.55), 1, bone=f"{side}UpperLeg")]
    build("Bottom_04_SuitTrousers", bp, bots, [M["Bottom"], M["BottomAccent"]], armature=arm)
    sh = bpy.data.collections["Shoes"]
    sp = []
    for s, side in ((1, "Left"), (-1, "Right")):
        sp += [P((0.13, 0.27, 0.07), (s * 0.10, -0.06, 0.045), 0, bone=f"{side}Foot"),
               P((0.135, 0.275, 0.015), (s * 0.10, -0.06, 0.008), 1, bone=f"{side}Foot")]
    build("Shoes_03_Dress", sp, sh, [mat("DressShoe", (0.02, 0.02, 0.02), 0.2), M["ShoesAccent"]], armature=arm)
    for n in ("Top_04_Suit", "Bottom_04_SuitTrousers", "Shoes_03_Dress"):
        bpy.data.objects[n].hide_set(True)
        bpy.data.objects[n].hide_render = True
    t = bpy.data.texts.get("README")
    if t:
        t.write("\nADDED: Top_04_Suit (jacket, shirt, tie; materials Top, Shirt, Tie), Bottom_04_SuitTrousers, Shoes_03_Dress.\n")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, "person.blend"), compress=False)
    for ob in bpy.context.scene.objects:
        ob.hide_set(False)
    bpy.ops.export_scene.gltf(filepath=os.path.join(GLB_DIR, "person.glb"), export_format='GLB', use_visible=False,
                              export_yup=True, export_skins=True, export_morph=True, export_animations=False)

for fn in (house, supermarket, church, dealership, pine):
    fn()
    print("built", fn.__name__)
