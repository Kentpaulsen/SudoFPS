import sys, os
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "render_v2.py")).read()
exec(src[:src.index("for f, pers in")])
for f, d in (("vehicle_atv", (1.4, -1.6, 0.8)), ("vehicle_sedan", (1.4, -1.8, 0.7)), ("vehicle_heli", (1.6, -1.5, 0.7))):
    scene(f); frame(d, 1.05, (800, 600)); render(f)
