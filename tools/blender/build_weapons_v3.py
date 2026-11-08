"""SudoFPS weapons v3: more detailed low-poly guns and melee. Same origins, part names and markers as v1.
Run: python build_weapons_v3.py <outdir>"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler
_d = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_d, "build_templates_v2.py")).read()
exec(_src[:_src.index("# ---------------------------------------------------------------- TIKE")])

WEAPON_README = """WEAPON TEMPLATE ({kind})
Origin = where the right palm grips. Barrel / business end points -Y. Up is +Z. 1 BU = 1 m.
Attach to the character's SOCKET_Weapon_R with zero offset.
Moving parts are separate objects with their own pivot (Mag, Slide, Pump) so they can be animated.
Markers (empties): MUZZLE, EJECT, AIM (sight: camera lines up AIM -> MUZZLE when aiming), GRIP_L,
HIT_BASE / HIT_TIP (melee hit line). Materials: Metal, Polymer, Wood, Accent, Dark, Rubber, Brass, Glass."""

def W():
    return [mat("Metal", (0.035, 0.036, 0.04), 0.35, 0.9), mat("Polymer", (0.025, 0.025, 0.027), 0.6),
            mat("Wood", (0.20, 0.09, 0.035), 0.55), mat("Accent", (0.30, 0.28, 0.22), 0.5, 0.6),
            mat("Dark", (0.006, 0.006, 0.007), 0.8), mat("Rubber", (0.015, 0.015, 0.015), 0.95),
            mat("Brass", (0.55, 0.38, 0.12), 0.3, 1.0), mat("Glass", (0.6, 0.05, 0.03), 0.1)]
MT, PO, WD, AC, DK, RB, BR, GL = range(8)
X90 = (0, 90, 0)    # cylinder along X
Y90 = (90, 0, 0)    # cylinder along Y (barrel axis)

def trigger(m, y, z, guard_len=0.06, mat_i=PO):
    m.path([(0, y - guard_len, z), (0, y - guard_len, z - 0.035), (0, y, z - 0.04), (0, y + 0.015, z - 0.02)],
           0.0045, mat_i, seg=6)
    m.box((0.006, 0.008, 0.024), (0, y - guard_len * 0.45, z - 0.016), MT, rot=(-15, 0, 0), bevel=0.002)

def markers(c, root, d):
    for n, l in d.items():
        empty(n, l, c, parent=root, size=0.02)

# ---------------------------------------------------------------- pistol
def pistol():
    reset(); M = W(); c = coll("Pistol")
    f = MB()
    f.box((0.029, 0.048, 0.11), (0, 0.010, -0.012), PO, rot=(18, 0, 0), bevel=0.006, seg=2)          # grip
    for k in range(3):
        f.box((0.031, 0.006, 0.012), (0, -0.016 + k * 0.004, -0.004 - k * 0.026), PO, rot=(18, 0, 0), bevel=0.002)
    f.box((0.027, 0.13, 0.022), (0, -0.045, 0.036), PO, bevel=0.004, seg=2)                         # frame
    f.box((0.022, 0.05, 0.006), (0, -0.082, 0.024), DK)                                               # rail
    trigger(f, -0.02, 0.026)
    f.box((0.026, 0.02, 0.012), (0, 0.032, 0.040), PO, bevel=0.003)                                   # beavertail
    root = f.finish("Pistol", M, c)
    s = MB()
    s.box((0.030, 0.19, 0.034), (0, -0.065, 0.0625), MT, bevel=0.004, seg=2)
    for k in range(7):
        for x in (-0.0152, 0.0152):
            s.box((0.002, 0.003, 0.026), (x, 0.012 + k * 0.006 - 0.04, 0.062), DK)
    s.box((0.002, 0.045, 0.014), (0.0152, -0.045, 0.068), DK)                                         # eject port
    s.cyl(0.0068, 0.012, (0, -0.158, 0.060), DK, rot=Y90, seg=12)                                    # muzzle
    s.box((0.004, 0.006, 0.008), (0, -0.150, 0.0835), AC)                                             # front sight
    for x in (-0.0055, 0.0055):
        s.box((0.004, 0.008, 0.009), (x, 0.022, 0.084), MT)                                           # rear sight
    s.finish("Slide", M, c, origin=(0, 0.03, 0.0625), parent=root)
    g = MB()
    g.box((0.022, 0.034, 0.10), (0, 0.010, -0.02), MT, rot=(18, 0, 0))
    g.box((0.031, 0.048, 0.012), (0, 0.030, -0.070), PO, rot=(18, 0, 0), bevel=0.003)
    g.finish("Mag", M, c, origin=(0, 0.008, 0.03), parent=root)
    markers(c, root, {"MUZZLE": (0, -0.165, 0.060), "EJECT": (0.017, -0.04, 0.072), "AIM": (0, 0.022, 0.086)})
    set_meta("PISTOL v3 (compact polymer pistol). " + WEAPON_README.format(kind="one-handed, ~20 cm"))
    save("weapon_pistol")

# ---------------------------------------------------------------- uzi
def uzi():
    reset(); M = W(); c = coll("UZI")
    f = MB()
    f.box((0.046, 0.25, 0.066), (0, -0.04, 0.078), MT, bevel=0.006, seg=2)                            # receiver
    for k in range(9):
        f.box((0.048, 0.006, 0.006), (0, -0.14 + k * 0.024, 0.112), DK)                               # top ribs
    f.cyl(0.018, 0.03, (0, -0.177, 0.075), MT, rot=Y90, seg=14)                                       # barrel nut
    f.cyl(0.009, 0.05, (0, -0.205, 0.075), DK, rot=Y90, seg=12)                                       # barrel
    f.box((0.036, 0.05, 0.10), (0, 0.0, -0.01), PO, bevel=0.008, seg=2)                               # grip
    f.box((0.038, 0.012, 0.03), (0, 0.03, -0.02), PO, rot=(10, 0, 0), bevel=0.003)                    # grip safety
    trigger(f, -0.035, 0.045, 0.04)
    f.cyl(0.008, 0.03, (0.0, -0.09, 0.122), AC, seg=10)                                               # cocking knob
    f.box((0.012, 0.01, 0.022), (0, -0.155, 0.122), MT)                                               # front sight
    f.box((0.012, 0.01, 0.018), (0, 0.07, 0.120), MT)                                                 # rear sight
    for x in (-0.026, 0.026):                                                                         # folded stock
        f.path([(x, 0.085, 0.05), (x, 0.09, 0.02), (x, -0.12, 0.02)], 0.004, MT, seg=6)
    f.box((0.06, 0.012, 0.03), (0, -0.125, 0.02), MT, bevel=0.003)
    root = f.finish("UZI", M, c)
    g = MB()
    g.box((0.024, 0.030, 0.20), (0, 0, -0.07), MT, bevel=0.002)
    g.box((0.030, 0.036, 0.012), (0, 0, -0.17), PO, bevel=0.003)
    g.finish("Mag", M, c, origin=(0, 0, 0.03), parent=root)
    markers(c, root, {"MUZZLE": (0, -0.232, 0.075), "EJECT": (0.024, -0.02, 0.09), "AIM": (0, 0.07, 0.128)})
    set_meta("UZI v3. " + WEAPON_README.format(kind="one-handed, ~31 cm"))
    save("weapon_uzi")

# ---------------------------------------------------------------- shotgun
def shotgun():
    reset(); M = W(); c = coll("Shotgun")
    f = MB()
    f.box((0.044, 0.20, 0.07), (0, -0.12, 0.038), MT, bevel=0.006, seg=2)                             # receiver
    f.box((0.002, 0.07, 0.03), (0.0225, -0.12, 0.04), DK)                                             # eject port
    f.cyl(0.0115, 0.52, (0, -0.48, 0.058), MT, rot=Y90, seg=16)                                       # barrel
    f.cyl(0.0105, 0.44, (0, -0.44, 0.030), MT, rot=Y90, seg=14)                                       # mag tube
    f.cyl(0.013, 0.02, (0, -0.665, 0.030), MT, rot=Y90, seg=14)                                       # mag cap
    f.box((0.026, 0.03, 0.04), (0, -0.66, 0.046), MT, bevel=0.003)                                    # barrel clamp
    f.sphere(0.004, (0, -0.735, 0.072), BR)                                                           # bead
    f.box((0.008, 0.36, 0.006), (0, -0.50, 0.072), MT)                                                # vent rib
    f.cyl(0.011, 0.004, (0, -0.741, 0.058), DK, rot=Y90, seg=14)                                      # muzzle
    trigger(f, -0.04, 0.005, 0.05, MT)
    f.box((0.036, 0.09, 0.05), (0, 0.01, 0.022), WD, rot=(-12, 0, 0), bevel=0.012, seg=2)            # wrist
    f.box((0.040, 0.25, 0.075), (0, 0.17, -0.005), WD, rot=(-8, 0, 0), bevel=0.015, seg=2)            # stock
    f.box((0.044, 0.02, 0.11), (0, 0.297, -0.02), RB, rot=(-8, 0, 0), bevel=0.01, seg=2)              # butt pad
    root = f.finish("Shotgun", M, c)
    p = MB()
    p.box((0.05, 0.17, 0.048), (0, -0.40, 0.024), WD, bevel=0.016, seg=3)
    for k in range(7):
        p.box((0.052, 0.005, 0.044), (0, -0.46 + k * 0.02, 0.024), DK, bevel=0.002)
    p.finish("Pump", M, c, origin=(0, -0.40, 0.024), parent=root)
    markers(c, root, {"MUZZLE": (0, -0.745, 0.058), "EJECT": (0.024, -0.12, 0.05), "AIM": (0, -0.05, 0.08),
                      "GRIP_L": (0, -0.40, -0.005)})
    set_meta("SHOTGUN v3 (pump). " + WEAPON_README.format(kind="two-handed, ~1.07 m"))
    save("weapon_shotgun")

# ---------------------------------------------------------------- rifle
def rifle():
    reset(); M = W(); c = coll("Rifle")
    f = MB()
    f.box((0.030, 0.045, 0.10), (0, 0.012, -0.028), PO, rot=(22, 0, 0), bevel=0.007, seg=2)           # pistol grip
    f.box((0.034, 0.20, 0.05), (0, -0.05, 0.040), MT, bevel=0.005, seg=2)                             # lower
    f.box((0.036, 0.024, 0.06), (0, -0.12, 0.02), MT, bevel=0.004)                                    # mag well
    trigger(f, -0.03, 0.017, 0.065, MT)
    f.box((0.032, 0.22, 0.042), (0, -0.07, 0.087), MT, bevel=0.005, seg=2)                            # upper
    f.box((0.002, 0.06, 0.02), (0.0165, -0.06, 0.088), DK)                                            # eject port
    for k in range(14):                                                                               # rail
        f.box((0.022, 0.009, 0.008), (0, -0.175 + k * 0.016, 0.112), DK)
    f.box((0.018, 0.22, 0.004), (0, -0.07, 0.108), MT)
    f.box((0.012, 0.03, 0.012), (0, 0.035, 0.105), AC, bevel=0.002)                                   # charging handle
    f.cyl(0.026, 0.27, (0, -0.315, 0.087), PO, rot=Y90, seg=12, bevel=0.004)                          # handguard
    for k in range(6):
        for s in (-1, 1):
            f.box((0.004, 0.022, 0.008), (s * 0.026, -0.23 - k * 0.032, 0.095), DK)                   # vents
    f.cyl(0.0085, 0.22, (0, -0.56, 0.087), MT, rot=Y90, seg=12)                                       # barrel
    f.box((0.022, 0.024, 0.02), (0, -0.47, 0.090), MT, bevel=0.003)                                   # gas block
    f.path([(0, -0.47, 0.10), (0, -0.475, 0.135), (0, -0.48, 0.10)], 0.004, MT, seg=6)                # front sight
    f.cyl(0.012, 0.06, (0, -0.69, 0.087), MT, rot=Y90, seg=12)                                        # flash hider
    for k in range(4):
        f.box((0.026, 0.008, 0.003), (0, -0.69, 0.087), DK, rot=(0, k * 45, 0))
    f.cyl(0.015, 0.20, (0, 0.13, 0.082), MT, rot=Y90, seg=14)                                         # buffer tube
    f.box((0.042, 0.17, 0.07), (0, 0.22, 0.06), PO, rot=(-4, 0, 0), bevel=0.012, seg=2)               # stock
    f.box((0.044, 0.02, 0.10), (0, 0.305, 0.05), RB, bevel=0.01, seg=2)                               # butt
    # red dot sight
    f.box((0.022, 0.05, 0.012), (0, 0.0, 0.122), MT, bevel=0.003)
    f.cyl(0.019, 0.07, (0, 0.0, 0.150), MT, rot=Y90, seg=16, bevel=0.003)
    f.cyl(0.0155, 0.072, (0, 0.0, 0.150), DK, rot=Y90, seg=16)
    f.cyl(0.015, 0.002, (0, -0.02, 0.150), GL, rot=Y90, seg=16)
    f.box((0.012, 0.016, 0.01), (0.022, 0.0, 0.15), MT, bevel=0.002)
    root = f.finish("Rifle", M, c)
    g = MB()
    g.box((0.024, 0.07, 0.10), (0, -0.115, -0.02), MT, rot=(8, 0, 0), bevel=0.004)
    g.box((0.024, 0.07, 0.09), (0, -0.098, -0.105), MT, rot=(20, 0, 0), bevel=0.004)
    g.box((0.028, 0.074, 0.012), (0, -0.083, -0.152), PO, rot=(20, 0, 0), bevel=0.003)
    g.finish("Mag", M, c, origin=(0, -0.12, 0.025), parent=root)
    markers(c, root, {"MUZZLE": (0, -0.722, 0.087), "EJECT": (0.02, -0.05, 0.09), "AIM": (0, 0.03, 0.150),
                      "GRIP_L": (0, -0.32, 0.055)})
    set_meta("RIFLE v3 (AR-style with red dot; AIM is the sight centre). " + WEAPON_README.format(kind="two-handed, ~1.03 m"))
    save("weapon_rifle")

# ---------------------------------------------------------------- knife
def knife():
    reset(); M = W() + [mat("BatWood", (0.5, 0.3, 0.1)), mat("Blade", (0.62, 0.63, 0.66), 0.3, 0.3)]; c = coll("Knife")
    k = MB()
    k.cyl(0.014, 0.11, (0, 0.0, 0), RB, rot=Y90, seg=10)
    for i in range(6):
        k.cyl(0.0155, 0.006, (0, -0.045 + i * 0.018, 0), RB, rot=Y90, seg=10)
    k.cyl(0.016, 0.014, (0, 0.062, 0), MT, rot=Y90, seg=10, bevel=0.003)                              # pommel
    k.box((0.07, 0.008, 0.016), (0, -0.059, 0), MT, bevel=0.003)                                       # guard
    k.box((0.004, 0.13, 0.032), (0, -0.13, 0.002), 9, bevel=0.0015)                                   # blade
    k.box((0.0045, 0.12, 0.004), (0, -0.13, 0.017), AC)                                                # spine
    k.box((0.004, 0.045, 0.026), (0, -0.207, 0.006), 9, rot=(-22, 0, 0), bevel=0.0015)                # tip
    root = k.finish("Knife", M, c)
    markers(c, root, {"HIT_BASE": (0, -0.07, 0), "HIT_TIP": (0, -0.235, 0.006)})
    set_meta("KNIFE v3. " + WEAPON_README.format(kind="one-handed, ~30 cm"))
    save("weapon_knife")

# ---------------------------------------------------------------- bat
def bat():
    reset(); M = W() + [mat("BatWood", (0.52, 0.32, 0.14), 0.5)]
    BW = 8
    c = coll("Bat")
    b = MB()
    b.cyl(0.026, 0.02, (0, 0.10, 0), BW, rot=Y90, seg=16, bevel=0.006)                                 # knob
    b.cyl(0.0155, 0.32, (0, -0.07, 0), BW, rot=Y90, seg=14, r2=0.0175)                                 # handle
    for i in range(10):
        b.cyl(0.0175, 0.02, (0, 0.07 - i * 0.022, 0), RB, rot=(90 + (8 if i % 2 else -8), 0, 0), seg=12)  # tape
    b.cyl(0.0175, 0.22, (0, -0.34, 0), BW, rot=Y90, seg=16, r2=0.032)                                  # taper
    b.cyl(0.032, 0.30, (0, -0.60, 0), BW, rot=Y90, seg=18, r2=0.034)                                   # barrel
    b.cyl(0.034, 0.012, (0, -0.756, 0), BW, rot=Y90, seg=18, bevel=0.008, bseg=2)                      # end cap
    b.box((0.002, 0.08, 0.02), (0.033, -0.55, 0), DK)                                                  # logo burn
    root = b.finish("Bat", M, c)
    markers(c, root, {"HIT_BASE": (0, -0.40, 0), "HIT_TIP": (0, -0.76, 0), "GRIP_L": (0, 0.06, 0)})
    set_meta("BAT v3. " + WEAPON_README.format(kind="~0.86 m"))
    save("weapon_bat")

for fn in (pistol, uzi, shotgun, rifle, knife, bat):
    fn()
    print("built", fn.__name__)
