"""SudoFPS templates v0.2: vehicles (Tike, Bike) and sandbag build pieces.
Run: python3 build_templates_v2.py <outdir>   (reuses helpers from build_templates.py)"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler

_src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_templates.py")).read()
exec(_src[:_src.index("# ---------------------------------------------------------------- PERSON")])

# ---------------------------------------------------------------- mesh builder
class MB:
    """Collects primitives (each optionally bevelled) into one mesh object."""
    def __init__(self):
        self.parts = []

    def _push(self, bm, mat, bevel=0.0, seg=1, smooth=False):
        if bevel > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=bevel, segments=seg,
                            profile=0.5, affect='EDGES', clamp_overlap=True)
        for f in bm.faces:
            f.material_index = mat
            f.smooth = smooth or bevel > 0
        me = bpy.data.meshes.new("_tmp")
        bm.to_mesh(me)
        bm.free()
        self.parts.append(me)

    def box(self, size, loc, mat=0, rot=(0, 0, 0), bevel=0.0, seg=1):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        M = Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4() \
            @ Matrix.Diagonal((*size, 1))
        bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
        self._push(bm, mat, bevel, seg)

    def cyl(self, r, depth, loc, mat=0, rot=(0, 0, 0), seg=16, bevel=0.0, bseg=1, r2=None, smooth=True):
        """Cylinder along local Z, then rotated by rot (degrees)."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r,
                              radius2=r if r2 is None else r2, depth=depth)
        M = Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
        self._push(bm, mat, bevel, bseg, smooth)

    def tube(self, p1, p2, r, mat=0, seg=8):
        p1, p2 = Vector(p1), Vector(p2)
        d = p2 - p1
        if d.length < 1e-5:
            return
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r,
                              depth=d.length)
        M = Matrix.Translation((p1 + p2) / 2) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
        self._push(bm, mat, smooth=True)

    def sphere(self, r, loc, mat=0, seg=8):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(4, seg // 2), radius=r)
        bmesh.ops.transform(bm, matrix=Matrix.Translation(loc), verts=bm.verts)
        self._push(bm, mat, smooth=True)

    def path(self, pts, r, mat=0, seg=8, closed=False, joints=True):
        pts = [Vector(p) for p in pts]
        n = len(pts)
        for i in range(n if closed else n - 1):
            self.tube(pts[i], pts[(i + 1) % n], r, mat, seg)
        if joints:
            for p in (pts if closed else pts[1:-1]):
                self.sphere(r, p, mat, seg)

    def spring(self, p1, p2, r_coil, r_wire, turns, mat=0):
        p1, p2 = Vector(p1), Vector(p2)
        d = p2 - p1
        R = d.to_track_quat('Z', 'Y').to_matrix()
        steps = int(turns * 10)
        pts = [p1 + R @ Vector((r_coil * math.cos(t * 2 * math.pi * turns / steps),
                                 r_coil * math.sin(t * 2 * math.pi * turns / steps),
                                 d.length * t / steps)) for t in range(steps + 1)]
        self.path(pts, r_wire, mat, seg=6, joints=False)

    def finish(self, name, mats, collection, origin=(0, 0, 0), parent=None):
        origin = Vector(origin)
        bm = bmesh.new()
        for me in self.parts:
            bm.from_mesh(me)
            bpy.data.meshes.remove(me)
        bmesh.ops.transform(bm, matrix=Matrix.Translation(-origin), verts=bm.verts)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for m in mats:
            me.materials.append(m)
        try:
            me.set_sharp_from_angle(angle=math.radians(35))
        except Exception:
            pass
        ob = bpy.data.objects.new(name, me)
        collection.objects.link(ob)
        if parent:
            ob.parent = parent
            ob.location = origin - parent.matrix_world.translation
        else:
            ob.location = origin
        bpy.context.view_layer.update()
        return ob

def wheel(name, hub, R, W, collection, parent, mats, knobs=22, rim_r=0.55):
    """ATV/dirt wheel: knobby tyre, rim, hub. Rolls about X. Origin at hub."""
    hub = Vector(hub)
    m = MB()
    m.cyl(R - 0.025, W, hub, 0, rot=(0, 90, 0), seg=24, bevel=0.03, bseg=2)
    for i in range(knobs):
        a = 2 * math.pi * i / knobs
        for side in (-1, 1):
            off = side * W * 0.24 + (0.02 if i % 2 else -0.02) * side
            p = hub + Vector((off, math.cos(a) * (R - 0.012), math.sin(a) * (R - 0.012)))
            m.box((W * 0.36, 0.045, 0.035), p, 0, rot=(math.degrees(a) - 90, 0, 0), bevel=0.006)
    m.cyl(R * rim_r, W + 0.012, hub, 1, rot=(0, 90, 0), seg=20)
    m.cyl(R * 0.2, W + 0.05, hub, 2, rot=(0, 90, 0), seg=12)
    for k in range(5):
        a = 2 * math.pi * k / 5
        for side in (-1, 1):
            m.cyl(0.01, 0.02, hub + Vector((side * (W / 2 + 0.03), math.cos(a) * R * 0.13,
                                             math.sin(a) * R * 0.13)), 2, rot=(0, 90, 0), seg=6)
    return m.finish(name, mats, collection, origin=hub, parent=parent)

def ring(center, normal, radius, n=18):
    R = Vector(normal).to_track_quat('Z', 'Y').to_matrix()
    return [Vector(center) + R @ Vector((radius * math.cos(2 * math.pi * i / n),
                                         radius * math.sin(2 * math.pi * i / n), 0)) for i in range(n)]


def face(m, centre, tilt_x, half_d, eye_lz, eye_x, eye_r, mouth_lz, mouth_w, lid_mat, white, black,
         lid_angle=14):
    """Cartoon face on the front of a box rotated tilt_x degrees about X. Returns eye centres and normal."""
    R = Matrix.Rotation(math.radians(tilt_x), 3, 'X')
    n = R @ Vector((0, -1, 0))
    surf = lambda x, lz: Vector(centre) + R @ Vector((x, -half_d, lz)) + n * 0.004
    eyes = []
    for s in (1, -1):
        c = surf(s * eye_x, eye_lz)
        m.tube(c, c + n * 0.018, eye_r, white, seg=24)                                   # eye white
        m.tube(c + n * 0.010, c + n * 0.022, eye_r * 1.12, black, seg=24)                # dark rim
        m.tube(c + n * 0.012, c + n * 0.024, eye_r * 1.0, white, seg=24)
        lidR = R @ Matrix.Rotation(math.radians(-s * lid_angle), 3, 'Y')                  # determined brow
        lc = c + R @ Vector((0, 0, eye_r * 0.62)) + n * 0.03
        bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
        M4 = Matrix.Translation(lc) @ lidR.to_4x4() @ Matrix.Diagonal((eye_r * 2.5, 0.03, eye_r * 0.75, 1))
        bmesh.ops.transform(bm, matrix=M4, verts=bm.verts)
        m._push(bm, lid_mat, 0.008, 2)
        eyes.append(c + n * 0.024)
    pts = [surf(t * mouth_w / 2, mouth_lz + 0.16 * mouth_w * t * t) for t in
           [i / 6 - 1 for i in range(13)]]
    pts = [p + n * 0.012 for p in pts]
    m.path(pts, mouth_w * 0.06, black, seg=10)                                            # grin
    for t in (-1, 1):
        m.sphere(mouth_w * 0.07, pts[0 if t < 0 else -1] + R @ Vector((0, 0, mouth_w * 0.06)), black)
    return eyes, n

def pupils(eyes, n, r, mats, collection, parent, idx):
    """Separate pupil objects with origin at eye centre, so the game can make them look around."""
    out = []
    for nm, c in zip(("Pupil_L", "Pupil_R"), eyes):
        p = MB()
        p.tube(c + n * 0.002 - Vector((0, 0, r * 0.25)), c + n * 0.014 - Vector((0, 0, r * 0.25)), r, idx, seg=18)
        p.sphere(r * 0.3, c + n * 0.016 + Vector((r * 0.35, 0, r * 0.1)), idx - 1, seg=8)  # catch light
        out.append(p.finish(nm, mats, collection, origin=c, parent=parent))
    return out

VEHICLE_README = """VEHICLE TEMPLATE ({kind})
1 BU = 1 m. Origin on the ground under the centre of the vehicle. Front is -Y. Up is +Z.
Moving parts are separate objects with their pivot where they rotate:
  Wheel_* roll about their local X axis. Front wheels / Steer also turn about Z (or the fork axis).
  SteeringWheel / Steer: rotate for steering input.
Face: Pupil_L / Pupil_R are separate, origin at the eye centre: move them a few cm to make the\n  vehicle look around (e.g. at the nearest player).\nMarkers: SEAT (driver hips), HAND_L / HAND_R (grip points), FOOT_L / FOOT_R, EXIT_L (where the
driver is placed on exit), CAM_3P (third-person camera target).
Colliders: '-convcolonly' boxes. The game drives this as an arcade vehicle (no real tyre physics).
Materials are tint slots; keep names."""

# ---------------------------------------------------------------- TIKE
def vehicle_tike():
    reset()
    M = [mat("Plastic", (0.80, 0.07, 0.04), 0.35), mat("Cage", (0.95, 0.75, 0.05), 0.4, 0.3),
         mat("Frame", (0.92, 0.92, 0.90), 0.5, 0.2), mat("Rubber", (0.04, 0.04, 0.04), 0.9),
         mat("Metal", (0.45, 0.46, 0.47), 0.4, 0.8), mat("Hose", (0.85, 0.10, 0.08), 0.5),
         mat("Exhaust", (0.10, 0.25, 0.65), 0.4, 0.5), mat("EyeWhite", (0.97, 0.97, 0.95), 0.3),
         mat("Pupil", (0.03, 0.03, 0.04), 0.2)]
    PL, CG, FR, RB, MT, HS, EX, EW, PU = range(9)
    c = coll("Tike")
    body = MB()
    # ---- red tub
    body.box((0.76, 1.00, 0.08), (0, 0.0, 0.34), PL, bevel=0.03, seg=2)
    for s in (1, -1):
        body.box((0.08, 1.00, 0.44), (s * 0.36, 0.0, 0.58), PL, bevel=0.035, seg=3)
        body.box((0.04, 0.62, 0.30), (s * 0.405, 0.02, 0.56), PL, bevel=0.015, seg=2)        # door bulge
        body.cyl(0.035, 0.02, (s * 0.43, 0.12, 0.64), FR, rot=(0, 90, 0), seg=12)             # fuel cap
    body.box((0.76, 0.22, 0.42), (0, -0.46, 0.62), PL, rot=(-18, 0, 0), bevel=0.05, seg=3)  # hood
    body.box((0.76, 0.08, 0.38), (0, 0.48, 0.56), PL, bevel=0.03, seg=2)                    # rear wall
    body.box((0.46, 0.34, 0.10), (0, 0.18, 0.43), RB, bevel=0.03, seg=2)                    # seat
    body.box((0.46, 0.08, 0.30), (0, 0.38, 0.62), RB, rot=(10, 0, 0), bevel=0.03, seg=2)    # seat back
    # ---- white chassis
    rails = [(-0.6, 0.25), (0.98, 0.30)]
    for s in (1, -1):
        body.path([(s * 0.26, -0.90, 0.25), (s * 0.26, -0.40, 0.25), (s * 0.26, 0.55, 0.27),
                   (s * 0.22, 1.00, 0.32)], 0.022, FR)
    for y, z in ((-0.90, 0.25), (-0.55, 0.25), (0.55, 0.27), (1.00, 0.32)):
        body.tube((-0.26, y, z), (0.26, y, z), 0.02, FR)
    # front suspension: A-arms, uprights, coil-overs
    fy, fz = -0.74, 0.25
    for s in (1, -1):
        knuckle = Vector((s * 0.55, fy, fz))
        for zz, dz in ((0.20, -0.04), (0.36, 0.07)):
            body.path([(s * 0.26, fy - 0.12, zz), (s * 0.50, fy, zz + dz * 0.3), (s * 0.26, fy + 0.12, zz)],
                      0.016, FR)
        body.tube((s * 0.50, fy, 0.18), (s * 0.50, fy, 0.40), 0.02, FR)
        body.tube((s * 0.30, fy + 0.02, 0.62), (s * 0.44, fy + 0.02, 0.22), 0.012, MT)
        body.spring((s * 0.31, fy + 0.02, 0.58), (s * 0.43, fy + 0.02, 0.28), 0.035, 0.008, 7, CG)
        body.cyl(0.03, 0.04, (s * 0.30, fy + 0.02, 0.62), FR, rot=(0, 90, 0), seg=10)
        body.tube((s * 0.26, fy, 0.25), (s * 0.30, fy + 0.02, 0.62), 0.016, FR)
    # ---- yellow roll cage
    for s in (1, -1):
        x = s * 0.40
        body.path([(x, -0.40, 0.26), (x, -0.40, 0.76), (x * 0.94, -0.28, 1.46), (x * 0.94, 0.40, 1.48),
                   (x, 0.50, 0.78), (x, 0.50, 0.28)], 0.026, CG, seg=10)
        body.path([(x * 0.94, 0.40, 1.48), (s * 0.26, 0.82, 0.70)], 0.022, CG, seg=10, joints=False)
        body.tube((x, -0.40, 0.76), (x, 0.50, 0.78), 0.02, CG, seg=10)
    body.tube((-0.376, -0.28, 1.46), (0.376, -0.28, 1.46), 0.026, CG, seg=10)
    body.tube((-0.376, 0.40, 1.48), (0.376, 0.40, 1.48), 0.026, CG, seg=10)
    body.tube((-0.376, 0.40, 1.48), (0.376, -0.28, 1.46), 0.02, CG, seg=10)
    # ---- steering column
    col_a, col_b = Vector((0, -0.52, 0.48)), Vector((0, -0.30, 0.86))
    body.tube(col_a, col_b, 0.018, MT)
    # ---- engine bay (rear)
    body.box((0.40, 0.30, 0.04), (0, 0.80, 0.33), MT, bevel=0.01)                           # engine plate
    body.box((0.30, 0.28, 0.26), (0.02, 0.80, 0.48), MT, bevel=0.03, seg=2)                 # crankcase
    for i in range(7):                                                                    # finned cylinder
        body.cyl(0.10 - 0.004 * (i % 2), 0.014, (0.22 + i * 0.026, 0.82, 0.56), MT, rot=(0, 90, 0), seg=16)
    body.cyl(0.05, 0.06, (0.42, 0.82, 0.56), MT, rot=(0, 90, 0), seg=12)                   # head
    body.cyl(0.11, 0.05, (-0.17, 0.78, 0.46), MT, rot=(0, 90, 0), seg=24)                  # CVT pulley
    body.cyl(0.09, 0.02, (-0.20, 0.78, 0.46), RB, rot=(0, 90, 0), seg=24)
    body.box((0.04, 0.30, 0.26), (0.30, 0.66, 0.72), CG, rot=(0, 0, 0), bevel=0.01)         # yellow mount plate
    for k in range(4):
        body.cyl(0.02, 0.05, (0.30, 0.58 + k * 0.06, 0.78), FR, rot=(0, 90, 0), seg=10)     # lightening holes
    body.path([(0.30, 0.82, 0.62), (0.20, 0.82, 0.80), (0.00, 0.72, 0.84)], 0.03, HS, seg=10)  # red intake
    body.cyl(0.07, 0.16, (-0.10, 0.70, 0.86), MT, rot=(0, 90, 0), seg=16)                  # air filter
    for k in range(5):
        body.cyl(0.074, 0.008, (-0.165 + k * 0.032, 0.70, 0.86), RB, rot=(0, 90, 0), seg=16)
    body.path([(0.36, 0.86, 0.48), (0.36, 1.02, 0.40), (0.28, 1.10, 0.40)], 0.022, MT)      # exhaust pipe
    body.cyl(0.06, 0.20, (0.15, 1.10, 0.40), EX, rot=(0, 90, 0), seg=14, bevel=0.01)        # blue silencer
    body.tube((-0.66, 0.60, 0.30), (0.66, 0.60, 0.30), 0.025, MT)                            # rear axle
    body.tube((-0.36, 0.48, 0.80), (-0.52, 1.30, 1.55), 0.008, RB, seg=6)                    # whip antenna
    body.sphere(0.02, (-0.52, 1.30, 1.55), RB)
    eyes, n = face(body, (0, -0.46, 0.62), -18, 0.11, 0.075, 0.17, 0.085, -0.115, 0.36, PL, EW, RB)
    root = body.finish("Tike", M, c)
    pupils(eyes, n, 0.038, M, c, root, PU)

    # steering wheel (separate, rotates about column axis)
    sw = MB()
    axis = (col_b - col_a).normalized()
    sw.path(ring(col_b, axis, 0.15, 20), 0.016, RB, closed=True, joints=False)
    for p in ring(col_b, axis, 0.15, 3):
        sw.tube(col_b, p, 0.012, RB)
    sw.cyl(0.03, 0.03, col_b, RB, seg=10)
    swo = sw.finish("SteeringWheel", M, c, origin=col_b, parent=root)

    wm = [M[RB], M[FR], M[MT]]
    for nm, x, y, R, W in (("Wheel_FL", 0.66, -0.74, 0.24, 0.20), ("Wheel_FR", -0.66, -0.74, 0.24, 0.20),
                           ("Wheel_RL", 0.70, 0.60, 0.30, 0.26), ("Wheel_RR", -0.70, 0.60, 0.30, 0.26)):
        wheel(nm, (x, y, R), R, W, c, root, wm)

    collider("Tike_COL_Body", (1.0, 2.1, 0.6), (0, 0.08, 0.50), c)
    collider("Tike_COL_Cage", (0.85, 0.80, 0.70), (0, 0.06, 1.15), c)
    for n, l in (("SEAT", (0, 0.18, 0.48)), ("HAND_L", (0.10, -0.31, 0.92)), ("HAND_R", (-0.10, -0.31, 0.92)),
                 ("FOOT_L", (0.12, -0.55, 0.40)), ("FOOT_R", (-0.12, -0.55, 0.40)),
                 ("EXIT_L", (1.10, 0.0, 0.0)), ("CAM_3P", (0, 0.2, 1.4))):
        empty(n, l, c, parent=root, size=0.08)
    set_meta(VEHICLE_README.format(kind="TIKE: one-seat modified kiddie car, ~2.2 m long. Arcade 4-wheel."))
    save("vehicle_tike")

# ---------------------------------------------------------------- BIKE
def vehicle_bike():
    reset()
    M = [mat("Paint", (0.80, 0.07, 0.04), 0.35), mat("Frame", (0.95, 0.75, 0.05), 0.4, 0.3),
         mat("Chrome", (0.80, 0.80, 0.82), 0.2, 1.0), mat("Rubber", (0.04, 0.04, 0.04), 0.9),
         mat("Metal", (0.42, 0.43, 0.44), 0.4, 0.8), mat("Plate", (0.93, 0.93, 0.90), 0.5),
         mat("Seat", (0.10, 0.09, 0.09), 0.8), mat("EyeWhite", (0.97, 0.97, 0.95), 0.3),
         mat("Pupil", (0.03, 0.03, 0.04), 0.2)]
    PA, FR, CH, RB, MT, PLT, SE, EW, PU = range(9)
    c = coll("Bike")
    Rw, Wf, Wr = 0.32, 0.11, 0.13
    head = Vector((0, -0.50, 1.00))
    fax = Vector((0, -0.70, Rw))
    b = MB()
    # ---- frame
    b.path([head, (0, -0.10, 0.92), (0, 0.18, 0.80), (0, 0.24, 0.40)], 0.026, FR, seg=10)
    b.path([head + Vector((0, 0.02, -0.08)), (0, -0.30, 0.42), (0, -0.12, 0.24), (0, 0.24, 0.30)],
           0.024, FR, seg=10)
    for s in (1, -1):
        b.path([(s * 0.08, 0.10, 0.88), (s * 0.10, 0.72, 0.92)], 0.016, FR, joints=False)
        b.tube((s * 0.08, 0.24, 0.45), (s * 0.10, 0.62, 0.88), 0.014, FR)
    # ---- swingarm
    for s in (1, -1):
        b.box((0.03, 0.42, 0.05), (s * 0.08, 0.43, 0.35), MT, rot=(-6, 0, 0), bevel=0.008)
    b.tube((-0.09, 0.24, 0.38), (0.09, 0.24, 0.38), 0.02, MT)
    b.tube((-0.09, 0.64, Rw), (0.09, 0.64, Rw), 0.012, MT)
    # ---- mono shock
    b.tube((0, 0.20, 0.80), (0, 0.38, 0.40), 0.012, CH)
    b.spring((0, 0.215, 0.76), (0, 0.36, 0.45), 0.035, 0.008, 8, FR)
    # ---- engine
    b.box((0.22, 0.34, 0.24), (0, -0.04, 0.38), MT, bevel=0.03, seg=2)
    for i in range(7):
        b.box((0.20 - 0.01 * (i % 2), 0.16, 0.014), (0, -0.17, 0.54 + i * 0.024), MT, rot=(-20, 0, 0))
    b.box((0.14, 0.12, 0.06), (0, -0.23, 0.72), MT, rot=(-20, 0, 0), bevel=0.015)
    b.cyl(0.09, 0.04, (0.12, 0.02, 0.36), MT, rot=(0, 90, 0), seg=18)                       # clutch cover
    b.cyl(0.06, 0.08, (-0.12, -0.02, 0.56), RB, rot=(0, 90, 0), seg=14)                      # air box
    # ---- exhaust (high scrambler pipe, right side)
    b.path([(-0.04, -0.28, 0.62), (-0.12, -0.32, 0.50), (-0.16, -0.16, 0.42), (-0.17, 0.12, 0.60),
            (-0.17, 0.36, 0.72)], 0.024, CH, seg=10)
    b.cyl(0.05, 0.32, (-0.17, 0.52, 0.76), CH, rot=(-80, 0, 0), seg=14, bevel=0.01)
    b.box((0.02, 0.34, 0.09), (-0.22, 0.48, 0.74), MT, rot=(-10, 0, 0), bevel=0.005)        # heat shield
    # ---- bodywork
    b.box((0.28, 0.40, 0.18), (0, -0.16, 0.98), PA, rot=(8, 0, 0), bevel=0.06, seg=3)        # tank
    b.cyl(0.03, 0.03, (0, -0.10, 1.08), CH, seg=10)                                          # filler cap
    b.box((0.24, 0.62, 0.08), (0, 0.32, 0.93), SE, rot=(-3, 0, 0), bevel=0.035, seg=3)       # seat
    b.box((0.15, 0.46, 0.03), (0, 0.84, 0.86), PA, rot=(14, 0, 0), bevel=0.012, seg=2)      # rear fender
    for s in (1, -1):
        b.box((0.02, 0.24, 0.18), (s * 0.13, 0.52, 0.78), PLT, rot=(-8, 0, 0), bevel=0.02, seg=2)  # side plates
        b.box((0.16, 0.05, 0.02), (s * 0.14, 0.10, 0.30), MT)                                   # footpegs
    b.box((0.08, 0.04, 0.05), (0, 1.07, 0.90), PA, bevel=0.01)                                 # tail light
    root = b.finish("Bike", M, c)

    # ---- steer assembly: forks, clamps, bars, headlight, front fender (pivots at head)
    st = MB()
    for s in (1, -1):
        st.tube((s * 0.08, -0.47, 1.06), (s * 0.08, -0.60, 0.66), 0.026, CH, seg=12)   # stanchion
        st.tube((s * 0.08, -0.60, 0.68), (s * 0.08, -0.70, Rw), 0.032, MT, seg=12)     # lower leg
    for z, y in ((1.06, -0.47), (0.92, -0.51)):
        st.box((0.24, 0.07, 0.04), (0, y, z), MT, rot=(-18, 0, 0), bevel=0.01)
    st.path([(-0.38, -0.40, 1.18), (-0.16, -0.44, 1.14), (0.16, -0.44, 1.14), (0.38, -0.40, 1.18)], 0.012, CH)
    for s in (1, -1):
        st.tube((s * 0.04, -0.46, 1.08), (s * 0.06, -0.44, 1.14), 0.012, CH)
        st.cyl(0.018, 0.12, (s * 0.34, -0.41, 1.175), RB, rot=(0, 90, 0), seg=10)       # grips
        st.box((0.08, 0.02, 0.012), (s * 0.24, -0.47, 1.16), MT)                         # levers
    st.cyl(0.08, 0.06, (0, -0.60, 0.96), CH, rot=(72, 0, 0), seg=18)                    # headlight
    st.cyl(0.068, 0.02, (0, -0.63, 0.95), PLT, rot=(72, 0, 0), seg=18)
    st.box((0.26, 0.04, 0.22), (0, -0.58, 0.80), FR, rot=(-18, 0, 0), bevel=0.03, seg=2)  # number board
    st.box((0.14, 0.34, 0.025), (0, -0.72, 0.69), PA, rot=(-10, 0, 0), bevel=0.01, seg=2)   # front fender
    eyes, n = face(st, (0, -0.58, 0.80), -18, 0.02, 0.035, 0.062, 0.042, -0.06, 0.15, FR, EW, RB, lid_angle=16)
    steer = st.finish("Steer", M, c, origin=head, parent=root)
    pupils(eyes, n, 0.019, M, c, steer, PU)

    wm = [M[RB], M[MT], M[CH]]
    wheel("Wheel_F", fax, Rw, Wf, c, steer, wm, knobs=26)
    wheel("Wheel_R", (0, 0.64, Rw), Rw, Wr, c, root, wm, knobs=26)

    collider("Bike_COL", (0.36, 1.70, 0.90), (0, 0.0, 0.62), c)
    for n, l in (("SEAT", (0, 0.24, 0.98)), ("HAND_L", (0.34, -0.41, 1.18)), ("HAND_R", (-0.34, -0.41, 1.18)),
                 ("FOOT_L", (0.20, 0.10, 0.32)), ("FOOT_R", (-0.20, 0.10, 0.32)),
                 ("EXIT_L", (0.9, 0.0, 0.0)), ("CAM_3P", (0, 0.2, 1.5))):
        empty(n, l, c, parent=root, size=0.08)
    set_meta(VEHICLE_README.format(kind="BIKE: one-seat scrambler, ~2.0 m long. Drives like the Tike; "
             "the whole model leans about the origin's Y axis when cornering. 'Steer' turns about the "
             "fork axis (head tube) and carries Wheel_F."))
    save("vehicle_bike")

# ---------------------------------------------------------------- SANDBAG BUILD PIECES
BAG_L, BAG_H, BAG_D = 0.5, 0.25, 0.38
WALL_W, WALL_H = 3.0, 3.0
COURSES = int(WALL_H / BAG_H)

def course_bags(x0, x1, course, holes=()):
    """Running-bond bag segments between x0..x1 for one course, with openings cut out."""
    off = 0.0 if course % 2 == 0 else BAG_L / 2
    z0 = course * BAG_H
    segs, x = [], x0 - off
    while x < x1 - 1e-6:
        a, b = max(x, x0), min(x + BAG_L, x1)
        if b - a > 0.05:
            segs.append([a, b])
        x += BAG_L
    for hx0, hx1, hz0, hz1 in holes:
        if z0 + BAG_H <= hz0 + 1e-6 or z0 >= hz1 - 1e-6:
            continue
        nxt = []
        for a, b in segs:
            if b <= hx0 or a >= hx1:
                nxt.append([a, b])
                continue
            if a < hx0 and hx0 - a > 0.05:
                nxt.append([a, hx0])
            if b > hx1 and b - hx1 > 0.05:
                nxt.append([hx1, b])
        segs = nxt
    return segs

def bag(m, a, b, course, y=0.0, along_y=False, jitter=0):
    L = b - a - 0.012
    c = (a + b) / 2
    z = course * BAG_H + BAG_H / 2
    shade = (course + int(a * 4) + jitter) % 3 == 0
    size = (L, BAG_D, BAG_H - 0.012) if not along_y else (BAG_D, L, BAG_H - 0.012)
    loc = (c, y, z) if not along_y else (y, c, z)
    m.box(size, loc, 1 if shade else 0, bevel=0.045, seg=2)

def sandbag_piece(name, holes, lintels, cols, readme):
    reset()
    M = [mat("Sandbag", (0.64, 0.57, 0.40), 0.95), mat("SandbagDark", (0.54, 0.47, 0.33), 0.95),
         mat("Wood", (0.42, 0.28, 0.16), 0.8)]
    c = coll(name)
    m = MB()
    for k in range(COURSES):
        for a, b in course_bags(-WALL_W / 2, WALL_W / 2, k, holes):
            bag(m, a, b, k)
    for (x0, x1, z) in lintels:
        m.box((x1 - x0 + 0.3, BAG_D + 0.04, 0.10), ((x0 + x1) / 2, 0, z), 2, bevel=0.01)
    root = m.finish(name, M, c)
    for i, (sz, loc) in enumerate(cols):
        collider(f"{name}_COL{i}", sz, loc, c)
    for n, l in (("SNAP_L", (-WALL_W / 2, 0, 0)), ("SNAP_R", (WALL_W / 2, 0, 0)),
                 ("SNAP_TOP", (0, 0, WALL_H))):
        empty(n, l, c, parent=root, size=0.2)
    set_meta(readme)
    save("build_" + name.lower())

PIECE_README = """SANDBAG BUILD PIECE: {kind}
Rust-style snapping on a 3 m cell. Wall: 3.0 m wide, 3.0 m high, {d} m thick.
Origin at bottom centre of the wall line; the wall runs along X and sits on the cell edge.
SNAP_L / SNAP_R: neighbouring walls join here. SNAP_TOP: plank floors/roofs sit on top (z = 3.0).
The game adds a foundation below the origin on sloped ground, so do not model one.
Bags: {bl} x {bd} x {bh} m, running bond. Wooden lintels carry bags over openings.
Proposed cost: {cost} sandbags."""

def build_wall():
    sandbag_piece("Wall", [], [], [((WALL_W, BAG_D, WALL_H), (0, 0, WALL_H / 2))],
                  PIECE_README.format(kind="WALL", d=BAG_D, bl=BAG_L, bd=BAG_D, bh=BAG_H, cost=10))

def build_window():
    hz0, hz1 = 1.25, 2.0
    sandbag_piece("WallWindow", [(-0.5, 0.5, hz0, hz1)], [(-0.5, 0.5, hz1 + 0.05)],
                  [((WALL_W, BAG_D, hz0), (0, 0, hz0 / 2)),
                   ((WALL_W, BAG_D, WALL_H - hz1), (0, 0, (hz1 + WALL_H) / 2)),
                   ((1.0, BAG_D, hz1 - hz0), (-1.0, 0, (hz0 + hz1) / 2)),
                   ((1.0, BAG_D, hz1 - hz0), (1.0, 0, (hz0 + hz1) / 2))],
                  PIECE_README.format(kind="WALL WITH WINDOW (1.0 x 0.75 m, sill at 1.25 m: shoot "
                                      "standing, hide crouched)", d=BAG_D, bl=BAG_L, bd=BAG_D, bh=BAG_H, cost=9))

def build_door():
    hz1 = 2.25
    sandbag_piece("WallDoor", [(-0.5, 0.5, 0, hz1)], [(-0.5, 0.5, hz1 + 0.05)],
                  [((1.0, BAG_D, WALL_H), (-1.0, 0, WALL_H / 2)), ((1.0, BAG_D, WALL_H), (1.0, 0, WALL_H / 2)),
                   ((1.0, BAG_D, WALL_H - hz1), (0, 0, (hz1 + WALL_H) / 2))],
                  PIECE_README.format(kind="WALL WITH DOORWAY (1.0 x 2.25 m, open; a door leaf "
                                      "can be a separate plank item later)", d=BAG_D, bl=BAG_L, bd=BAG_D,
                                      bh=BAG_H, cost=8))

def build_lwall():
    reset()
    M = [mat("Sandbag", (0.64, 0.57, 0.40), 0.95), mat("SandbagDark", (0.54, 0.47, 0.33), 0.95)]
    c = coll("WallL")
    m = MB()
    t = BAG_D / 2
    for k in range(COURSES):
        # corner bonding: courses alternate which leg covers the corner block
        ax0, by0 = (-t, t) if k % 2 == 0 else (t, -t)
        for a, b in course_bags(ax0, WALL_W, k):
            bag(m, a, b, k)
        for a, b in course_bags(by0, WALL_W, k + 1):
            bag(m, a, b, k, along_y=True, jitter=1)
    root = m.finish("WallL", M, c)
    collider("WallL_COL0", (WALL_W + t, BAG_D, WALL_H), ((WALL_W - t) / 2, 0, WALL_H / 2), c)
    collider("WallL_COL1", (BAG_D, WALL_W - t, WALL_H), (0, (WALL_W + t) / 2, WALL_H / 2), c)
    for n, l in (("SNAP_CORNER", (0, 0, 0)), ("SNAP_A_END", (WALL_W, 0, 0)), ("SNAP_B_END", (0, WALL_W, 0)),
                 ("SNAP_TOP", (WALL_W / 2, WALL_W / 2, WALL_H))):
        empty(n, l, c, parent=root, size=0.2)
    set_meta("SANDBAG BUILD PIECE: L-SHAPED CORNER WALL\nTwo 3 m legs meeting at the origin: leg A runs +X, "
             "leg B runs +Y.\nOrigin = the shared cell corner. Corner bags interlock course by course.\n"
             "SNAP_CORNER, SNAP_A_END, SNAP_B_END, SNAP_TOP (cell centre at roof height).\nProposed cost: 18 sandbags.")
    save("build_walll")

for fn in (vehicle_tike, vehicle_bike, build_wall, build_window, build_door, build_lwall):
    fn()
    print("built", fn.__name__)
