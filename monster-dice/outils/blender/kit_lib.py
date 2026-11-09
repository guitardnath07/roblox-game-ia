# Boîte à outils Blender du monde des monstres (Z vers le haut, 1 unité = 1 stud Roblox).
# Construction : Builder (un objet, plusieurs matériaux), lathe (forme tournée), tube, stone, slab, rockmesh.
# Export : une pièce par matériau (une MeshPart Roblox par couleur), UV en projection cubique pour que les
# matériaux Roblox (ardoise, bois, roche...) se répètent à la bonne échelle, manifeste JSON des centres et tailles.
import bpy, bmesh, math, random, json, os
from mathutils import Vector, Matrix, noise

TAU = math.pi * 2
OUT = os.path.expanduser('~/Desktop/jeux roblox ia /monster-dice/outils/blender/sortie/')  # exécuté via exec() : pas de __file__
os.makedirs(OUT, exist_ok=True)

def hex_lin(h):
    h = h.lstrip('#')
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]

PAL = {
    'PierreClaire': '#7A7190', 'Pierre': '#5E5672', 'PierreSombre': '#433C52', 'Joint': '#2B2633',
    'Roche': '#544A60', 'RocheSombre': '#3A3245', 'Mousse': '#5E8A3C', 'MousseSombre': '#46682E',
    'Fonte': '#2A2433', 'PaveChaud': '#B0906A', 'PaveChaud2': '#957654', 'PaveChaud3': '#C4A57C',
    'Os': '#E8DCC0', 'Bois': '#5A3E2C', 'Laiton': '#B8913F', 'EmailViolet': '#5B3F8C',
    'Maconnerie': '#5A5268', 'Ardoise': '#3A3346', 'Planches': '#6A4A34', 'Banniere': '#5E1A2A',
}
GLOW = {'NeonOr': '#FFC23A', 'NeonOrange': '#FF7A2A', 'NeonTurquoise': '#2EE6C8', 'NeonViolet': '#9B5CFF', 'NeonCramoisi': '#FF2E5A'}

def mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    b = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if b is None:
        out = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None) or nt.nodes.new('ShaderNodeOutputMaterial')
        b = nt.nodes.new('ShaderNodeBsdfPrincipled')
        nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    c = hex_lin(GLOW.get(name) or PAL.get(name, '#808080'))
    b.inputs['Base Color'].default_value = (*c, 1)
    if name in GLOW:
        b.inputs['Emission Color'].default_value = (*c, 1)
        b.inputs['Emission Strength'].default_value = 2.5
    m.diffuse_color = (*c, 1)
    return m

class Builder:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def m(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def merge(self, tmp, mi, matrix=None):
        if matrix is not None:
            bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
        for f in tmp.faces:
            f.material_index = mi
        me = bpy.data.meshes.new('_tmp')
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def finish(self, coll, loc=(0, 0, 0)):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        old = bpy.data.objects.get(self.name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for n in self.mats:
            me.materials.append(mat(n))
        o = bpy.data.objects.new(self.name, me)
        coll.objects.link(o)
        o.location = loc
        return o

def lathe(b, profile, segs, mi, at=Matrix(), rot=0.0, rfun=None, caps=True):
    t = bmesh.new()
    rings = []
    for k, (r, z) in enumerate(profile):
        rings.append([t.verts.new(((r * (rfun(i, k) if rfun else 1)) * math.cos(rot + TAU * i / segs), (r * (rfun(i, k) if rfun else 1)) * math.sin(rot + TAU * i / segs), z)) for i in range(segs)])
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            t.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    if caps and profile[0][0] > 0:
        t.faces.new(list(reversed(rings[0])))
    if caps and profile[-1][0] > 0:
        t.faces.new(rings[-1])
    bmesh.ops.remove_doubles(t, verts=t.verts, dist=1e-5)
    b.merge(t, mi, at)

def tube(b, pts, radius, mi, sides=6, caps=True):
    pts = [Vector(p) for p in pts]
    t = bmesh.new()
    rings, prev, n = [], None, len(pts)
    for k, p in enumerate(pts):
        d = (pts[min(k + 1, n - 1)] - pts[max(k - 1, 0)]).normalized()
        if prev is None:
            up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            nn = d.cross(up).normalized()
        else:
            nn = (prev - d * prev.dot(d)).normalized()
        bb = d.cross(nn)
        prev = nn
        r = radius(k / (n - 1)) if callable(radius) else radius
        rings.append([t.verts.new(p + (nn * math.cos(TAU * i / sides) + bb * math.sin(TAU * i / sides)) * r) for i in range(sides)])
    for k in range(n - 1):
        for i in range(sides):
            j = (i + 1) % sides
            t.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    if caps:
        t.faces.new(list(reversed(rings[0])))
        t.faces.new(rings[-1])
    b.merge(t, mi)

def slab(b, poly, top, h, ch, mi, jitter=0.0, seed=0.0):
    t = bmesh.new()
    n = len(poly)
    cx, cy = sum(p[0] for p in poly) / n, sum(p[1] for p in poly) / n
    inner = []
    for x, y in poly:
        dx, dy = x - cx, y - cy
        d = math.hypot(dx, dy) or 1
        k = max(0.0, d - ch) / d
        inner.append((cx + dx * k, cy + dy * k))
    jz = (lambda x, y: noise.noise(Vector((x * 0.7 + seed, y * 0.7, seed))) * jitter) if jitter else (lambda x, y: 0.0)
    tv = [t.verts.new((x, y, top + jz(x, y))) for x, y in inner]
    rv = [t.verts.new((x, y, top - ch * 0.7)) for x, y in poly]
    bv = [t.verts.new((x, y, top - h)) for x, y in poly]
    t.faces.new(tv)
    for i in range(n):
        j = (i + 1) % n
        if ch > 0:
            t.faces.new((rv[i], rv[j], tv[j], tv[i]))
            t.faces.new((bv[i], bv[j], rv[j], rv[i]))
        else:
            t.faces.new((bv[i], bv[j], tv[j], tv[i]))
    b.merge(t, mi)

def blob(cx, cy, r, k=7, j=0.35):
    return [(cx + r * (1 + random.uniform(-j, j)) * math.cos(a), cy + r * (1 + random.uniform(-j, j)) * math.sin(a)) for a in [i / k * TAU for i in range(k)]]

def rockmesh(b, matrix, mi, seed, subdiv=2, squash=0.7, rough=0.35):
    """Volume facetté (rocher, feuillage, baie) : icosphère bruitée, base aplatie."""
    t = bmesh.new()
    bmesh.ops.create_icosphere(t, subdivisions=subdiv, radius=1.0)
    off = Vector((seed * 1.7, seed * 0.3, seed * 2.1))
    for v in t.verts:
        v.co *= 1 + rough * noise.noise(v.co * 1.4 + off)
        v.co.z *= squash
        if v.co.z < -0.3:
            v.co.z = -0.3 + (v.co.z + 0.3) * 0.25
    b.merge(t, mi, matrix)

def collection(name, parent=None):
    c = bpy.data.collections.get(name)
    if c:
        for o in list(c.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        c = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(c)
    return c

# ------------------------------------------------------------------------------------------------- export
def _srgb_hex(lin):
    return '#%02X%02X%02X' % tuple(int(round(max(0, min(1, (x * 12.92 if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055))) * 255)) for x in lin[:3])

def piece(obj, mname, uv_scale=(1, 1, 1), tile=8.0):
    """Copie des faces de `obj` au matériau `mname`, centrée ; UV en projection cubique (1 UV = `tile` studs,
    à l'échelle `uv_scale` que l'asset aura en jeu). Renvoie (objet, centre Roblox, taille Roblox)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    names = [m.name if m else '' for m in obj.data.materials]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if names[f.material_index] != mname], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    if not bm.faces:
        bm.free()
        return None
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    sx, sy, sz = uv_scale
    uvl = bm.loops.layers.uv.new('UVMap')
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = l.vert.co
            x, y, z = p.x * sx, p.y * sy, p.z * sz
            u, v = ((y, z) if ax == 0 else (x, z) if ax == 1 else (x, y))
            l[uvl].uv = (u / tile, v / tile)
    lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
    hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
    c = (lo + hi) / 2
    for v in bm.verts:
        v.co -= c
    d = hi - lo
    me = bpy.data.meshes.new(obj.name + '__' + mname)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(bpy.data.materials.get(mname))
    o = bpy.data.objects.new(me.name, me)
    return o, [round(c.x, 4), round(c.z, 4), round(-c.y, 4)], [round(d.x, 4), round(d.z, 4), round(d.y, 4)]

def stage(obj, name, exp, manifest, uv_scale=(1, 1, 1)):
    for o in list(exp.objects):
        if o.name.startswith(name + '__'):
            bpy.data.objects.remove(o, do_unlink=True)
    info = []
    for mname in sorted({m.name for m in obj.data.materials if m}):
        r = piece(obj, mname, uv_scale)
        if not r:
            continue
        o, c, s = r
        o.name = f'{name}__{mname}'
        exp.objects.link(o)
        m = bpy.data.materials[mname]
        info.append({'label': mname, 'neon': mname.startswith('Neon'), 'color': GLOW.get(mname) or PAL.get(mname) or _srgb_hex(m.diffuse_color), 'center': c, 'size': s, 'tris': len(o.data.polygons)})
    manifest[name] = info
    return info

def export_fbx(exp, path, prefix=None):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    n = 0
    for o in exp.objects:
        if prefix is None or o.name.split('__')[0] in prefix:
            o.hide_set(False)
            o.select_set(True)
            n += 1
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'}, axis_forward='-Z', axis_up='Y',
                             apply_unit_scale=True, global_scale=1.0, mesh_smooth_type='FACE', path_mode='STRIP',
                             embed_textures=False, bake_anim=False)
    return n
