import sys, os
sys.argv = sys.argv[:-2] + sys.argv[-2:]
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "render_v2.py")).read()
exec(src[:src.index("for f, pers in")])
for f in ("vehicle_tike", "vehicle_bike"):
    scene(f); frame((0.55, -1.7, 0.45), 1.0); render(f + "_face")
