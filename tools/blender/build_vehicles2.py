"""SudoFPS vehicles v2: ATV, 80s sport sedan (generic, no brand), military utility helicopter (generic).
Run with Blender 4.2 Python: python build_vehicles2.py <outdir>"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler
_d = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_d, "build_templates_v2.py")).read()
exec(_src[:_src.index("# ---------------------------------------------------------------- TIKE")])

def hull(m, pts, mi):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    m._push(bm, mi)
MB.hull = hull

def markers(c, root, d):
    for n, l in d.items():
        empty(n, l, c, parent=root, size=0.08)

# ---------------------------------------------------------------- ATV
def atv():
    reset()
    M = [mat("Paint", (0.08, 0.30, 0.10), 0.4), mat("Frame", (0.05, 0.05, 0.05), 0.5, 0.4),
         mat("Rubber", (0.03, 0.03, 0.03), 0.9), mat("Metal", (0.4, 0.4, 0.42), 0.4, 0.8),
         mat("Seat", (0.06, 0.05, 0.05), 0.8), mat("Light", (0.95, 0.95, 0.85), 0.2)]
    PA, FR, RB, MT, SE, LI = range(6)
    c = coll("ATV")
    b = MB()
    b.box((0.70, 1.30, 0.30), (0, 0.0, 0.50), FR, bevel=0.03, seg=2)                       # chassis
    b.box((0.90, 0.55, 0.12), (0, -0.62, 0.78), PA, rot=(-8, 0, 0), bevel=0.05, seg=3)      # front fenders
    b.box((0.95, 0.60, 0.12), (0, 0.62, 0.80), PA, rot=(6, 0, 0), bevel=0.05, seg=3)        # rear fenders
    b.box((0.42, 0.55, 0.25), (0, -0.18, 0.80), PA, bevel=0.06, seg=3)                      # tank
    b.box((0.36, 0.70, 0.10), (0, 0.32, 0.92), SE, bevel=0.04, seg=3)                       # seat
    for s in (1, -1):
        b.box((0.06, 0.40, 0.04), (s * 0.30, -0.95, 0.85), MT)                              # front rack
        b.box((0.06, 0.45, 0.04), (s * 0.32, 1.0, 0.88), MT)                                # rear rack
        b.box((0.12, 0.30, 0.03), (s * 0.30, 0.0, 0.40), MT)                                # footrests
        b.tube((s * 0.10, -0.4, 0.45), (s * 0.48, -0.62, 0.32), 0.02, MT)                   # a-arms
        b.tube((s * 0.10, 0.4, 0.45), (s * 0.48, 0.62, 0.32), 0.02, MT)
    b.box((0.62, 0.04, 0.04), (0, -1.15, 0.85), MT)
    b.box((0.66, 0.04, 0.04), (0, 1.22, 0.88), MT)
    for s in (1, -1):
        b.box((0.12, 0.05, 0.06), (s * 0.18, -0.92, 0.72), LI, bevel=0.01)                  # headlights
    root = b.finish("ATV", M, c)
    st = MB()
    head = Vector((0, -0.42, 0.95))
    st.tube((0, -0.42, 0.85), (0, -0.40, 1.05), 0.025, MT)
    st.path([(-0.38, -0.36, 1.08), (-0.15, -0.40, 1.05), (0.15, -0.40, 1.05), (0.38, -0.36, 1.08)], 0.014, FR)
    for s in (1, -1):
        st.cyl(0.02, 0.12, (s * 0.34, -0.37, 1.075), RB, rot=(0, 90, 0), seg=10)
    st.finish("Steer", M, c, origin=head, parent=root)
    wm = [M[RB], M[MT], M[FR]]
    for nm, x, y, R, W in (("Wheel_FL", 0.52, -0.62, 0.30, 0.24), ("Wheel_FR", -0.52, -0.62, 0.30, 0.24),
                           ("Wheel_RL", 0.54, 0.62, 0.32, 0.28), ("Wheel_RR", -0.54, 0.62, 0.32, 0.28)):
        wheel(nm, (x, y, R), R, W, c, root, wm, knobs=20)
    collider("ATV_COL", (1.2, 2.1, 0.8), (0, 0, 0.6), c)
    markers(c, root, {"SEAT": (0, 0.30, 0.98), "HAND_L": (0.34, -0.37, 1.08), "HAND_R": (-0.34, -0.37, 1.08),
                      "EXIT_L": (1.1, 0, 0), "CAM_3P": (0, 0.3, 1.5)})
    set_meta(VEHICLE_README.format(kind="ATV: one-seat quad bike, ~2.2 m long. Arcade 4-wheel, front wheels and 'Steer' turn."))
    save("vehicle_atv")

# ---------------------------------------------------------------- 80s sport sedan (generic)
def sedan():
    reset()
    M = [mat("Paint", (0.75, 0.04, 0.03), 0.25, 0.3), mat("Trim", (0.02, 0.02, 0.02), 0.5),
         mat("Glass", (0.04, 0.06, 0.08), 0.05, 0.3), mat("Rubber", (0.03, 0.03, 0.03), 0.9),
         mat("Rim", (0.55, 0.56, 0.58), 0.3, 0.9), mat("Light", (0.95, 0.95, 0.85), 0.2),
         mat("Tail", (0.6, 0.02, 0.02), 0.2), mat("Interior", (0.10, 0.09, 0.09), 0.8)]
    PA, TR, GL, RB, RIM, LI, TL, IN = range(8)
    c = coll("Sedan")
    b = MB()
    L, Wd = 4.35, 1.70
    b.box((Wd, L, 0.55), (0, 0, 0.58), PA, bevel=0.05, seg=2)                                # lower body
    for s in (1, -1):                                                                        # boxy wheel-arch flares
        for y in (-1.30, 1.32):
            b.box((0.10, 0.95, 0.30), (s * (Wd / 2 + 0.02), y, 0.68), PA, bevel=0.03, seg=2)
    b.box((Wd + 0.04, 0.12, 0.22), (0, -L / 2 - 0.02, 0.42), TR, bevel=0.02)                  # front bumper
    b.box((Wd + 0.04, 0.12, 0.22), (0, L / 2 + 0.02, 0.42), TR, bevel=0.02)                   # rear bumper
    b.box((Wd - 0.1, 0.10, 0.06), (0, -L / 2 - 0.08, 0.30), TR)                               # front lip spoiler
    for s in (1, -1):
        b.box((0.30, 0.04, 0.12), (s * 0.55, -L / 2 - 0.005, 0.70), LI, bevel=0.01)          # rectangular twin lamps
        b.box((0.15, 0.04, 0.12), (s * 0.30, -L / 2 - 0.005, 0.70), LI, bevel=0.01)
        b.box((0.42, 0.04, 0.14), (s * 0.55, L / 2 + 0.005, 0.72), TL, bevel=0.01)           # tail lamps
        b.box((0.02, 2.2, 0.06), (s * (Wd / 2 + 0.005), 0.0, 0.50), TR)                       # side strip
    b.box((0.70, 0.04, 0.10), (0, -L / 2 - 0.005, 0.70), TR)                                  # plain black grille bar
    # cabin: glass box with pillars
    b.hull([(-0.80, -0.55, 0.85), (0.80, -0.55, 0.85), (-0.80, 1.05, 0.85), (0.80, 1.05, 0.85),
            (-0.70, -0.15, 1.33), (0.70, -0.15, 1.33), (-0.70, 0.85, 1.33), (0.70, 0.85, 1.33)], GL)
    b.box((1.42, 1.02, 0.05), (0, 0.35, 1.355), PA, bevel=0.02)                                # roof
    for s in (1, -1):
        b.box((0.06, 0.06, 0.52), (s * 0.76, -0.36, 1.08), PA, rot=(-38, 0, 0))               # A-pillars
        b.box((0.06, 0.10, 0.48), (s * 0.76, 0.96, 1.08), PA, rot=(14, 0, 0))                 # C-pillars
    b.box((Wd - 0.2, 0.30, 0.04), (0, L / 2 - 0.15, 0.88), PA)                                 # boot lid
    b.box((1.30, 0.10, 0.05), (0, L / 2 - 0.08, 0.96), TR)                                     # rear lip spoiler
    b.box((0.10, 0.12, 0.10), (0.86, -0.50, 0.98), TR)                                         # mirror
    b.box((1.40, 0.35, 0.22), (0, -0.12, 0.93), IN)                                             # dashboard
    b.box((0.50, 0.50, 0.15), (0.38, 0.25, 0.78), IN)                                           # seats
    b.box((0.50, 0.10, 0.55), (0.38, 0.52, 1.00), IN)
    b.box((0.50, 0.50, 0.15), (-0.38, 0.25, 0.78), IN)
    b.box((0.50, 0.10, 0.55), (-0.38, 0.52, 1.00), IN)
    root = b.finish("Sedan", M, c)
    sw = MB()
    col_top = Vector((0.38, -0.08, 1.05))
    axis = Vector((0, 0.45, 0.25)).normalized()
    sw.path(ring(col_top, axis, 0.18, 20), 0.016, TR, closed=True, joints=False)
    for p in ring(col_top, axis, 0.18, 3):
        sw.tube(col_top, p, 0.012, TR)
    sw.finish("SteeringWheel", M, c, origin=col_top, parent=root)
    wm = [M[RB], M[RIM], M[TR]]
    for nm, x, y in (("Wheel_FL", 0.76, -1.30), ("Wheel_FR", -0.76, -1.30), ("Wheel_RL", 0.76, 1.32), ("Wheel_RR", -0.76, 1.32)):
        wheel(nm, (x, y, 0.31), 0.31, 0.22, c, root, wm, knobs=0, rim_r=0.68)
    collider("Sedan_COL", (Wd, L, 0.9), (0, 0, 0.75), c)
    markers(c, root, {"SEAT": (0.38, 0.25, 0.90), "HAND_L": (0.52, -0.10, 1.08), "HAND_R": (0.24, -0.10, 1.08),
                      "EXIT_L": (1.5, 0.0, 0), "CAM_3P": (0, 0.5, 1.6)})
    set_meta(VEHICLE_README.format(kind="SPORT SEDAN: generic 1980s two-door sport saloon (no brand badges), 4.35 m."))
    save("vehicle_sedan")

# ---------------------------------------------------------------- utility helicopter (generic)
def heli():
    reset()
    M = [mat("Olive", (0.10, 0.12, 0.07), 0.6), mat("Dark", (0.03, 0.03, 0.03), 0.6),
         mat("Glass", (0.05, 0.08, 0.10), 0.05, 0.3), mat("Metal", (0.35, 0.36, 0.37), 0.4, 0.8),
         mat("Rubber", (0.03, 0.03, 0.03), 0.9), mat("Red", (0.6, 0.05, 0.03), 0.4)]
    OL, DK, GL, MT, RB, RD = range(6)
    c = coll("Helicopter")
    b = MB()
    # fuselage: cabin + nose + tapering tail boom
    b.hull([(-1.1, -2.6, 0.55), (1.1, -2.6, 0.55), (-1.1, 1.6, 0.55), (1.1, 1.6, 0.55),
            (-1.05, -2.4, 2.35), (1.05, -2.4, 2.35), (-1.0, 1.6, 2.35), (1.0, 1.6, 2.35)], OL)
    b.hull([(-1.0, -2.6, 0.6), (1.0, -2.6, 0.6), (-0.95, -2.4, 2.3), (0.95, -2.4, 2.3),
            (-0.55, -4.0, 0.8), (0.55, -4.0, 0.8), (-0.4, -3.7, 1.9), (0.4, -3.7, 1.9)], OL)    # nose
    b.hull([(-0.97, -2.55, 1.35), (0.97, -2.55, 1.35), (-0.92, -2.42, 2.25), (0.92, -2.42, 2.25),
            (-0.5, -3.75, 1.4), (0.5, -3.75, 1.4), (-0.38, -3.62, 1.92), (0.38, -3.62, 1.92)], GL)  # windscreen
    b.hull([(-0.9, 1.5, 0.9), (0.9, 1.5, 0.9), (-0.85, 1.5, 2.3), (0.85, 1.5, 2.3),
            (-0.22, 8.6, 1.7), (0.22, 8.6, 1.7), (-0.22, 8.6, 2.15), (0.22, 8.6, 2.15)], OL)     # tail boom
    b.hull([(-0.12, 8.0, 1.9), (0.12, 8.0, 1.9), (-0.12, 9.2, 1.9), (0.12, 9.2, 1.9),
            (-0.1, 8.8, 3.6), (0.1, 8.8, 3.6), (-0.1, 9.5, 3.6), (0.1, 9.5, 3.6)], OL)          # tail fin
    b.box((2.6, 0.7, 0.06), (0, 7.9, 1.75), OL)                                                 # stabiliser
    b.hull([(-0.85, -1.3, 2.3), (0.85, -1.3, 2.3), (-0.85, 1.4, 2.3), (0.85, 1.4, 2.3),
            (-0.6, -1.0, 2.95), (0.6, -1.0, 2.95), (-0.6, 1.2, 2.95), (0.6, 1.2, 2.95)], OL)    # engine deck
    for s in (1, -1):
        b.cyl(0.32, 1.6, (s * 0.55, 0.2, 2.78), DK, rot=(90, 0, 0), seg=12)                     # engine pods
        b.box((0.05, 1.5, 1.2), (s * 1.12, -0.6, 1.45), DK)                                     # door outline
        b.box((0.04, 0.5, 0.4), (s * 1.13, -1.6, 1.9), GL)                                      # cabin windows
        b.box((0.04, 0.5, 0.4), (s * 1.13, 0.6, 1.9), GL)
        b.tube((s * 0.95, -1.9, 0.5), (s * 1.25, -1.9, 0.0), 0.05, MT)                          # main gear struts
        b.tube((s * 0.95, 0.6, 0.6), (s * 1.30, 0.3, 0.0), 0.05, MT)
        b.cyl(0.28, 0.18, (s * 1.3, 0.3, 0.28), RB, rot=(0, 90, 0), seg=14)                    # main wheels
        b.cyl(0.22, 0.14, (s * 1.25, -1.9, 0.22), RB, rot=(0, 90, 0), seg=14)
    b.cyl(0.14, 0.10, (0, 8.2, 1.65), RB, rot=(0, 90, 0), seg=12)                                # tail wheel
    b.cyl(0.18, 0.5, (0, 0.0, 3.15), MT, seg=12)                                                  # rotor mast
    b.box((0.25, 0.06, 0.06), (0, -4.02, 1.2), RD)                                                # nose light
    root = b.finish("Helicopter", M, c)
    r = MB()
    hub = Vector((0, 0.0, 3.42))
    r.cyl(0.32, 0.18, hub, MT, seg=12)
    for k in range(4):
        a = math.radians(45 + k * 90)
        d = Vector((math.cos(a), math.sin(a), 0))
        r.box((0.45, 7.6, 0.05), hub + d * 3.9 + Vector((0, 0, 0.06)), DK, rot=(0, 0, math.degrees(a) - 90))
    r.finish("Rotor", M, c, origin=hub, parent=root)
    t = MB()
    th = Vector((0.18, 9.1, 3.0))
    t.cyl(0.08, 0.12, th, MT, rot=(0, 90, 0), seg=10)
    for k in range(4):
        t.box((0.03, 0.18, 1.3), th + Vector((0.04, 0, 0)), DK, rot=(k * 45, 0, 0))
    t.finish("TailRotor", M, c, origin=th, parent=root)
    collider("Heli_COL_Cabin", (2.3, 6.4, 2.0), (0, -1.0, 1.45), c)
    collider("Heli_COL_Tail", (0.6, 7.0, 1.0), (0, 5.2, 1.9), c)
    markers(c, root, {"SEAT": (0.45, -2.6, 1.2), "EXIT_L": (2.4, -1.5, 0), "CAM_3P": (0, 0, 3.0)})
    set_meta("UTILITY HELICOPTER (generic military transport style). Front -Y. 'Rotor' spins about Z, 'TailRotor' about X.\n"
             "Dev mode only in the game.")
    save("vehicle_heli")

for fn in (atv, sedan, heli):
    fn()
    print("built", fn.__name__)
