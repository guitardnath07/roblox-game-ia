--!strict
-- Monde des monstres : île flottante gothique (architecture presque noire, éclairages or / jaune / orange,
-- ciel crépusculaire violet -> orange). Seule source de vérité des dimensions, couleurs et réglages
-- d'éclairage, lue par le générateur (ServerScriptService.Server.Generateurs.IleMonstres) et par l'ambiance client
-- (AmbianceMonstres). Après un changement de dimensions ou de couleurs, relancer le générateur.

local MondeMonstres = {}

-- Deuxième monde, à l'échelle de la map des héros (≈ 650 studs de large) et organisé pareil : place centrale,
-- 9 parcelles de base aux mêmes rayons et angles, puis une couronne d'îlots reliés par des ponts.
-- Centre de la place (sol) en coordonnées monde : loin de la map des héros (sol de 760 × 760 autour de 0).
MondeMonstres.origin = Vector3.new(3000, 200, 0)
-- Rayon autour du centre dans lequel l'ambiance crépusculaire remplace le cycle jour/nuit.
MondeMonstres.zoneRadius = 1000

MondeMonstres.dims = table.freeze({
	plazaRadius = 60, -- place centrale circulaire
	islandRadius = 168, -- plateforme principale (place + anneau des parcelles)
	ringRoad = { 76, 84 }, -- chemin circulaire entre la place et les parcelles (rayon intérieur, extérieur)
	rockDepth = 80, -- épaisseur de roche sous la plateforme principale
	block = 16, -- taille des blocs de roche de la plateforme principale (style voxel)
	isletBlock = 12, -- taille des blocs de roche des îlots
	tile = 8, -- taille des pavés des îlots
	rings = { 46, 30, 14 }, -- anneaux lumineux de la place
	lightColumnLength = { 110, 220 }, -- longueur des colonnes de lumière sous l'île (min, max)
})

MondeMonstres.colors = table.freeze({
	-- Style « en cubes » de la map des héros : tons vifs et clairs, le détail vient des petites tuiles
	-- (ServerStorage.SurfaceDetail) et des décors en cubes (ServerStorage.VoxelLibMonstres).
	stone = Color3.fromHex("#7E6FA8"), -- maçonnerie lavande
	brick = Color3.fromHex("#8A6AA8"), -- murs des maisons, violet plus chaud
	trim = Color3.fromHex("#9A8CC4"), -- bordures, remparts
	roof = Color3.fromHex("#4250A8"), -- toitures bleu indigo
	plaza = Color3.fromHex("#E6BA7C"), -- dallage chaud de la place (sable doré)
	plazaInner = Color3.fromHex("#D2A066"),
	rock = Color3.fromHex("#6C5C8E"),
	rockDark = Color3.fromHex("#4A3F6E"),
	moss = Color3.fromHex("#72C24C"), -- mousse
	wood = Color3.fromHex("#8A5A38"),
	crystal = Color3.fromHex("#B04CFF"), -- cristaux magiques
	bone = Color3.fromHex("#CFC6B4"), -- os, pierres tombales claires
	-- accents qui cassent la monochromie or/orange : magie violette, flammes spectrales, braises cramoisies
	violet = Color3.fromHex("#7B4DFF"),
	teal = Color3.fromHex("#2EE6C8"),
	crimson = Color3.fromHex("#FF2E5A"),
	gold = Color3.fromHex("#FFC53D"), -- néon doré (anneaux, pointes)
	window = Color3.fromHex("#FFD65A"), -- fenêtres
	orange = Color3.fromHex("#FF8A1F"), -- lanternes, liserés
	ember = Color3.fromHex("#FF6216"), -- roche incandescente
	banner = Color3.fromHex("#8C1A22"),
	light = Color3.fromHex("#FFB347"), -- couleur des PointLight chaudes
})

-- Parcelles des bases (mêmes valeurs que la map des héros, voir Config/Economie si elle revient) :
-- centres tous les `angleStep` degrés depuis +X, entre `inner` et `outer` studs du centre.
MondeMonstres.plots = table.freeze({ count = 9, angleStep = 40, inner = 94, outer = 152, size = 54 })

-- Îlots de la couronne extérieure. angle : degrés depuis l'arrière (-Z), sens horaire vu du dessus (vers +X).
-- kind : "cathedrale" (la Tour des monstres), "tour" (haute tour), "maison" (maison à pignon), "manoir" (manoir
-- hanté), "chapelle" (petite tour + cimetière), "porte" (îlot d'entrée). y : hauteur du sol de l'îlot par rapport à la place.
export type Islet = { angle: number, dist: number, radius: number, y: number, kind: string }
MondeMonstres.islets = table.freeze({
	-- la Tour des monstres, au fond. -10° : l'avenue qui y mène passe entre deux parcelles (260° depuis +X).
	{ angle = -10, dist = 300, radius = 102, y = 22, kind = "cathedrale" },
	{ angle = -48, dist = 258, radius = 40, y = 8, kind = "tour" },
	{ angle = 48, dist = 258, radius = 40, y = 8, kind = "tour" },
	{ angle = -96, dist = 268, radius = 46, y = -2, kind = "maison" },
	{ angle = 96, dist = 268, radius = 46, y = -2, kind = "manoir" },
	{ angle = -142, dist = 258, radius = 38, y = -8, kind = "chapelle" },
	{ angle = 142, dist = 258, radius = 38, y = -8, kind = "chapelle" },
	{ angle = 180, dist = 246, radius = 36, y = -12, kind = "porte" },
} :: { Islet })

-- Éclairage appliqué côté client dans la zone du monde des monstres (crépuscule violet en haut, orange en bas).
MondeMonstres.lighting = table.freeze({
	-- Même rendu que la map des héros (soleil haut, lumière ambiante claire, peu de contraste), teinté lavande :
	-- c'est le soleil de Roblox et le ciel clair (Config/KitMonstres.sky) qui éclairent, plus les néons.
	clockTime = 14.5,
	brightness = 3,
	exposure = 0.1,
	ambient = Color3.fromHex("#6C6488"), -- ombres plus marquées qu'avant, teintées violet (héros : #8A8A8A)
	outdoorAmbient = Color3.fromHex("#A49CB8"), -- lumière du ciel lavande (héros : #9696A0)
	environmentScale = 0.6,
	fogColor = Color3.fromHex("#D8CCE8"),
	atmosphere = {
		Density = 0.25,
		Offset = 0,
		Color = Color3.fromHex("#E6DCFF"), -- brume claire lavande (héros : bleu ciel)
		Decay = Color3.fromHex("#A898E0"),
		Glare = 0.15,
		Haze = 0.6,
	},
	tint = Color3.fromHex("#FFFCFF"),
	saturation = 0.32, -- couleurs plus vives que les héros
	contrast = 0.12, -- relief : ombres et lumières mieux séparées
	bloom = { Intensity = 0.25, Size = 18, Threshold = 1.2 }, -- presque rien : seules les flammes et fenêtres brillent
	sunRays = { Intensity = 0.06, Spread = 0.6 },
	depthOfField = { FarIntensity = 0.08, FocusDistance = 120, InFocusRadius = 220, NearIntensity = 0 },
	fadeSeconds = 1.5,
})

-- Limites de performance (mobile).
MondeMonstres.maxPointLights = 44

-- Style : false = pas de kit Blender ni de modèles Toolbox (ServerStorage.KitMonstres / AssetsMonstres), le
-- générateur construit tout en blocs comme la map des héros. Les deux restent disponibles en repassant à true.
MondeMonstres.useKit = false
MondeMonstres.useToolbox = false
MondeMonstres.emberEmitters = 8

-- Animations (client, AnimationsMonstres) : tags posés par le générateur sur ce qui bouge.
MondeMonstres.tags = table.freeze({
	flotte = "MonstresFlotte", -- rocher flottant : monte, descend et tourne lentement
	flamme = "MonstresFlamme", -- PointLight de feu : vacille
	pulse = "MonstresPulse", -- néon : respire (transparence)
	balance = "MonstresBalance", -- cage suspendue : se balance (attribut Crochet = point d'accroche)
})
MondeMonstres.animation = table.freeze({
	bats = 14, -- chauves-souris autour de la Tour des monstres
	wisps = 6, -- feux follets sur la place
	lightning = { 9, 22 }, -- secondes entre deux éclairs au loin
})

return table.freeze(MondeMonstres)
