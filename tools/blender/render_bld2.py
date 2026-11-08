import sys, os
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "render_v2.py")).read()
exec(src[:src.index("for f, pers in")])
for f, d in (("bld_dealership", (0.8, -1.7, 0.9)), ("pine", (1.2, -1.6, 0.5))):
    scene(f); frame(d, 1.05, (800, 600)); render(f)
