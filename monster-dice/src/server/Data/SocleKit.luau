--!strict
-- Pièces du socle des parcelles, modélisé dans Blender (outils/blender/kit_socle.py, collection Socle).
-- Les meshes viennent de ~/Desktop/jeux roblox ia /Blender/Socle.fbx, importé une fois dans Studio puis rangé dans ServerStorage.Socle
-- (une MeshPart par pièce, nommée « Socle__Pièce »). Centre (studs, par rapport au point de pose au sol), taille, couleur.
-- Généré depuis outils/blender/sortie/socle.json ; ne pas éditer les nombres à la main.

export type Piece = { label: string, center: Vector3, size: Vector3, color: Color3 }

return table.freeze({
	{ label = "SocleBrin", center = Vector3.new(-0.0004, 2.6319, 0.0125), size = Vector3.new(4.9499, 0.5971, 4.9546), color = Color3.fromHex("#8FD63E") },
	{ label = "SocleHerbe", center = Vector3.new(0.0, 2.0, -0.0), size = Vector3.new(5.0, 1.3333, 5.0), color = Color3.fromHex("#7CC832") },
	{ label = "SocleHerbeClaire", center = Vector3.new(0.0, 2.3333, -0.0), size = Vector3.new(5.0, 1.3333, 5.0), color = Color3.fromHex("#9BDB45") },
	{ label = "SocleHerbeSombre", center = Vector3.new(0.0, 1.5, -0.0), size = Vector3.new(5.0, 1.6667, 5.0), color = Color3.fromHex("#4F9A2A") },
	{ label = "SoclePierreBeige", center = Vector3.new(0.0, 0.8333, -0.0), size = Vector3.new(5.6667, 1.6667, 5.6667), color = Color3.fromHex("#A8957A") },
	{ label = "SoclePierreBrune", center = Vector3.new(0.1667, 0.8333, 0.3333), size = Vector3.new(5.3333, 1.6667, 5.0), color = Color3.fromHex("#7A6656") },
	{ label = "SoclePierreClaire", center = Vector3.new(0.1667, 0.8333, -0.0), size = Vector3.new(5.3333, 1.6667, 5.6667), color = Color3.fromHex("#C2BBAC") },
	{ label = "SoclePierreGrise", center = Vector3.new(0.0, 0.8333, -0.0), size = Vector3.new(5.6667, 1.6667, 5.6667), color = Color3.fromHex("#9C9A94") },
	{ label = "SoclePierreSombre", center = Vector3.new(0.3333, 0.6667, 0.1667), size = Vector3.new(4.3333, 1.3333, 4.6667), color = Color3.fromHex("#5E5650") },
} :: { Piece })
