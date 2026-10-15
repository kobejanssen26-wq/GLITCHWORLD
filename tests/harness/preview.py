#!/usr/bin/env python3
"""Render PNG previews from the dump_test output (stdin): target sheet (front view, both states) + valley map."""
import sys, math
from PIL import Image, ImageDraw, ImageFont
lines = [l.strip() for l in sys.stdin if l.startswith(("PART|", "HROW|", "TGT|", "SEC|", "STA|", "DEC|"))]
parts, hrows, tgts, secs, stas, decs = {}, {}, [], [], [], []
for l in lines:
    f = l.split("|")
    if f[0] == "PART":
        sx, sy, sz = map(float, f[4].split(",")); px, py, pz = map(float, f[5].split(",")); r = list(map(float, f[6].split(",")))
        col = tuple(float(v) for v in f[7].split(",")); parts.setdefault(f[1], {}).setdefault(f[2], []).append((f[3], (sx, sy, sz), (px, py, pz), r, col, f[8], float(f[9])))
    elif f[0] == "HROW": hrows[int(f[1])] = list(map(float, f[2].split(",")))
    elif f[0] == "TGT": tgts.append((f[1], f[2], int(f[3]), int(f[4])))
    elif f[0] == "SEC": secs.append((int(f[2]), int(f[3])))
    elif f[0] == "STA": stas.append((f[1], int(f[2]), int(f[3])))
    elif f[0] == "DEC": decs.append((f[1], int(f[2]), int(f[3])))

def hull(pts):
    pts = sorted(set(pts))
    if len(pts) <= 2: return pts
    def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lo = []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    up = []
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]

def render_part(draw, part, ox, oy, scale, view):
    shape, (sx, sy, sz), (px, py, pz), r, col, mat, tr = part
    if tr >= 0.99: return
    def to2(x, y, z): return (ox + (x if view == "front" else x) * scale, oy - (y if view == "front" else z) * scale)
    c = tuple(int(255 * min(1, v * (1.35 if mat == "Neon" else 1))) for v in col)
    alpha = int(255 * (1 - tr))
    if shape == "ball":
        cx, cy = to2(px, py, pz); rad = sx / 2 * scale
        draw.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=c + (alpha,), outline=(0, 0, 0, 90))
        return
    corners = []
    for ax in (-.5, .5):
        for ay in (-.5, .5):
            for az in (-.5, .5):
                lx, ly, lz = ax * sx, ay * sy, az * sz
                wx = px + r[0]*lx + r[1]*ly + r[2]*lz; wy = py + r[3]*lx + r[4]*ly + r[5]*lz; wz = pz + r[6]*lx + r[7]*ly + r[8]*lz
                corners.append(to2(wx, wy, wz))
    draw.polygon(hull(corners), fill=c + (alpha,), outline=(0, 0, 0, 110))

order = ["grass", "bush", "tree", "crystal", "ruin", "capsule", "anomaly", "bloom", "prism_vein", "surge_node", "rift_core"]
cell = 260; scale = 13
img = Image.new("RGBA", (cell * 4, cell * 6), (150, 190, 215, 255))
d = ImageDraw.Draw(img, "RGBA")
for i, typ in enumerate(order):
    for s, state in enumerate(("Corrupted", "Restored")):
        col, row = (i % 2) * 2 + s, i // 2
        ox, oy = col * cell + cell // 2, row * cell + cell - 40
        d.rectangle((col * cell, row * cell, (col + 1) * cell - 2, (row + 1) * cell - 2), fill=(165, 200, 225, 255) if state == "Restored" else (92, 84, 112, 255))
        d.rectangle((col * cell, oy, (col + 1) * cell - 2, (row + 1) * cell - 2), fill=(96, 150, 70, 255) if state == "Restored" else (80, 78, 96, 255))
        items = [p for p in parts.get(typ, {}).get(state, []) + parts.get(typ, {}).get("Shared", [])]
        items.sort(key=lambda p: -p[2][2])  # far (+z) first
        for p in items: render_part(d, p, ox, oy, scale, "front")
        d.text((col * cell + 6, row * cell + 4), f"{typ} / {state}", fill=(255, 255, 255, 255))
img.convert("RGB").save(sys.argv[1] + "/targets.png")

# valley map: heightmap shading + placements
S = 3
W = 300 * S
m = Image.new("RGB", (W, W), (20, 20, 30))
px = m.load()
xs = sorted(hrows)
for xi, x in enumerate(xs):
    row = hrows[x]
    for zi, h in enumerate(row):
        z = -150 + zi * 2
        shade = max(0, min(255, int(90 + h * 5)))
        c = (shade // 2, shade, shade // 2) if h > -1.2 else (60, 80, 200)
        if h > 20: c = (150, 140, 130)
        for dx in range(2 * S):
            for dz in range(2 * S):
                X, Z = (x + 150) * S + dx, (z + 150) * S + dz
                if 0 <= X < W and 0 <= Z < W: px[X, Z] = c
d = ImageDraw.Draw(m)
colors = {"grass": (140, 255, 140), "bush": (60, 200, 90), "tree": (20, 120, 40), "crystal": (255, 120, 255), "ruin": (230, 200, 120), "capsule": (60, 255, 255), "anomaly": (255, 255, 90),
          "bloom": (190, 120, 255), "prism_vein": (120, 200, 255), "surge_node": (255, 150, 60), "rift_core": (255, 60, 60)}
for kind, x, z in decs: d.ellipse(((x + 150) * S - 2, (z + 150) * S - 2, (x + 150) * S + 2, (z + 150) * S + 2), fill=(200, 255, 200))
for _id, typ, x, z in tgts:
    r = 4 if typ in ("ruin", "tree", "rift_core") else 3
    d.ellipse(((x + 150) * S - r, (z + 150) * S - r, (x + 150) * S + r, (z + 150) * S + r), fill=colors[typ], outline=(0, 0, 0))
for x, z in secs: d.rectangle(((x + 150) * S - 3, (z + 150) * S - 3, (x + 150) * S + 3, (z + 150) * S + 3), outline=(255, 255, 0))
for name, x, z in stas: d.rectangle(((x + 150) * S - 6, (z + 150) * S - 6, (x + 150) * S + 6, (z + 150) * S + 6), fill=(255, 255, 255), outline=(0, 0, 0)); d.text(((x + 150) * S + 8, (z + 150) * S - 5), name, fill=(255, 255, 255))
d.text((10, 10), "N (-z) up. Valley map. White squares=stations, yellow=hidden shards, dots=targets", fill=(255, 255, 255))
m.save(sys.argv[1] + "/valley_map.png")
print("saved")

ids = [k for k in parts if k.startswith("echo_")]
cell2 = 200; sc = 40
img2 = Image.new("RGB", (cell2 * 4, cell2 * 3), (40, 36, 70))
d2 = ImageDraw.Draw(img2, "RGBA")
for i, k in enumerate(sorted(ids)):
    ox, oy = (i % 4) * cell2 + cell2 // 2, (i // 4) * cell2 + cell2 // 2 + 20
    items = sorted(parts[k]["Echo"], key=lambda p: -p[2][2])
    for pt in items: render_part(d2, pt, ox, oy, sc, "front")
    d2.text(((i % 4) * cell2 + 6, (i // 4) * cell2 + 4), k[5:], fill=(255, 255, 255, 255))
img2.save(sys.argv[1] + "/echoes.png")
