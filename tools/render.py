#!/usr/bin/env python3
"""Tiny software renderer for the baked world (.rbxmx) so the map can be inspected without Roblox Studio.
usage: render.py World.rbxmx out_dir   -> top.png, tower_side.png, view_*.png (perspective camera shots)"""
import re, sys, math
from PIL import Image, ImageDraw

def parse(path):
    txt = open(path, encoding='utf-8').read()
    parts = []
    for m in re.finditer(r'<Item class="Part" referent="RBX\d+"><Properties>(.*?)</Properties></Item>', txt):
        body = m.group(1)
        name = re.search(r'<string name="Name">(.*?)</string>', body).group(1)
        c = int(re.search(r'name="Color3uint8">(\d+)<', body).group(1))
        col = ((c >> 16) & 255, (c >> 8) & 255, c & 255)
        mat = int(re.search(r'name="Material">(\d+)<', body).group(1))
        shape = int(re.search(r'name="shape">(\d+)<', body).group(1))
        sz = tuple(float(v) for v in re.search(r'name="size"><X>(.*?)</X><Y>(.*?)</Y><Z>(.*?)</Z>', body).groups())
        cfb = re.search(r'<CoordinateFrame name="CFrame">(.*?)</CoordinateFrame>', body).group(1)
        cf = [float(v) for v in re.findall(r'<[XYZR][0-9]*>(.*?)</', cfb)]
        tr = re.search(r'name="Transparency">(.*?)<', body)
        parts.append(dict(n=name, col=col, mat=mat, shape=shape, sz=sz, cf=cf, tr=float(tr.group(1)) if tr else 0.0))
    return parts

def mul(cf, v):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
    return (x + r00*v[0] + r01*v[1] + r02*v[2], y + r10*v[0] + r11*v[1] + r12*v[2], z + r20*v[0] + r21*v[1] + r22*v[2])

def rotv(cf, v):
    _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
    return (r00*v[0] + r01*v[1] + r02*v[2], r10*v[0] + r11*v[1] + r12*v[2], r20*v[0] + r21*v[1] + r22*v[2])

LIGHT = (0.4, 0.8, 0.35)
def shade(col, n, neon):
    l = math.sqrt(sum(a*a for a in LIGHT)); d = max(0.0, (n[0]*LIGHT[0] + n[1]*LIGHT[1] + n[2]*LIGHT[2]) / l)
    k = 1.0 if neon else 0.45 + 0.65 * d
    return tuple(min(255, int(c * k * (1.25 if neon else 1))) for c in col)

def faces(p):
    sx, sy, sz = [s / 2 for s in p['sz']]
    cf = p['cf']
    if p['shape'] == 1 or True:
        out = []
        # six faces of a box (cylinders drawn as 12-gon prisms; balls as boxes are replaced by discs elsewhere)
        for axis in range(3):
            for sign in (-1, 1):
                n = [0, 0, 0]; n[axis] = sign
                us = [(axis + 1) % 3, (axis + 2) % 3]
                quad = []
                for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    v = [0, 0, 0]; v[axis] = sign * (sx, sy, sz)[axis]
                    v[us[0]] = a * (sx, sy, sz)[us[0]]; v[us[1]] = b * (sx, sy, sz)[us[1]]
                    quad.append(mul(cf, v))
                out.append((quad, rotv(cf, n)))
        return out

def prism(p, sides=12):
    # cylinder along local X
    h, dy, dz = p['sz'][0] / 2, p['sz'][1] / 2, p['sz'][2] / 2
    cf = p['cf']
    ring = [(math.cos(2*math.pi*k/sides)*dy, math.sin(2*math.pi*k/sides)*dz) for k in range(sides)]
    out = []
    for k in range(sides):
        a, b = ring[k], ring[(k+1) % sides]
        quad = [mul(cf, (-h, a[0], a[1])), mul(cf, (h, a[0], a[1])), mul(cf, (h, b[0], b[1])), mul(cf, (-h, b[0], b[1]))]
        mid = ((a[0]+b[0])/2, (a[1]+b[1])/2); ln = math.hypot(*mid) or 1
        out.append((quad, rotv(cf, (0, mid[0]/ln, mid[1]/ln))))
    for sgn in (-1, 1):
        quad = [mul(cf, (sgn*h, r[0], r[1])) for r in ring]
        out.append((quad, rotv(cf, (sgn, 0, 0))))
    return out

def render(parts, cam, look, fov, size, path, maxd=1800, skip=lambda p: False, bg=(24, 16, 52)):
    W, H = size
    img = Image.new('RGB', size, bg)
    d = ImageDraw.Draw(img, 'RGBA')
    fwd = [look[i] - cam[i] for i in range(3)]; l = math.sqrt(sum(a*a for a in fwd)); fwd = [a/l for a in fwd]
    right = (-fwd[2], 0, fwd[0]); rl = math.hypot(right[0], right[2]) or 1; right = (right[0]/rl, 0, right[2]/rl)
    up = (right[1]*fwd[2]-right[2]*fwd[1], right[2]*fwd[0]-right[0]*fwd[2], right[0]*fwd[1]-right[1]*fwd[0])
    f = (H/2) / math.tan(math.radians(fov)/2)
    def proj(v):
        rel = (v[0]-cam[0], v[1]-cam[1], v[2]-cam[2])
        z = rel[0]*fwd[0] + rel[1]*fwd[1] + rel[2]*fwd[2]
        if z < 0.5: return None
        x = rel[0]*right[0] + rel[1]*right[1] + rel[2]*right[2]
        y = rel[0]*up[0] + rel[1]*up[1] + rel[2]*up[2]
        return (W/2 + f*x/z, H/2 - f*y/z, z)
    draws = []
    for p in parts:
        if skip(p): continue
        c = p['cf']
        dist = math.dist((c[0], c[1], c[2]), cam)
        if dist > maxd: continue
        neon = p['mat'] == 288
        if p['shape'] == 0:
            pr = proj((c[0], c[1], c[2]))
            if pr:
                rad = p['sz'][0]/2 * f / pr[2]
                if rad < 0.4: continue
                draws.append((pr[2], 'ball', (pr[0], pr[1], rad, shade(p['col'], (0, 1, 0), neon), p['tr'])))
            continue
        fl = prism(p) if p['shape'] == 2 else faces(p)
        for quad, n in fl:
            # backface cull
            mid = [sum(q[i] for q in quad)/len(quad) for i in range(3)]
            if (n[0]*(cam[0]-mid[0]) + n[1]*(cam[1]-mid[1]) + n[2]*(cam[2]-mid[2])) <= 0: continue
            pts = [proj(q) for q in quad]
            if any(q is None for q in pts): continue
            xs = [q[0] for q in pts]; ys = [q[1] for q in pts]
            if max(xs) < 0 or min(xs) > W or max(ys) < 0 or min(ys) > H: continue
            if (max(xs)-min(xs)) < 0.6 and (max(ys)-min(ys)) < 0.6: continue
            depth = sum(q[2] for q in pts)/len(pts)
            draws.append((depth, 'poly', ([(q[0], q[1]) for q in pts], shade(p['col'], n, neon), p['tr'])))
    draws.sort(key=lambda t: -t[0])
    for depth, kind, data in draws:
        if kind == 'ball':
            x, y, r, col, tr = data
            d.ellipse((x-r, y-r, x+r, y+r), fill=col + (int(255*(1-tr)),))
        else:
            pts, col, tr = data
            d.polygon(pts, fill=col + (int(255*(1-tr)),))
    img.save(path)

if __name__ == '__main__':
    parts = parse(sys.argv[1]); out = sys.argv[2]
    print(len(parts), 'parts')
    def near_tower(p): return math.hypot(p['cf'][0], p['cf'][2]) < 200 and p['cf'][1] > -5
    tower = [p for p in parts if near_tower(p)]
    # overview of the tower from outside
    render(tower, (330, 190, 330), (0, 140, 0), 50, (1100, 900), out + '/tower_far.png', maxd=2000)
    # camera at the start of the climb (hub side)
    render(parts, (150, 30, -60), (60, 18, 40), 70, (1100, 700), out + '/view_start.png', maxd=900, skip=lambda p: p['n'] in ('Cloud',))
    # looking along a floor-3 path
    render(parts, (-20, 95, 100), (-60, 100, 20), 70, (1100, 700), out + '/view_floor.png', maxd=500, skip=lambda p: p['n'] in ('Cloud',))
    # hub overview from above
    render([p for p in parts if math.hypot(p['cf'][0], p['cf'][2]) < 560 and p['cf'][1] < 40], (0, 700, -520), (0, 0, 0), 48, (1100, 800), out + '/hub_far.png', maxd=2500)

def module_sheet(parts, xml_path, out):
    """One perspective shot per obstacle type, camera behind the module's start looking along the path."""
    txt = open(xml_path, encoding='utf-8').read()
    kinds = {}
    for m in re.finditer(r'<string name="Name">M(\d\d)_(\w+)</string>', txt):
        kinds.setdefault(m.group(2), int(m.group(1)))
    R, L = 90.0, 44.0
    dth = 2 * math.atan((L / 2) / R)
    order = [k for k in kinds if k not in ('plaza', 'summit')] + ['plaza', 'summit']
    shots = []
    for kind in order:
        i = kinds[kind]
        th = i * dth
        P = (R * math.cos(th), 6 + 3.5 * i, R * math.sin(th))
        T = (-math.sin(th), 0, math.cos(th))
        cam = (P[0] - T[0] * 46, P[1] + 20, P[2] - T[2] * 46)
        look = (P[0] + T[0] * 4, P[1] + 1, P[2] + T[2] * 4)
        near = [p for p in parts if math.dist((p['cf'][0], p['cf'][1], p['cf'][2]), P) < 90 and p['n'] != 'Strut' and not p['n'].startswith('Islet') and p['n'] not in ('Cloud', 'CoreSection', 'CoreRib', 'CoreWindow', 'CoreBand')]
        path = f'{out}/_m_{kind}.png'
        render(near, cam, look, 62, (800, 450), path, maxd=400)
        shots.append((kind, i, path))
    for sheet in range(0, len(shots), 4):
        img = Image.new('RGB', (1600, 900))
        for j, (kind, i, path) in enumerate(shots[sheet:sheet + 4]):
            im = Image.open(path)
            ImageDraw.Draw(im).text((10, 8), f'{kind} (module {i})', fill=(255, 255, 255))
            img.paste(im, ((j % 2) * 800, (j // 2) * 450))
        img.save(f'{out}/modules_{sheet // 4 + 1}.png')

if __name__ == '__main__' and len(sys.argv) > 3 and sys.argv[3] == 'modules':
    module_sheet(parse(sys.argv[1]), sys.argv[1], sys.argv[2])
