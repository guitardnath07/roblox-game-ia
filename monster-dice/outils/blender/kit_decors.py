# Décors détaillés (remplacent les boules) : champignons, citrouilles, buissons, herbe, souche.
# Exécuter après kit_lib.py (exec dans le même espace de noms).
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, noise

TAU = math.pi * 2
PAL.update({
    'ChapeauRose': '#D8468E', 'ChapeauViolet': '#8A4FD8', 'ChapeauOrange': '#F07A3A', 'Lamelles': '#F2D6C4',
    'Pied': '#F0E6D6', 'Pois': '#FFF6E0', 'Citrouille': '#F08A24', 'Tige': '#5E7A2E', 'Feuille': '#4E8A34',
    'Feuillage': '#4E9A3A', 'FeuillageSombre': '#3A7A2E', 'Baies': '#C02040', 'Herbe': '#6CBA48', 'HerbeSombre': '#4E9A38',
    'Ecorce': '#5E4030', 'Aubier': '#C9A06A',
})

def _bezier(p0, p1, p2, n):
    return [tuple(Vector(p0) * (1 - t) ** 2 + Vector(p1) * 2 * t * (1 - t) + Vector(p2) * t * t) for t in [k / n for k in range(n + 1)]]

def _mushroom(b, base, h, r, cap_mat, spot_mat, lean):
    bx, by = base
    top = Vector((bx + lean[0] * h, by + lean[1] * h, h))
    stem = _bezier((bx, by, 0), (bx + lean[0] * h * 0.2, by + lean[1] * h * 0.2, h * 0.5), tuple(top), 6)
    tube(b, stem, lambda u: r * (0.34 - 0.08 * u), b.m('Pied'), 7)
    lathe(b, [(r * 0.42, 0.0), (r * 0.5, r * 0.15), (r * 0.36, r * 0.4), (0, r * 0.4)], 9, b.m('Pied'), Matrix.Translation((bx, by, 0)))  # bulbe
    ring_z = 0.78
    rp = Vector(stem[int(len(stem) * ring_z)])
    lathe(b, [(r * 0.3, 0.0), (r * 0.55, -r * 0.18), (r * 0.5, -r * 0.24), (r * 0.28, -r * 0.08)], 12, b.m('Pied'), Matrix.Translation(rp), caps=False)  # anneau
    T = Matrix.Translation(top) @ Matrix.Rotation(lean[0] * 0.8, 4, 'Y') @ Matrix.Rotation(-lean[1] * 0.8, 4, 'X')
    prof = [(0, r * 0.95), (r * 0.45, r * 0.9), (r * 0.82, r * 0.62), (r * 1.02, r * 0.25), (r * 1.0, r * 0.08)]
    lathe(b, prof, 16, b.m(cap_mat), T, rfun=lambda i, k: 1 + 0.04 * math.sin(i * 1.7))
    lathe(b, [(r * 1.0, r * 0.08), (r * 0.7, r * 0.02), (r * 0.25, -r * 0.05), (0, -r * 0.05)], 16, b.m('Lamelles'), T)
    for k in range(18):  # lamelles
        a = k / 18 * TAU
        p0 = T @ Vector((math.cos(a) * r * 0.28, math.sin(a) * r * 0.28, -r * 0.03))
        p1 = T @ Vector((math.cos(a) * r * 0.95, math.sin(a) * r * 0.95, r * 0.07))
        tube(b, [tuple(p0), tuple(p1)], r * 0.025, b.m('Lamelles'), 3)
    for k in range(7):  # pois
        a = random.uniform(0, TAU)
        e = random.uniform(0.25, 0.75)
        rr = r * (0.35 + 0.6 * e)
        zz = r * (0.95 - 0.7 * e ** 1.6)
        p = T @ Vector((math.cos(a) * rr, math.sin(a) * rr, zz + r * 0.03))
        s = r * random.uniform(0.09, 0.15)
        rockmesh(b, Matrix.Translation(p) @ Matrix.Diagonal((s, s, s * 0.45, 1)), b.m(spot_mat), random.random() * 9, 1, 1.0, 0.1)

def kit_mushrooms(coll, name, cap_mat, spot_mat, seed):
    random.seed(seed)
    b = Builder(name)
    slab(b, blob(0, 0, 1.6, 9, 0.3), 0.08, 0.2, 0.06, b.m('Mousse'))
    sizes = [(0, 0, 2.6, 1.0), (0.9, 0.5, 1.6, 0.65), (-0.8, 0.6, 1.2, 0.5), (0.2, -0.9, 0.9, 0.4)]
    for x, y, h, r in sizes:
        lean = (random.uniform(-0.15, 0.15) + x * 0.08, random.uniform(-0.15, 0.15) + y * 0.08)
        _mushroom(b, (x, y), h, r, cap_mat, spot_mat, lean)
    for _ in range(4):
        a = random.uniform(0, TAU)
        rockmesh(b, Matrix.Translation((math.cos(a) * 1.4, math.sin(a) * 1.4, 0.05)) @ Matrix.Diagonal((0.18, 0.15, 0.12, 1)), b.m('Pierre'), random.random() * 9, 1, 0.9, 0.3)
    return b.finish(coll)

def kit_pumpkin(coll, name, lantern, seed):
    random.seed(seed)
    b = Builder(name)
    ribs = 7
    prof = [(0, 0.02), (0.55, 0.06), (0.95, 0.38), (1.05, 0.72), (0.86, 1.1), (0.4, 1.26), (0.12, 1.2), (0, 1.12)]
    lathe(b, prof, 42, b.m('Citrouille'), rfun=lambda i, k: 0.86 + 0.14 * abs(math.cos(i / 42 * ribs * math.pi)))
    # tige torsadée qui se courbe
    stem = _bezier((0, 0, 1.1), (0.05, 0.05, 1.55), (0.35, 0.12, 1.7), 6)
    tube(b, stem, lambda u: 0.16 - 0.07 * u, b.m('Tige'), 6)
    # vrille en spirale
    spiral = [(0.1 + 0.25 * math.cos(t * 5) * (1 - t * 0.6), 0.25 * math.sin(t * 5) * (1 - t * 0.6), 1.2 + t * 0.35) for t in [k / 24 for k in range(25)]]
    tube(b, spiral, 0.025, b.m('Tige'), 4, caps=False)
    # feuilles à nervure
    for a in (0.6, 2.9):
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0))
        base = Vector((0, 0, 1.12)) + d * 0.25
        tip = base + d * 1.0 + Vector((0, 0, -0.25))
        t = bmesh.new()
        pts = [base, base + d * 0.35 + s * 0.35 + Vector((0, 0, 0.12)), tip, base + d * 0.35 - s * 0.35 + Vector((0, 0, 0.12))]
        mid = base + d * 0.45 + Vector((0, 0, 0.05))
        vs = [t.verts.new(p) for p in pts]
        vm = t.verts.new(mid)
        for i in range(4):
            t.faces.new((vm, vs[i], vs[(i + 1) % 4]))
        b.merge(t, b.m('Feuille'))
        tube(b, [tuple(base), tuple(mid), tuple(tip)], 0.02, b.m('Tige'), 3)
    if lantern:
        # visage sculpté lumineux sur la face -Y (tournée vers la place par le générateur)
        G = b.m('NeonOrange')
        def carve(poly, z):
            t = bmesh.new()
            vs = []
            for x, zz in poly:
                y = -math.sqrt(max(0.0, 1.0 - x * x)) * 1.0 - 0.03
                vs.append(t.verts.new((x, y, z + zz)))
            t.faces.new(vs)
            b.merge(t, G)
        carve([(-0.42, 0.0), (-0.18, 0.0), (-0.3, 0.22)], 0.68)
        carve([(0.18, 0.0), (0.42, 0.0), (0.3, 0.22)], 0.68)
        carve([(-0.06, 0.0), (0.06, 0.0), (0.0, 0.12)], 0.52)
        mouth = [(-0.5, 0.0), (-0.3, -0.1), (-0.15, 0.0), (0.0, -0.12), (0.15, 0.0), (0.3, -0.1), (0.5, 0.0), (0.3, -0.18), (0.0, -0.24), (-0.3, -0.18)]
        carve(mouth, 0.38)
    return b.finish(coll)

def kit_bush(coll, name, seed):
    random.seed(seed)
    b = Builder(name)
    for k in range(4):  # branches
        a = k / 4 * TAU
        tube(b, [(0, 0, 0), (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.6), (math.cos(a) * 0.7, math.sin(a) * 0.7, 1.0)], lambda u: 0.12 * (1 - 0.6 * u), b.m('Ecorce'), 5)
    blobs = [(0, 0, 1.4, 1.1)] + [(math.cos(a) * 0.9, math.sin(a) * 0.9, 0.95 + random.uniform(-0.1, 0.25), random.uniform(0.65, 0.85)) for a in [k / 6 * TAU + random.uniform(-0.3, 0.3) for k in range(6)]]
    for i, (x, y, z, s) in enumerate(blobs):
        rockmesh(b, Matrix.Translation((x, y, z)) @ Matrix.Diagonal((s, s, s * 0.85, 1)), b.m('Feuillage' if i % 2 == 0 else 'FeuillageSombre'), i * 3.7 + seed, 1, 1.0, 0.32)
        for _ in range(2):  # baies
            a = random.uniform(0, TAU)
            el = random.uniform(-0.2, 0.6)
            p = Vector((x, y, z)) + Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el))) * s * 0.95
            rockmesh(b, Matrix.Translation(p) @ Matrix.Diagonal((0.09, 0.09, 0.09, 1)), b.m('Baies'), random.random() * 9, 1, 1.0, 0.05)
    return b.finish(coll)

def kit_grass(coll, name, seed):
    random.seed(seed)
    b = Builder(name)
    for k in range(16):
        a = random.uniform(0, TAU)
        d = Vector((math.cos(a), math.sin(a), 0))
        r0 = random.uniform(0, 0.35)
        h = random.uniform(0.7, 1.6)
        p0 = d * r0
        bend = d * random.uniform(0.25, 0.6)
        tube(b, _bezier(tuple(p0), tuple(p0 + bend * 0.2 + Vector((0, 0, h * 0.6))), tuple(p0 + bend + Vector((0, 0, h))), 5), lambda u: 0.06 * (1 - u) + 0.005, b.m('Herbe' if k % 3 else 'HerbeSombre'), 3)
    return b.finish(coll)

def kit_stump(coll, name, seed):
    random.seed(seed)
    b = Builder(name)
    lathe(b, [(1.25, 0), (1.05, 0.3), (0.95, 1.4), (0.98, 1.5)], 18, b.m('Ecorce'), rfun=lambda i, k: 1 + 0.07 * math.sin(i * 2.1) + 0.04 * (i % 2))
    lathe(b, [(0.98, 1.5), (0.88, 1.56), (0, 1.56)], 18, b.m('Aubier'), rfun=lambda i, k: 1 + 0.07 * math.sin(i * 2.1))
    for rr in (0.25, 0.5, 0.72):  # cernes
        lathe(b, [(rr - 0.02, 1.565), (rr + 0.02, 1.565), (rr + 0.02, 1.55), (rr - 0.02, 1.55)], 18, b.m('Ecorce'), caps=False)
    for k in range(5):  # racines
        a = k / 5 * TAU + random.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(b, _bezier(tuple(d * 0.8 + Vector((0, 0, 0.5))), tuple(d * 1.5 + Vector((0, 0, 0.2))), tuple(d * 2.1 + Vector((0, 0, -0.1))), 5), lambda u: 0.3 * (1 - 0.75 * u), b.m('Ecorce'), 5)
    for k in range(3):  # champignons-étagères
        a = 1.0 + k * 0.5
        z = 0.5 + k * 0.32
        T = Matrix.Translation((math.cos(a) * 1.0, math.sin(a) * 1.0, z)) @ Matrix.Rotation(a, 4, 'Z')
        lathe(b, [(0, 0.06), (0.4, 0.04), (0.42, -0.02), (0, -0.04)], 10, b.m('ChapeauOrange'), T @ Matrix.Diagonal((1, 1.5, 1, 1)))
    slab(b, blob(0, 0, 1.8, 9, 0.3), 0.06, 0.15, 0.05, b.m('Mousse'))
    return b.finish(coll)

def build_decor(coll):
    out = []
    out.append(kit_mushrooms(coll, 'ChampignonsRose', 'ChapeauRose', 'Pois', 51))
    out.append(kit_mushrooms(coll, 'ChampignonsViolet', 'ChapeauViolet', 'Pois', 52))
    out.append(kit_mushrooms(coll, 'ChampignonsLumineux', 'ChapeauViolet', 'NeonTurquoise', 53))
    out.append(kit_pumpkin(coll, 'Citrouille', False, 54))
    out.append(kit_pumpkin(coll, 'CitrouilleLanterne', True, 55))
    out.append(kit_bush(coll, 'Buisson', 56))
    out.append(kit_grass(coll, 'Herbe', 57))
    out.append(kit_stump(coll, 'Souche', 58))
    return out
