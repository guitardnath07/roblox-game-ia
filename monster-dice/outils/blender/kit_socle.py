# Socle des parcelles, d'après la photo de référence : petit diorama voxel aux angles arrondis.
# Base de blocs de pierre (gris, beige, brun) en vrac dont certains dépassent, herbe en cubes bosselée qui coule
# sur la pierre par endroits, nombreux brins fins. Grille de voxels : seules les faces visibles sont créées.
# Exécuter après kit_lib.py (exec dans le même espace de noms). 1 unité = 1 stud, Z vers le haut.
# Sortie : ~/Desktop/jeux roblox ia /Blender/Socle.fbx (une pièce par matériau) + sortie/socle.json (centres et tailles côté Roblox).
import bpy, bmesh, math, random, json
from mathutils import Vector, Matrix

PAL.update({
    'SoclePierreGrise': '#9C9A94', 'SoclePierreClaire': '#C2BBAC', 'SoclePierreBeige': '#A8957A',
    'SoclePierreBrune': '#7A6656', 'SoclePierreSombre': '#5E5650',
    'SocleHerbe': '#7CC832', 'SocleHerbeClaire': '#9BDB45', 'SocleHerbeSombre': '#4F9A2A', 'SocleBrin': '#8FD63E',
})
STONES = ['SoclePierreGrise', 'SoclePierreClaire', 'SoclePierreBeige', 'SoclePierreBrune', 'SoclePierreSombre']
STONE_W = [5, 4, 3, 2, 1]

V = 1 / 3      # taille d'un voxel (studs)
N = 15         # voxels de côté : socle de 5 studs
STONE_H = 5    # couches de pierre
GRASS_H = 2    # couches d'herbe

def footprint(i, j, pad=0):
    # carré aux angles arrondis (rayon 3 voxels)
    r = 3
    a, b = min(i + pad, N - 1 - i + pad), min(j + pad, N - 1 - j + pad)
    if a < 0 or b < 0:
        return False
    if a < r and b < r:
        return (r - a - 0.5) ** 2 + (r - b - 0.5) ** 2 <= r * r
    return True

def socle(coll, name='Socle', seed=11):
    random.seed(seed)
    vox = {}
    # pierre : blocs de 2 × 2 × 2 voxels, une couleur par bloc
    block_col = {}
    def stone_at(i, j, k):
        key = (i // 2 + (k // 2) % 2, j // 2, k // 2)  # rangées décalées
        if key not in block_col:
            block_col[key] = random.choices(STONES, STONE_W)[0]
        return block_col[key]
    for i in range(N):
        for j in range(N):
            if not footprint(i, j):
                continue
            for k in range(STONE_H):
                vox[(i, j, k)] = stone_at(i, j, k)
    # blocs qui dépassent : certains blocs de 2 × 2 avancent d'un voxel vers l'extérieur
    out_block = {}
    for i in range(-1, N + 1):
        for j in range(-1, N + 1):
            if footprint(i, j) or not footprint(i, j, 1):
                continue
            for k in range(0, STONE_H - 1, 2):
                key = (i // 2, j // 2, k // 2)
                if key not in out_block:
                    out_block[key] = random.random() < 0.3
                if out_block[key]:
                    for dk in (0, 1):
                        vox[(i, j, k + dk)] = stone_at(i, j, k)
    # herbe : deux couches au ras de la pierre, couleurs mouchetées
    def grass_col():
        return random.choices(('SocleHerbe', 'SocleHerbeClaire', 'SocleHerbeSombre'), (6, 3, 1))[0]
    top = {}
    for i in range(N):
        for j in range(N):
            if not footprint(i, j):
                continue
            h = STONE_H + GRASS_H
            for k in range(STONE_H, h):
                vox[(i, j, k)] = grass_col()
            top[(i, j)] = h
    # coulures : par paires de voxels du pourtour, le haut de la pierre devient de l'herbe (1 à 3 voxels)
    drip = {}
    for i in range(N):
        for j in range(N):
            if footprint(i, j) and not all(footprint(i + di, j + dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                key = (i // 2, j // 2)
                if key not in drip:
                    drip[key] = random.randint(1, 3) if random.random() < 0.45 else 0
                for k in range(STONE_H - 1, STONE_H - 1 - drip[key], -1):
                    vox[(i, j, k)] = 'SocleHerbeSombre' if k < STONE_H - 1 else 'SocleHerbe'
    # bosses d'herbe sur le dessus (taches de 2 × 2)
    for _ in range(5):
        ci, cj = random.randint(2, N - 4), random.randint(2, N - 4)
        for i in (ci, ci + 1):
            for j in (cj, cj + 1):
                if random.random() < 0.85:
                    vox[(i, j, top[(i, j)])] = grass_col()
                    top[(i, j)] += 1
    # maillage : une face par côté de voxel exposé
    b = Builder(name)
    t = bmesh.new()
    DIRS = [((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]), ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
            ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]), ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
            ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]), ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)])]
    off = Vector((-N / 2, -N / 2, 0))
    byMat = {}
    for (i, j, k), mname in vox.items():
        for d, quad in DIRS:
            if (i + d[0], j + d[1], k + d[2]) in vox:
                continue
            byMat.setdefault(mname, []).append([(Vector((i + q[0], j + q[1], k + q[2])) + off) * V for q in quad])
    for mname, quads in byMat.items():
        tm = bmesh.new()
        for quad in quads:
            tm.faces.new([tm.verts.new(p) for p in quad])
        b.merge(tm, b.m(mname))
    t.free()
    # brins : fines lames dressées, en touffes, surtout près du bord
    def blade(base, h, lean):
        tb = bmesh.new()
        w = 0.035
        a = [tb.verts.new((base.x + dx, base.y + dy, base.z)) for dx, dy in ((-w, -w), (w, -w), (w, w), (-w, w))]
        tip = tb.verts.new((base.x + lean[0] * h, base.y + lean[1] * h, base.z + h))
        for q in range(4):
            tb.faces.new((a[q], a[(q + 1) % 4], tip))
        b.merge(tb, b.m(random.choice(('SocleBrin', 'SocleBrin', 'SocleHerbeClaire'))))
    cells = list(top.items())
    for _ in range(40):
        (i, j), h = random.choice(cells)
        if not (i in (0, 1, N - 2, N - 1) or j in (0, 1, N - 2, N - 1)) and random.random() < 0.6:
            continue
        c = (Vector((i + 0.5, j + 0.5, h)) + off) * V
        for _ in range(random.randint(3, 6)):
            o = Vector((random.uniform(-0.12, 0.12), random.uniform(-0.12, 0.12), 0))
            blade(c + o, random.uniform(0.25, 0.6), (random.uniform(-0.25, 0.25), random.uniform(-0.25, 0.25)))
    return b.finish(coll)

coll = collection('Socle')
obj = socle(coll)
exp = collection('SocleExport')
manifest = {}
stage(obj, 'Socle', exp, manifest)
for o in exp.objects:
    o.hide_set(True)
n = export_fbx(exp, os.path.expanduser('~/Desktop/jeux roblox ia /Blender/Socle.fbx'))
with open(OUT + 'socle.json', 'w') as f:
    json.dump(manifest, f, indent=1)
result = {'pieces': n, 'tris': sum(p['tris'] for p in manifest['Socle']), 'labels': [p['label'] for p in manifest['Socle']]}
