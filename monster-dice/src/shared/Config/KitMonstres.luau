--!strict
-- Kit 3D du monde des monstres, modélisé dans Blender (~/Desktop/jeux roblox ia /Blender/assets monstre blender.blend, collection
-- KitMonstres). Rendu de la map des héros : chaque asset est découpé en une pièce par matériau, en couleur unie
-- (SmoothPlastic) ou en néon pour les vraies sources de lumière — aucune texture, donc rien de pixelisé.
-- Les meshes viennent de ~/Desktop/jeux roblox ia /Blender/KitMonstresDetail.fbx (UV en projection cubique : 1 tuile = 8 studs), importé une fois dans Studio puis rangé dans
-- ServerStorage.KitMonstres (une MeshPart par pièce, nommée « Asset__Pièce »). Le générateur de l'île les clone ;
-- ce fichier donne pour chaque pièce sa position dans l'asset (centre, en studs, par rapport au point de pose),
-- sa taille et sa couleur. Partie « assets » générée par outils/blender (kit_lib.py) ; ne pas éditer les nombres à la main.

export type Part = { label: string, center: Vector3, size: Vector3, color: Color3, neon: boolean }

local KitMonstres = {}

-- Néons adoucis (moins éblouissants que les couleurs de Blender) : seules les vraies sources de lumière en ont.
KitMonstres.neon = table.freeze({
	NeonOr = Color3.fromHex("#E0A848"),
	NeonOrange = Color3.fromHex("#E0803C"),
	NeonTurquoise = Color3.fromHex("#46BFAE"),
	NeonViolet = Color3.fromHex("#8A66D6"),
	NeonCramoisi = Color3.fromHex("#D24660"),
})

KitMonstres.assets = table.freeze({
	Allee = {
		{ label = "Joint", center = Vector3.new(0, -0.36, -0), size = Vector3.new(10, 0.6, 12), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "PaveChaud", center = Vector3.new(-0.0092, -0.243, -0.0219), size = Vector3.new(9.943, 0.5649, 11.936), color = Color3.fromHex("#B0906A"), neon = false },
		{ label = "PaveChaud2", center = Vector3.new(0.0042, -0.2447, 0.0171), size = Vector3.new(9.9311, 0.5705, 11.8957), color = Color3.fromHex("#957654"), neon = false },
		{ label = "PaveChaud3", center = Vector3.new(-0.0087, -0.2406, -0.7406), size = Vector3.new(9.8613, 0.5708, 10.4921), color = Color3.fromHex("#C4A57C"), neon = false },
		{ label = "Pierre", center = Vector3.new(0, 0.2308, -0.739), size = Vector3.new(12.2, 1.0616, 10.442), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 0.2253, -0), size = Vector3.new(12.2, 1.0506, 11.92), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 0.2129, 1.6359), size = Vector3.new(12.2, 1.0258, 8.6482), color = Color3.fromHex("#433C52"), neon = false },
	},
	AnneauPassage = {
		{ label = "Joint", center = Vector3.new(79.9727, -0.36, -0), size = Vector3.new(10.2546, 0.6, 29.5549), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "PaveChaud", center = Vector3.new(79.3769, -0.2407, -2.495), size = Vector3.new(8.8546, 0.5769, 23.2768), color = Color3.fromHex("#B0906A"), neon = false },
		{ label = "PaveChaud2", center = Vector3.new(79.5569, -0.2365, -0.1248), size = Vector3.new(8.7032, 0.582, 28.5163), color = Color3.fromHex("#957654"), neon = false },
		{ label = "PaveChaud3", center = Vector3.new(79.4285, -0.2413, -0), size = Vector3.new(8.9577, 0.574, 28.9634), color = Color3.fromHex("#C4A57C"), neon = false },
		{ label = "Pierre", center = Vector3.new(83.8814, 0.1599, 0.5135), size = Vector3.new(1.4172, 0.9199, 22.7999), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(83.6599, 0.2187, 0.7493), size = Vector3.new(1.4611, 1.0374, 25.5889), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(83.4813, 0.1689, -0), size = Vector3.new(1.5011, 0.9379, 29.4756), color = Color3.fromHex("#433C52"), neon = false },
	},
	AnneauPlein = {
		{ label = "Joint", center = Vector3.new(79.9727, -0.36, -0), size = Vector3.new(10.2546, 0.6, 29.5549), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "PaveChaud", center = Vector3.new(79.443, -0.2382, -0), size = Vector3.new(8.8314, 0.5797, 27.359), color = Color3.fromHex("#B0906A"), neon = false },
		{ label = "PaveChaud2", center = Vector3.new(79.3998, -0.2441, 0.0564), size = Vector3.new(8.9003, 0.5642, 26.8155), color = Color3.fromHex("#957654"), neon = false },
		{ label = "PaveChaud3", center = Vector3.new(79.5216, -0.2437, -0), size = Vector3.new(8.6715, 0.5701, 28.9441), color = Color3.fromHex("#C4A57C"), neon = false },
		{ label = "Pierre", center = Vector3.new(83.8967, 0.2105, 0.7016), size = Vector3.new(2.3319, 1.0209, 28.0725), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(84.0652, 0.203, 0.5222), size = Vector3.new(2.0685, 1.006, 24.7335), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(83.9152, 0.2165, -4.7037), size = Vector3.new(2.369, 1.033, 20.0683), color = Color3.fromHex("#433C52"), neon = false },
	},
	ArbreMort = {
		{ label = "Bois", center = Vector3.new(2.9697, 5.8351, 1.1544), size = Vector3.new(9.4939, 12.2282, 5.8633), color = Color3.fromHex("#5A3E2C"), neon = false },
	},
	Arche = {
		{ label = "Laiton", center = Vector3.new(0, 12.1737, 0.593), size = Vector3.new(12.24, 5.5681, 1.3939), color = Color3.fromHex("#B8913F"), neon = false },
		{ label = "NeonCramoisi", center = Vector3.new(0, 15.422, 0.854), size = Vector3.new(0.5268, 0.22, 0.1871), color = KitMonstres.neon.NeonCramoisi, neon = true },
		{ label = "Os", center = Vector3.new(0, 15.356, 1.25), size = Vector3.new(0.8567, 1.012, 1.0089), color = Color3.fromHex("#E8DCC0"), neon = false },
		{ label = "Pierre", center = Vector3.new(0.0145, 8.3726, -0), size = Vector3.new(14.6522, 15.1452, 2.6), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 8.3726, -0), size = Vector3.new(15.1, 15.1452, 3.1), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 6.35, -0), size = Vector3.new(15.4, 12.7, 3.4), color = Color3.fromHex("#433C52"), neon = false },
	},
	Avenue = {
		{ label = "Joint", center = Vector3.new(0, -0.36, -0), size = Vector3.new(16, 0.6, 12), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "PaveChaud", center = Vector3.new(-0.0064, -0.2404, 0.2337), size = Vector3.new(15.9635, 0.5673, 11.4552), color = Color3.fromHex("#B0906A"), neon = false },
		{ label = "PaveChaud2", center = Vector3.new(-0.0306, -0.2411, 0.2339), size = Vector3.new(15.8379, 0.5723, 11.4239), color = Color3.fromHex("#957654"), neon = false },
		{ label = "PaveChaud3", center = Vector3.new(0.0103, -0.2434, 0.2802), size = Vector3.new(15.8733, 0.573, 11.4122), color = Color3.fromHex("#C4A57C"), neon = false },
		{ label = "Pierre", center = Vector3.new(0, 0.2194, 0.6449), size = Vector3.new(18.2, 1.0389, 10.6301), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 0.2235, -0.5694), size = Vector3.new(18.2, 1.0469, 10.7813), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 0.2287, -0.7701), size = Vector3.new(18.2, 1.0575, 8.6981), color = Color3.fromHex("#433C52"), neon = false },
	},
	Brasero = {
		{ label = "Fonte", center = Vector3.new(0, 2.5189, -0), size = Vector3.new(2.94, 3.8222, 2.84), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "NeonOrange", center = Vector3.new(0, 4.8921, -0), size = Vector3.new(2.3, 1.9441, 2.3), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "PierreSombre", center = Vector3.new(0, 0.25, -0), size = Vector3.new(2.2, 0.5, 2.2), color = Color3.fromHex("#433C52"), neon = false },
	},
	Buisson = {
		{ label = "Baies", center = Vector3.new(-0.0702, 1.2724, -0.0424), size = Vector3.new(2.9869, 1.0443, 1.9146), color = Color3.fromHex("#C02040"), neon = false },
		{ label = "Ecorce", center = Vector3.new(0, 0.482, -0), size = Vector3.new(1.473, 1.0907, 1.473), color = Color3.fromHex("#5E4030"), neon = false },
		{ label = "Feuillage", center = Vector3.new(-0.1632, 1.4634, -0.0998), size = Vector3.new(2.9779, 1.731, 2.5987), color = Color3.fromHex("#4E9A3A"), neon = false },
		{ label = "FeuillageSombre", center = Vector3.new(0.1706, 1.1864, 0.0478), size = Vector3.new(2.6221, 1.1977, 3.034), color = Color3.fromHex("#3A7A2E"), neon = false },
	},
	CageSuspendue = {
		{ label = "Fonte", center = Vector3.new(0, -4.8966, -0), size = Vector3.new(3.5439, 9.8069, 3.5), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "NeonCramoisi", center = Vector3.new(0.0672, -8.071, -0), size = Vector3.new(0.8965, 2.358, 0.88), color = KitMonstres.neon.NeonCramoisi, neon = true },
		{ label = "Os", center = Vector3.new(0.3, -7.036, 0.3), size = Vector3.new(0.701, 0.828, 0.8255), color = Color3.fromHex("#E8DCC0"), neon = false },
	},
	Cathedrale = {
		{ label = "Ardoise", center = Vector3.new(0, 31.5, -12.6836), size = Vector3.new(25.4607, 41.6, 54.8279), color = Color3.fromHex("#3A3346"), neon = false },
		{ label = "Fonte", center = Vector3.new(0, 15, -10.5288), size = Vector3.new(22.56, 26.25, 49.6175), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "Laiton", center = Vector3.new(0, 34.704, -9.498), size = Vector3.new(24.6, 32.592, 47.596), color = Color3.fromHex("#B8913F"), neon = false },
		{ label = "Maconnerie", center = Vector3.new(0, 15.4, -14.1525), size = Vector3.new(24, 30.8, 56.3249), color = Color3.fromHex("#5A5268"), neon = false },
		{ label = "NeonCramoisi", center = Vector3.new(0, 6.861, 14.102), size = Vector3.new(16.2634, 1.67, 0.0936), color = KitMonstres.neon.NeonCramoisi, neon = true },
		{ label = "NeonOr", center = Vector3.new(0, 28.5, -10.425), size = Vector3.new(24.6, 52, 49.45), color = KitMonstres.neon.NeonOr, neon = true },
		{ label = "NeonOrange", center = Vector3.new(0, 18.2, 14.06), size = Vector3.new(6.27, 6.27, 0), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "NeonViolet", center = Vector3.new(0, 11.9175, -9.37), size = Vector3.new(22.36, 18.835, 46.86), color = KitMonstres.neon.NeonViolet, neon = true },
		{ label = "Os", center = Vector3.new(0, 6.828, 14.3), size = Vector3.new(16.4284, 2.066, 0.5045), color = Color3.fromHex("#E8DCC0"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 15.35, 12), size = Vector3.new(25.4, 30.7, 13.4), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 17.3, -10), size = Vector3.new(25.8, 34.6, 51), color = Color3.fromHex("#433C52"), neon = false },
		{ label = "Planches", center = Vector3.new(0, 13.535, 14.145), size = Vector3.new(20.3, 25.07, 0.29), color = Color3.fromHex("#6A4A34"), neon = false },
	},
	ChampignonsLumineux = {
		{ label = "ChapeauViolet", center = Vector3.new(0.0818, 2.2278, 0.0998), size = Vector3.new(2.9364, 2.6332, 2.5702), color = Color3.fromHex("#8A4FD8"), neon = false },
		{ label = "Lamelles", center = Vector3.new(0.0909, 1.8332, 0.0993), size = Vector3.new(2.8934, 1.9188, 2.516), color = Color3.fromHex("#F2D6C4"), neon = false },
		{ label = "Mousse", center = Vector3.new(-0.0571, -0.02, -0.1661), size = Vector3.new(3.5391, 0.2, 2.8581), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "NeonTurquoise", center = Vector3.new(0.0174, 2.3673, 0.0967), size = Vector3.new(2.5161, 2.4725, 2.1102), color = KitMonstres.neon.NeonTurquoise, neon = true },
		{ label = "Pied", center = Vector3.new(0.0662, 1.3138, 0.1491), size = Vector3.new(2.3645, 2.6727, 2.026), color = Color3.fromHex("#F0E6D6"), neon = false },
		{ label = "Pierre", center = Vector3.new(0.821, 0.0793, 0.6725), size = Vector3.new(1.4865, 0.17, 1.7084), color = Color3.fromHex("#5E5672"), neon = false },
	},
	ChampignonsRose = {
		{ label = "ChapeauRose", center = Vector3.new(0.1853, 2.2205, -0.0245), size = Vector3.new(3.4079, 2.6627, 2.6768), color = Color3.fromHex("#D8468E"), neon = false },
		{ label = "Lamelles", center = Vector3.new(0.1891, 1.8389, -0.02), size = Vector3.new(3.3407, 1.942, 2.6202), color = Color3.fromHex("#F2D6C4"), neon = false },
		{ label = "Mousse", center = Vector3.new(-0.172, -0.02, -0.0702), size = Vector3.new(3.5071, 0.2, 3.11), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "Pied", center = Vector3.new(0.1397, 1.3165, 0.0327), size = Vector3.new(2.6995, 2.6852, 2.1602), color = Color3.fromHex("#F0E6D6"), neon = false },
		{ label = "Pierre", center = Vector3.new(0.0122, 0.0805, -0.402), size = Vector3.new(3.1079, 0.1729, 1.6637), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "Pois", center = Vector3.new(0.1604, 2.2874, 0.0049), size = Vector3.new(3.1153, 2.3682, 2.0995), color = Color3.fromHex("#FFF6E0"), neon = false },
	},
	ChampignonsViolet = {
		{ label = "ChapeauViolet", center = Vector3.new(0.0454, 2.2066, 0.1077), size = Vector3.new(2.8981, 2.68, 2.8071), color = Color3.fromHex("#8A4FD8"), neon = false },
		{ label = "Lamelles", center = Vector3.new(0.0564, 1.8154, 0.1065), size = Vector3.new(2.8571, 1.9109, 2.7402), color = Color3.fromHex("#F2D6C4"), neon = false },
		{ label = "Mousse", center = Vector3.new(0.0547, -0.02, -0.1871), size = Vector3.new(4.0091, 0.2, 2.6011), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "Pied", center = Vector3.new(0.0485, 1.3121, 0.1555), size = Vector3.new(2.3531, 2.6569, 2.1937), color = Color3.fromHex("#F0E6D6"), neon = false },
		{ label = "Pierre", center = Vector3.new(-0.0878, 0.078, -0.0456), size = Vector3.new(1.669, 0.1715, 2.9817), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "Pois", center = Vector3.new(0.0972, 2.3706, 0.1404), size = Vector3.new(2.3737, 2.451, 2.4976), color = Color3.fromHex("#FFF6E0"), neon = false },
	},
	Chapelle = {
		{ label = "Ardoise", center = Vector3.new(0, 21.45, 0.0917), size = Vector3.new(13.9667, 21.5, 23.7834), color = Color3.fromHex("#3A3346"), neon = false },
		{ label = "Fonte", center = Vector3.new(0, 6.1, -0), size = Vector3.new(12.56, 6.5, 17.25), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "Laiton", center = Vector3.new(0, 23.428, 0.22), size = Vector3.new(13.344, 22.144, 22.58), color = Color3.fromHex("#B8913F"), neon = false },
		{ label = "Maconnerie", center = Vector3.new(0, 10.5, -0), size = Vector3.new(12, 19, 22.02), color = Color3.fromHex("#5A5268"), neon = false },
		{ label = "NeonCramoisi", center = Vector3.new(0, 7.842, 11.1701), size = Vector3.new(11.4873, 5.66, 0.2298), color = KitMonstres.neon.NeonCramoisi, neon = true },
		{ label = "NeonOr", center = Vector3.new(0, 10.285, 3.84), size = Vector3.new(12.36, 13.57, 14.48), color = KitMonstres.neon.NeonOr, neon = true },
		{ label = "NeonViolet", center = Vector3.new(0, 10.285, 1.34), size = Vector3.new(12.36, 13.57, 19.48), color = KitMonstres.neon.NeonViolet, neon = true },
		{ label = "Os", center = Vector3.new(0, 7.8165, 11.3865), size = Vector3.new(11.6673, 6.071, 0.6774), color = Color3.fromHex("#E8DCC0"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 10.25, 1.35), size = Vector3.new(12.5, 20.5, 25.3), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 10.65, 0.25), size = Vector3.new(14.4, 21.3, 23.9), color = Color3.fromHex("#433C52"), neon = false },
		{ label = "Planches", center = Vector3.new(0, 8.94, -0.075), size = Vector3.new(5.46, 15.88, 22.31), color = Color3.fromHex("#6A4A34"), neon = false },
	},
	Citrouille = {
		{ label = "Citrouille", center = Vector3.new(0.0327, 0.64, -0), size = Vector3.new(2.0345, 1.24, 2.0548), color = Color3.fromHex("#F08A24"), neon = false },
		{ label = "Feuille", center = Vector3.new(-0.091, 1.055, -0.2548), size = Vector3.new(2.2454, 0.37, 0.9021), color = Color3.fromHex("#4E8A34"), neon = false },
		{ label = "Tige", center = Vector3.new(-0.0906, 1.3147, -0.28), size = Vector3.new(2.2671, 0.9198, 0.8776), color = Color3.fromHex("#5E7A2E"), neon = false },
	},
	CitrouilleLanterne = {
		{ label = "Citrouille", center = Vector3.new(0.0327, 0.64, -0), size = Vector3.new(2.0345, 1.24, 2.0548), color = Color3.fromHex("#F08A24"), neon = false },
		{ label = "Feuille", center = Vector3.new(-0.091, 1.055, -0.2548), size = Vector3.new(2.2454, 0.37, 0.9021), color = Color3.fromHex("#4E8A34"), neon = false },
		{ label = "NeonOrange", center = Vector3.new(0, 0.52, 0.963), size = Vector3.new(1, 0.76, 0.134), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "Tige", center = Vector3.new(-0.0906, 1.3147, -0.28), size = Vector3.new(2.2671, 0.9198, 0.8776), color = Color3.fromHex("#5E7A2E"), neon = false },
	},
	Cristaux = {
		{ label = "NeonViolet", center = Vector3.new(-0.3554, 1.8171, -0.0286), size = Vector3.new(2.4081, 3.7659, 2.7616), color = KitMonstres.neon.NeonViolet, neon = true },
		{ label = "RocheSombre", center = Vector3.new(0.1453, 0.0916, -0.0472), size = Vector3.new(3.6942, 0.8473, 2.8334), color = Color3.fromHex("#3A3245"), neon = false },
	},
	DalleA = {
		{ label = "Joint", center = Vector3.new(0, -0.36, -0), size = Vector3.new(16, 0.6, 16), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "MousseSombre", center = Vector3.new(0.3335, 0, -1.9805), size = Vector3.new(6.3365, 0.12, 11.8316), color = Color3.fromHex("#46682E"), neon = false },
		{ label = "Pierre", center = Vector3.new(-0.0112, -0.2414, -0.0451), size = Vector3.new(15.9879, 0.5692, 15.9121), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(-0.0699, -0.2379, 0.6139), size = Vector3.new(15.8327, 0.5752, 14.6514), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0.0196, -0.2486, -0.0226), size = Vector3.new(15.9037, 0.557, 15.9184), color = Color3.fromHex("#433C52"), neon = false },
	},
	DalleB = {
		{ label = "Joint", center = Vector3.new(0, -0.36, -0), size = Vector3.new(16, 0.6, 16), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "Mousse", center = Vector3.new(1.1238, 0, 3.0283), size = Vector3.new(2.5422, 0.12, 2.8098), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "MousseSombre", center = Vector3.new(0.0241, 0, -0.5932), size = Vector3.new(8.2752, 0.12, 8.5822), color = Color3.fromHex("#46682E"), neon = false },
		{ label = "Pierre", center = Vector3.new(0.0435, -0.2384, 0.0374), size = Vector3.new(15.9292, 0.5726, 15.9283), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0.0004, -0.2396, -0.0109), size = Vector3.new(15.9271, 0.558, 15.8637), color = Color3.fromHex("#433C52"), neon = false },
		{ label = "RocheSombre", center = Vector3.new(-0.0221, -0.2452, -0.0147), size = Vector3.new(15.8808, 0.5677, 15.7974), color = Color3.fromHex("#3A3245"), neon = false },
	},
	DalleC = {
		{ label = "Joint", center = Vector3.new(0, -0.36, -0), size = Vector3.new(16, 0.6, 16), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "Mousse", center = Vector3.new(6.424, 0, 2.6292), size = Vector3.new(2.0163, 0.12, 2.138), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "MousseSombre", center = Vector3.new(3.8943, 0, -1.0829), size = Vector3.new(3.3795, 0.12, 12.3125), color = Color3.fromHex("#46682E"), neon = false },
		{ label = "Pierre", center = Vector3.new(1.1848, -0.2414, 3.0186), size = Vector3.new(13.5591, 0.5673, 9.967), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(-0.1396, -0.2374, -0.0284), size = Vector3.new(15.7218, 0.5687, 15.9012), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0.0218, -0.2414, -0.0117), size = Vector3.new(15.9152, 0.5709, 15.9901), color = Color3.fromHex("#433C52"), neon = false },
	},
	GrilleTravee = {
		{ label = "Fonte", center = Vector3.new(0, 3.0329, -0), size = Vector3.new(12, 3.9657, 0.2121), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "Pierre", center = Vector3.new(-2.3054, 0.425, -0), size = Vector3.new(7.3292, 0.85, 0.8), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 0.95, -0), size = Vector3.new(12, 0.2, 1.05), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(1.533, 0.425, -0), size = Vector3.new(8.874, 0.85, 0.8), color = Color3.fromHex("#433C52"), neon = false },
	},
	Herbe = {
		{ label = "Herbe", center = Vector3.new(-0.0792, 0.7819, 0.159), size = Vector3.new(1.4087, 1.5935, 1.2158), color = Color3.fromHex("#6CBA48"), neon = false },
		{ label = "HerbeSombre", center = Vector3.new(-0.072, 0.7845, -0.1464), size = Vector3.new(1.3779, 1.5925, 1.0438), color = Color3.fromHex("#4E9A38"), neon = false },
	},
	Lampadaire1Bras = {
		{ label = "Fonte", center = Vector3.new(0, 5.6, -1.3462), size = Vector3.new(1.7554, 9.7, 4.4477), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "NeonOrange", center = Vector3.new(0, 7.45, -2.85), size = Vector3.new(0.7621, 0.76, 0.88), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "Pierre", center = Vector3.new(0, 0.6, -0), size = Vector3.new(1.9, 0.35, 1.9), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 0.22, -0), size = Vector3.new(2.4, 0.45, 2.4), color = Color3.fromHex("#433C52"), neon = false },
	},
	Lampadaire2Bras = {
		{ label = "Fonte", center = Vector3.new(0, 5.0134, -0), size = Vector3.new(6.9471, 8.5268, 1.7554), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "NeonCramoisi", center = Vector3.new(0, 9.32, -0.36), size = Vector3.new(0.4789, 0.2, 0.1701), color = KitMonstres.neon.NeonCramoisi, neon = true },
		{ label = "NeonOrange", center = Vector3.new(2.85, 7.45, -0), size = Vector3.new(0.7621, 0.76, 0.88), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "NeonTurquoise", center = Vector3.new(-2.85, 7.45, -0), size = Vector3.new(0.7621, 0.76, 0.88), color = KitMonstres.neon.NeonTurquoise, neon = true },
		{ label = "Os", center = Vector3.new(-0, 9.26, -0), size = Vector3.new(0.7789, 0.92, 0.9172), color = Color3.fromHex("#E8DCC0"), neon = false },
		{ label = "Pierre", center = Vector3.new(0, 0.6, -0), size = Vector3.new(1.9, 0.35, 1.9), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 0.22, -0), size = Vector3.new(2.4, 0.45, 2.4), color = Color3.fromHex("#433C52"), neon = false },
	},
	Maison = {
		{ label = "Ardoise", center = Vector3.new(0, 14.775, -0), size = Vector3.new(17.8, 10.15, 12.8), color = Color3.fromHex("#3A3346"), neon = false },
		{ label = "Fonte", center = Vector3.new(0, 11.525, 0.72), size = Vector3.new(17.8, 18.55, 13), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "Maconnerie", center = Vector3.new(0, 10.5625, -0), size = Vector3.new(16, 18.725, 11), color = Color3.fromHex("#5A5268"), neon = false },
		{ label = "NeonOr", center = Vector3.new(0, 8.1, -0), size = Vector3.new(16.36, 11, 11.36), color = KitMonstres.neon.NeonOr, neon = true },
		{ label = "NeonOrange", center = Vector3.new(0.4405, 3, 6.31), size = Vector3.new(3.0811, 3.6, 1.26), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "PierreClaire", center = Vector3.new(4.9, 20.075, -1.925), size = Vector3.new(2, 0.4, 2), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 9.2625, -0), size = Vector3.new(16.6, 18.525, 11.6), color = Color3.fromHex("#433C52"), neon = false },
		{ label = "Planches", center = Vector3.new(0, 5.45, 0.015), size = Vector3.new(16.3, 9.4, 11.53), color = Color3.fromHex("#6A4A34"), neon = false },
	},
	Manoir = {
		{ label = "Ardoise", center = Vector3.new(-1.7, 18.25, 1.65), size = Vector3.new(35, 24.9, 17.7), color = Color3.fromHex("#3A3346"), neon = false },
		{ label = "Fonte", center = Vector3.new(-1.3789, 17.2, 1.275), size = Vector3.new(31.8672, 30.6, 16.11), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "Joint", center = Vector3.new(-1.3295, 10.45, 1.275), size = Vector3.new(31.6411, 15.9, 15.91), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "Maconnerie", center = Vector3.new(-1.6, 11.3, 1.5), size = Vector3.new(34.2, 22.6, 16), color = Color3.fromHex("#5A5268"), neon = false },
		{ label = "NeonOr", center = Vector3.new(2.8955, 10.5, 1.275), size = Vector3.new(23.1911, 15.8, 15.91), color = KitMonstres.neon.NeonOr, neon = true },
		{ label = "NeonOrange", center = Vector3.new(0, 2.83, 7.4), size = Vector3.new(3.9621, 0.76, 0.88), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "PierreClaire", center = Vector3.new(0, 12.75, 1.725), size = Vector3.new(20.6, 25.5, 17.05), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(-4.25, 13.25, -0), size = Vector3.new(29.5, 26.5, 14), color = Color3.fromHex("#433C52"), neon = false },
		{ label = "Planches", center = Vector3.new(0, 6.5, 6.55), size = Vector3.new(19, 10.6, 0.1), color = Color3.fromHex("#6A4A34"), neon = false },
	},
	Parcelle = {
		{ label = "EmailViolet", center = Vector3.new(0, 0.05, -0), size = Vector3.new(7.6, 0.3, 7.6), color = Color3.fromHex("#5B3F8C"), neon = false },
		{ label = "Joint", center = Vector3.new(0, -0.46, -0), size = Vector3.new(54, 0.8, 54), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "Laiton", center = Vector3.new(0, 0.11, -0), size = Vector3.new(48.64, 0.7, 48.64), color = Color3.fromHex("#B8913F"), neon = false },
		{ label = "Mousse", center = Vector3.new(-12.5091, 0, 19.4712), size = Vector3.new(1.7727, 0.12, 1.4368), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "MousseSombre", center = Vector3.new(1.1127, 0, 2.0166), size = Vector3.new(38.2733, 0.12, 40.4119), color = Color3.fromHex("#46682E"), neon = false },
		{ label = "Pierre", center = Vector3.new(-0.0015, -0.2429, 0), size = Vector3.new(54.0155, 0.5742, 54.0161), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(-0.0057, -0.1947, 0.002), size = Vector3.new(54.0049, 0.6693, 54.0061), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(-0.007, -0.0746, -0.0025), size = Vector3.new(47.9958, 0.9093, 48.0139), color = Color3.fromHex("#433C52"), neon = false },
	},
	PilierBougie = {
		{ label = "Laiton", center = Vector3.new(0, 6.1, -0), size = Vector3.new(0.64, 0.8, 0.64), color = Color3.fromHex("#B8913F"), neon = false },
		{ label = "NeonOrange", center = Vector3.new(0, 2.825, -0), size = Vector3.new(0.32, 1.69, 2.04), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "Pierre", center = Vector3.new(0, 2.7375, -0), size = Vector3.new(1.955, 4.475, 1.955), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 4.6, -0), size = Vector3.new(2.244, 0.3, 2.244), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 2.9, -0), size = Vector3.new(2.295, 5.8, 2.295), color = Color3.fromHex("#433C52"), neon = false },
	},
	PilierBoule = {
		{ label = "Fonte", center = Vector3.new(0, 6.1, -0), size = Vector3.new(0.7228, 0.76, 0.76), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "NeonViolet", center = Vector3.new(0, 2.825, -0), size = Vector3.new(0.32, 1.69, 2.04), color = KitMonstres.neon.NeonViolet, neon = true },
		{ label = "Pierre", center = Vector3.new(0, 2.7375, -0), size = Vector3.new(1.955, 4.475, 1.955), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 4.6, -0), size = Vector3.new(2.244, 0.3, 2.244), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 2.9, -0), size = Vector3.new(2.295, 5.8, 2.295), color = Color3.fromHex("#433C52"), neon = false },
	},
	PilierCrane = {
		{ label = "NeonCramoisi", center = Vector3.new(0, 6.218, -0.324), size = Vector3.new(0.431, 0.18, 0.1531), color = KitMonstres.neon.NeonCramoisi, neon = true },
		{ label = "NeonOr", center = Vector3.new(0, 2.825, -0), size = Vector3.new(0.32, 1.69, 2.04), color = KitMonstres.neon.NeonOr, neon = true },
		{ label = "Os", center = Vector3.new(-0, 6.164, -0), size = Vector3.new(0.701, 0.828, 0.8255), color = Color3.fromHex("#E8DCC0"), neon = false },
		{ label = "Pierre", center = Vector3.new(0, 2.7375, -0), size = Vector3.new(1.955, 4.475, 1.955), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 4.6, -0), size = Vector3.new(2.244, 0.3, 2.244), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 2.9, -0), size = Vector3.new(2.295, 5.8, 2.295), color = Color3.fromHex("#433C52"), neon = false },
	},
	Place = {
		{ label = "EmailViolet", center = Vector3.new(0, -0.05, -0), size = Vector3.new(61.4, 0.5, 61.4), color = Color3.fromHex("#5B3F8C"), neon = false },
		{ label = "Joint", center = Vector3.new(0, -0.73, -0), size = Vector3.new(120.8, 1.34, 120.8), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "Laiton", center = Vector3.new(0, 0, -0), size = Vector3.new(93.4, 0.6, 93.4), color = Color3.fromHex("#B8913F"), neon = false },
		{ label = "PaveChaud", center = Vector3.new(0.1495, -0.2371, -0.0894), size = Vector3.new(118.325, 0.5856, 118.455), color = Color3.fromHex("#B0906A"), neon = false },
		{ label = "PaveChaud2", center = Vector3.new(-0.1561, -0.2375, 0.0176), size = Vector3.new(118.323, 0.5842, 118.581), color = Color3.fromHex("#957654"), neon = false },
		{ label = "PaveChaud3", center = Vector3.new(-0.0039, -0.2372, 0.0572), size = Vector3.new(118.624, 0.5854, 118.487), color = Color3.fromHex("#C4A57C"), neon = false },
		{ label = "Pierre", center = Vector3.new(-0.0057, -0.2398, 0.1507), size = Vector3.new(24.5886, 0.5795, 24.2932), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, -0.2125, -0), size = Vector3.new(95.06, 0.625, 95.06), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, -0.11, -0), size = Vector3.new(9, 0.38, 9), color = Color3.fromHex("#433C52"), neon = false },
	},
	PontTravee = {
		{ label = "Fonte", center = Vector3.new(0.0175, 1.8486, -0), size = Vector3.new(8.105, 1.2184, 10.8364), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 0.9, -0), size = Vector3.new(9, 5, 12), color = Color3.fromHex("#433C52"), neon = false },
		{ label = "Planches", center = Vector3.new(-0.0301, -0.1774, 0.0158), size = Vector3.new(8.3399, 0.4211, 11.8884), color = Color3.fromHex("#6A4A34"), neon = false },
	},
	Porterie = {
		{ label = "Ardoise", center = Vector3.new(0, 22.9, -0), size = Vector3.new(26.8, 8.6, 9.5543), color = Color3.fromHex("#3A3346"), neon = false },
		{ label = "Banniere", center = Vector3.new(0, 11.25, 4.25), size = Vector3.new(19.2, 6.5, 0), color = Color3.fromHex("#5E1A2A"), neon = false },
		{ label = "Fonte", center = Vector3.new(0, 9.04, 2.33), size = Vector3.new(19.6, 11.28, 4.1), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "Joint", center = Vector3.new(0, 9.1, 4.05), size = Vector3.new(17.36, 8.2, 0), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "Laiton", center = Vector3.new(0, 28, -0), size = Vector3.new(17.24, 2, 0.24), color = Color3.fromHex("#B8913F"), neon = false },
		{ label = "Maconnerie", center = Vector3.new(0, 9, -0), size = Vector3.new(26.2, 18, 8.9693), color = Color3.fromHex("#5A5268"), neon = false },
		{ label = "NeonCramoisi", center = Vector3.new(0, 11.718, 1.626), size = Vector3.new(0.431, 0.18, 0.1531), color = KitMonstres.neon.NeonCramoisi, neon = true },
		{ label = "NeonOrange", center = Vector3.new(0, 6.03, 2.8), size = Vector3.new(7.1621, 0.76, 0.88), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "Os", center = Vector3.new(-0, 11.664, 1.95), size = Vector3.new(0.701, 0.828, 0.8255), color = Color3.fromHex("#E8DCC0"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 8.3, -0), size = Vector3.new(10.6, 14.6, 4.2), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0.2129, 9.65, -0), size = Vector3.new(26.4742, 19.3, 9.6844), color = Color3.fromHex("#433C52"), neon = false },
	},
	Potence = {
		{ label = "Bois", center = Vector3.new(3.15, 7.25, -0), size = Vector3.new(7.5, 13.5, 1.2), color = Color3.fromHex("#5A3E2C"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 0.25, -0), size = Vector3.new(2.2, 0.5, 2.2), color = Color3.fromHex("#433C52"), neon = false },
	},
	Rempart = {
		{ label = "Mousse", center = Vector3.new(1.7067, 2.3684, -0.6793), size = Vector3.new(7.6954, 4.8368, 2.4425), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "Pierre", center = Vector3.new(0, 2.3684, -0.0003), size = Vector3.new(11.9, 4.7368, 1.9161), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0, 2.447, -0), size = Vector3.new(12, 4.894, 2.3), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(-0.2695, 2.235, -0), size = Vector3.new(9.4574, 1.47, 1.866), color = Color3.fromHex("#433C52"), neon = false },
	},
	Rocher1 = {
		{ label = "Mousse", center = Vector3.new(0.0095, 1.4696, 0.0262), size = Vector3.new(6.3379, 0.9906, 2.9602), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "NeonViolet", center = Vector3.new(0.5211, 1.3514, -1.5728), size = Vector3.new(3.0101, 2.0796, 2.2215), color = KitMonstres.neon.NeonViolet, neon = true },
		{ label = "Roche", center = Vector3.new(0.0036, 0.428, -0.1231), size = Vector3.new(6.2572, 2.8582, 5.1609), color = Color3.fromHex("#544A60"), neon = false },
		{ label = "RocheSombre", center = Vector3.new(0.0511, -0.012, -0.2884), size = Vector3.new(6.828, 0.562, 4.3551), color = Color3.fromHex("#3A3245"), neon = false },
	},
	Rocher2 = {
		{ label = "Mousse", center = Vector3.new(-0.1495, 0.921, -0.0453), size = Vector3.new(3.9677, 0.6099, 3.4619), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "RocheSombre", center = Vector3.new(0.2388, 0.2258, 0.1024), size = Vector3.new(5.3213, 1.8566, 4.0326), color = Color3.fromHex("#3A3245"), neon = false },
	},
	Rocher3 = {
		{ label = "Mousse", center = Vector3.new(0.4177, 1.602, -0.073), size = Vector3.new(8.931, 0.8185, 6.3113), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "NeonTurquoise", center = Vector3.new(0.7363, 1.5014, -1.8897), size = Vector3.new(3.8346, 2.0796, 2.4336), color = KitMonstres.neon.NeonTurquoise, neon = true },
		{ label = "RocheSombre", center = Vector3.new(0.2574, 0.3235, -0.3893), size = Vector3.new(10.1226, 3.1057, 7.2104), color = Color3.fromHex("#3A3245"), neon = false },
	},
	RocherFlottant = {
		{ label = "Mousse", center = Vector3.new(-0.0768, 0.3092, -0.1773), size = Vector3.new(1.7576, 0.1648, 1.5728), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "NeonTurquoise", center = Vector3.new(0.6637, -0.084, -0.5406), size = Vector3.new(0.6023, 0.2008, 0.7217), color = KitMonstres.neon.NeonTurquoise, neon = true },
		{ label = "Roche", center = Vector3.new(0.0037, 0.0695, -0.0364), size = Vector3.new(1.8967, 0.5994, 1.9654), color = Color3.fromHex("#544A60"), neon = false },
		{ label = "RocheSombre", center = Vector3.new(-0.004, -0.8336, 0.0123), size = Vector3.new(1.4252, 1.5327, 1.5346), color = Color3.fromHex("#3A3245"), neon = false },
	},
	Ruines = {
		{ label = "Mousse", center = Vector3.new(-3.085, 0.045, -1.7933), size = Vector3.new(2.8592, 0.15, 2.5311), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "Pierre", center = Vector3.new(-0.3294, 3.9671, -0.6486), size = Vector3.new(11.6587, 7.883, 4.784), color = Color3.fromHex("#5E5672"), neon = false },
		{ label = "PierreClaire", center = Vector3.new(0.8008, 4.25, -1.8425), size = Vector3.new(13.2017, 8.5, 6.2849), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 0.4, -0), size = Vector3.new(11.8, 0.8, 2.8), color = Color3.fromHex("#433C52"), neon = false },
	},
	SocleIle = {
		{ label = "Joint", center = Vector3.new(0.0285, 0, -0.0053), size = Vector3.new(2.0744, 0, 2.0281), color = Color3.fromHex("#2B2633"), neon = false },
		{ label = "NeonCramoisi", center = Vector3.new(-0.2502, -0.182, -0.5224), size = Vector3.new(0.2886, 0.3293, 0.5726), color = KitMonstres.neon.NeonCramoisi, neon = true },
		{ label = "NeonOrange", center = Vector3.new(0.0444, -0.3586, -0.0985), size = Vector3.new(1.7908, 0.6828, 1.5914), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "NeonViolet", center = Vector3.new(0.1085, -0.1821, 0.0214), size = Vector3.new(1.5718, 0.3297, 1.3133), color = KitMonstres.neon.NeonViolet, neon = true },
		{ label = "PierreSombre", center = Vector3.new(0.0001, -0.3036, 0.0022), size = Vector3.new(1.395, 0.3929, 1.4268), color = Color3.fromHex("#433C52"), neon = false },
		{ label = "Roche", center = Vector3.new(0.0291, -0.2321, -0.0054), size = Vector3.new(2.1159, 0.4643, 2.0687), color = Color3.fromHex("#544A60"), neon = false },
		{ label = "RocheSombre", center = Vector3.new(0.0037, -0.3981, 0.0105), size = Vector3.new(1.7821, 0.7248, 1.7801), color = Color3.fromHex("#3A3245"), neon = false },
	},
	SocleIlot = {
		{ label = "Bois", center = Vector3.new(0.1786, -0.2145, 0.0008), size = Vector3.new(1.678, 0.3838, 2.0293), color = Color3.fromHex("#5A3E2C"), neon = false },
		{ label = "Fonte", center = Vector3.new(0.4314, -0.28, -0.4616), size = Vector3.new(0.8808, 0.4, 0.8199), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "Mousse", center = Vector3.new(0.0324, -0.0624, -0.0172), size = Vector3.new(2.2743, 0.1487, 2.1311), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "MousseSombre", center = Vector3.new(-0.0995, -0.1825, -0.3541), size = Vector3.new(1.751, 0.3166, 1.3208), color = Color3.fromHex("#46682E"), neon = false },
		{ label = "NeonOrange", center = Vector3.new(-0.4968, -0.1979, -0.2009), size = Vector3.new(0.6273, 0.3126, 1.1593), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "PierreSombre", center = Vector3.new(0.0279, -0.27, 0.0032), size = Vector3.new(1.5477, 0.3, 1.5107), color = Color3.fromHex("#433C52"), neon = false },
		{ label = "Roche", center = Vector3.new(0.0421, -0.27, -0.0113), size = Vector3.new(2.1619, 0.54, 2.0644), color = Color3.fromHex("#544A60"), neon = false },
		{ label = "RocheSombre", center = Vector3.new(0.056, -0.4882, -0.0439), size = Vector3.new(1.8161, 0.8564, 1.6762), color = Color3.fromHex("#3A3245"), neon = false },
	},
	Souche = {
		{ label = "Aubier", center = Vector3.new(-0.0017, 1.53, -0.0009), size = Vector3.new(1.9635, 0.06, 2.0439), color = Color3.fromHex("#C9A06A"), neon = false },
		{ label = "ChapeauOrange", center = Vector3.new(0.0498, 0.83, -0.886), size = Vector3.new(2.1296, 0.74, 1.061), color = Color3.fromHex("#F07A3A"), neon = false },
		{ label = "Ecorce", center = Vector3.new(0.1578, 0.7005, 0.083), size = Vector3.new(3.9466, 1.729, 4.0666), color = Color3.fromHex("#5E4030"), neon = false },
		{ label = "Mousse", center = Vector3.new(0.0422, -0.015, -0.3262), size = Vector3.new(3.4063, 0.15, 3.5393), color = Color3.fromHex("#5E8A3C"), neon = false },
	},
	Tombe = {
		{ label = "Mousse", center = Vector3.new(-0.4754, 0.4434, 0.0563), size = Vector3.new(1.1021, 0.2625, 1.1345), color = Color3.fromHex("#5E8A3C"), neon = false },
		{ label = "NeonViolet", center = Vector3.new(0.3654, 1.0007, 0.22), size = Vector3.new(0.2318, 0.8328, 0.07), color = KitMonstres.neon.NeonViolet, neon = true },
		{ label = "PierreClaire", center = Vector3.new(0.0464, 2.0176, 0.0249), size = Vector3.new(1.6885, 3.3983, 0.4484), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 1.2475, -0), size = Vector3.new(2.4, 2.505, 1.2), color = Color3.fromHex("#433C52"), neon = false },
	},
	Tonneaux = {
		{ label = "Fonte", center = Vector3.new(1, 2.1529, -0.95), size = Vector3.new(3.7717, 3.7659, 3.6717), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "Planches", center = Vector3.new(1, 2.0358, -0.95), size = Vector3.new(3.9, 4.0715, 3.743), color = Color3.fromHex("#6A4A34"), neon = false },
	},
	Tour = {
		{ label = "Ardoise", center = Vector3.new(0, 34.7, -0), size = Vector3.new(13.9, 11.8, 13.9), color = Color3.fromHex("#3A3346"), neon = false },
		{ label = "Fonte", center = Vector3.new(0, 13.6975, -0), size = Vector3.new(10.56, 23.495, 10.56), color = Color3.fromHex("#2A2433"), neon = false },
		{ label = "Maconnerie", center = Vector3.new(0, 17.4, -0), size = Vector3.new(11.1, 30, 11.1), color = Color3.fromHex("#5A5268"), neon = false },
		{ label = "NeonOr", center = Vector3.new(0, 23.75, -0), size = Vector3.new(13.2, 40.5, 13.2), color = KitMonstres.neon.NeonOr, neon = true },
		{ label = "NeonOrange", center = Vector3.new(0, 4.2, 5.18), size = Vector3.new(2.4, 3.6, 0), color = KitMonstres.neon.NeonOrange, neon = true },
		{ label = "PierreClaire", center = Vector3.new(0, 19.57, -0), size = Vector3.new(12.6, 18.46, 12.6), color = Color3.fromHex("#7A7190"), neon = false },
		{ label = "PierreSombre", center = Vector3.new(0, 15.65, -0), size = Vector3.new(13.7, 31.3, 13.7), color = Color3.fromHex("#433C52"), neon = false },
	},
} :: { [string]: { Part } })

-- Ciel de jour lumineux rendu dans Blender (bleu lavande au zénith, blanc rosé à l'horizon, nuages blancs) ;
-- le soleil est celui de Roblox (Sky.CelestialBodiesShown), qui éclaire la map comme sur la map des héros.
KitMonstres.sky = table.freeze({
	SkyboxBk = "rbxassetid://82968514182939",
	SkyboxDn = "rbxassetid://81243851579872",
	SkyboxFt = "rbxassetid://95122313982985",
	SkyboxLf = "rbxassetid://130474495765219",
	SkyboxRt = "rbxassetid://93035303033546",
	SkyboxUp = "rbxassetid://129475787667099",
})

-- Textures de particules (blanches sur fond transparent, teintées par ParticleEmitter.Color).
KitMonstres.particles = table.freeze({
	Lueur = "rbxassetid://78663278255683",
	Braise = "rbxassetid://73368706676368",
	Fumee = "rbxassetid://72101987631047",
	Etincelle = "rbxassetid://78820455515607",
	Rune = "rbxassetid://89913226510204",
	Ame = "rbxassetid://88708635741937",
})

-- Planches d'animation (flipbooks) dessinées dans Blender (mm_flipbook.py) : chaque image de la grille est une
-- étape de l'animation, jouée par ParticleEmitter.Flipbook*. OneShot = jouée une fois sur la vie de la particule.
export type Flipbook = { texture: string, layout: Enum.ParticleFlipbookLayout, mode: Enum.ParticleFlipbookMode, fps: number }
KitMonstres.flipbooks = table.freeze({
	Fumee = { texture = "rbxassetid://70598711450593", layout = Enum.ParticleFlipbookLayout.Grid8x8, mode = Enum.ParticleFlipbookMode.OneShot, fps = 0 },
	Flamme = { texture = "rbxassetid://123379140593964", layout = Enum.ParticleFlipbookLayout.Grid4x4, mode = Enum.ParticleFlipbookMode.Loop, fps = 18 },
	Braise = { texture = "rbxassetid://103387778374257", layout = Enum.ParticleFlipbookLayout.Grid4x4, mode = Enum.ParticleFlipbookMode.Loop, fps = 12 },
	Ame = { texture = "rbxassetid://83716989321806", layout = Enum.ParticleFlipbookLayout.Grid4x4, mode = Enum.ParticleFlipbookMode.Loop, fps = 10 },
	Rune = { texture = "rbxassetid://115787196368738", layout = Enum.ParticleFlipbookLayout.Grid4x4, mode = Enum.ParticleFlipbookMode.OneShot, fps = 0 },
	Etincelle = { texture = "rbxassetid://115365755551619", layout = Enum.ParticleFlipbookLayout.Grid4x4, mode = Enum.ParticleFlipbookMode.OneShot, fps = 0 },
} :: { [string]: Flipbook })

-- Palette appliquée par-dessus les couleurs de Blender (par nom de matériau = nom de la pièce) : plus vive que
-- les couleurs d'origine. Modifiable ici sans repasser par Blender ; relancer le générateur pour l'appliquer.
KitMonstres.palette = table.freeze({
	Pierre = Color3.fromHex("#7E6FA8"), -- dalles et maçonnerie lavande
	PierreSombre = Color3.fromHex("#5C4E88"),
	PierreClaire = Color3.fromHex("#A193CC"),
	Joint = Color3.fromHex("#3A3158"),
	Roche = Color3.fromHex("#6C5C8E"),
	RocheSombre = Color3.fromHex("#4A3F6E"),
	Mousse = Color3.fromHex("#72C24C"),
	MousseSombre = Color3.fromHex("#4F9A38"),
	PaveChaud = Color3.fromHex("#E6BA7C"), -- chemins en sable doré, comme les routes des héros
	PaveChaud2 = Color3.fromHex("#D2A066"),
	PaveChaud3 = Color3.fromHex("#F2CF98"),
	Maconnerie = Color3.fromHex("#7466A8"),
	Ardoise = Color3.fromHex("#3F4C9C"), -- toits bleu indigo : contraste avec les murs lavande
	Planches = Color3.fromHex("#9A6840"),
	Bois = Color3.fromHex("#7E5232"),
	Fonte = Color3.fromHex("#2B2240"),
	Laiton = Color3.fromHex("#F0BC48"),
	EmailViolet = Color3.fromHex("#9A5CF0"),
	Os = Color3.fromHex("#F4E8CC"),
	Banniere = Color3.fromHex("#C02A44"),
} :: { [string]: Color3 })

-- Couleurs propres à certains assets (prioritaires sur la palette) : les parcelles des joueurs se détachent
-- du sol en sarcelle / émeraude, bordure claire et liseré doré.
KitMonstres.recolor = table.freeze({
	Parcelle = {
		Pierre = Color3.fromHex("#3E9A90"),
		PierreSombre = Color3.fromHex("#2C7672"),
		PierreClaire = Color3.fromHex("#86D6C4"),
		Joint = Color3.fromHex("#1D4A4C"),
		Laiton = Color3.fromHex("#FFD24A"),
		EmailViolet = Color3.fromHex("#B66CFF"),
	},
} :: { [string]: { [string]: Color3 } })

-- Matériau Roblox de chaque matière (relief net qui se répète, comme les pièces de la map des héros) ;
-- les autres restent en SmoothPlastic.
KitMonstres.materials = table.freeze({
	Pierre = Enum.Material.Slate,
	PierreSombre = Enum.Material.Slate,
	PierreClaire = Enum.Material.Slate,
	Joint = Enum.Material.Slate,
	Ardoise = Enum.Material.Slate,
	Roche = Enum.Material.Rock,
	RocheSombre = Enum.Material.Rock,
	PaveChaud = Enum.Material.Sandstone,
	PaveChaud2 = Enum.Material.Sandstone,
	PaveChaud3 = Enum.Material.Sandstone,
	Maconnerie = Enum.Material.Brick,
	Mousse = Enum.Material.Grass,
	MousseSombre = Enum.Material.Grass,
	Herbe = Enum.Material.Grass,
	HerbeSombre = Enum.Material.Grass,
	Feuillage = Enum.Material.LeafyGrass,
	FeuillageSombre = Enum.Material.LeafyGrass,
	Planches = Enum.Material.WoodPlanks,
	Bois = Enum.Material.Wood,
	Ecorce = Enum.Material.Wood,
	Aubier = Enum.Material.Wood,
	Fonte = Enum.Material.Metal,
	Laiton = Enum.Material.Metal,
	Banniere = Enum.Material.Fabric,
} :: { [string]: Enum.Material })

return table.freeze(KitMonstres)
