--!strict
-- Générateur du deuxième monde (monstres) : grande île flottante gothique, à l'échelle de la map des héros.
-- À lancer dans Studio en mode édition, depuis la barre de commande :
--     require(game.ServerScriptService.Server.Generateurs.IleMonstres).build()
-- (le bootstrap serveur ne charge que Services/ : ce module ne s'exécute jamais tout seul en jeu)
-- Relançable : l'ancien modèle Workspace.MondeMonstres est supprimé avant la reconstruction (pas de doublon).
-- Tous les réglages (position, dimensions, couleurs, parcelles, îlots) : ReplicatedStorage.Shared.Config.MondeMonstres.
-- Construit avec des Parts, WedgeParts et matériaux Roblox, plus quelques modèles de la Toolbox rangés (nettoyés de
-- tout script) dans ServerStorage.AssetsMonstres : Cathedrale, Manoir, Gargouille, Tombe, Cristaux. Si l'un manque,
-- sa version en blocs est construite à la place.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.MondeMonstres)
local Kit = require(ReplicatedStorage.Shared.Config.KitMonstres)

local C = Config.colors
local D = Config.dims
local O = Config.origin
local T = Config.tags

local IleMonstres = {}

local NEON = Enum.Material.Neon
local SLATE = Enum.Material.Slate
local BRICK = Enum.Material.Brick
local ROCK = Enum.Material.Rock
local COBBLE = Enum.Material.Cobblestone
local WOOD = Enum.Material.WoodPlanks
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal
local BASALT = Enum.Material.Basalt
local LAVA = Enum.Material.CrackedLava
local GRANITE = Enum.Material.Granite
local MOSS = Enum.Material.LeafyGrass
local SMOOTH = Enum.Material.SmoothPlastic -- matière du sol détaillé de la map des héros
-- Style « en cubes » de la map des héros : matériaux simples, le relief vient des tuiles de SurfaceDetail.
local FLAT: { [Enum.Material]: Enum.Material } = {
	[Enum.Material.Cobblestone] = SLATE,
	[Enum.Material.Pavement] = SLATE,
	[Enum.Material.Granite] = SLATE,
	[Enum.Material.Basalt] = SLATE,
	[Enum.Material.Rock] = SLATE,
	[Enum.Material.CrackedLava] = SLATE,
	[Enum.Material.Brick] = SMOOTH,
	[Enum.Material.Ground] = SMOOTH,
	[Enum.Material.LeafyGrass] = Enum.Material.Grass,
}

-- Hauteurs des surfaces superposées : au moins 0,1 stud d'écart, sinon Roblox ne sait pas laquelle afficher
-- et les textures scintillent (z-fighting).
local LAYER = 0.1
local PLAZA_TOP = 0.9 -- la place, au-dessus des bandes de dallage et du chemin circulaire
local PLINTH = 5 -- hauteur du socle de la cathédrale

-- État de construction --------------------------------------------------------------------------------------

local rng = Random.new(1337) -- graine fixe : la même île à chaque génération
local created = 0
local lights = 0

-- Couleur d'une veine incandescente : surtout braise orange, parfois cramoisie ou violette (casse la monochromie).
local function veinColor(): Color3
	local r = rng:NextNumber()
	return if r < 0.62 then C.ember elseif r < 0.82 then C.crimson else C.violet
end

-- Matériau et teinte d'un bloc de roche : mélange roche / basalte / ardoise pour varier les textures.
local function rockStyle(): (Color3, Enum.Material)
	local r = rng:NextNumber()
	local color = if rng:NextNumber() < 0.5 then C.rock else C.rockDark
	if r < 0.5 then
		return color, ROCK
	elseif r < 0.8 then
		return color, BASALT
	end
	return color, SLATE
end

-- Laisse respirer Studio toutes les 250 pièces (évite de geler l'éditeur).
local function tick()
	created += 1
	if created % 250 == 0 then
		task.wait()
	end
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = FLAT[material or SLATE] or material or SLATE
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if material == NEON then
		p.CastShadow = false
		p.CanCollide = false
	end
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	tick()
	return p
end

local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = SLATE
	w.Parent = parent
	tick()
end

-- Disque horizontal (cylindre couché) de rayon r et d'épaisseur h, dont le dessus est à `top`, centré sur `at`.
local function disc(parent: Instance, r: number, h: number, top: number, color: Color3, material: Enum.Material?, at: Vector3?): BasePart
	local c = (at or Vector3.zero) + Vector3.new(0, top - h / 2, 0)
	return part(parent, Vector3.new(h, r * 2, r * 2), CFrame.new(O + c) * CFrame.Angles(0, 0, math.rad(90)), color, material, { Shape = Enum.PartType.Cylinder })
end

local function light(parent: BasePart, range: number, brightness: number?, color: Color3?, tag: string?)
	if lights >= Config.maxPointLights then
		return
	end
	lights += 1
	local l = Instance.new("PointLight")
	l.Color = color or C.light
	l.Range = range
	l.Brightness = brightness or 1.6
	l.Shadows = false
	l.Parent = parent
	if tag then
		CollectionService:AddTag(l, tag)
	end
end

-- Projecteur : éclaire une façade depuis le sol (relief et ombres portées sur la Tour des monstres).
local function spot(parent: Instance, cf: CFrame, color: Color3, range: number)
	local holder = part(parent, Vector3.new(1.2, 0.6, 1.2), cf, C.roof, METAL)
	local l = Instance.new("SpotLight")
	l.Color = color
	l.Range = range
	l.Angle = 55
	l.Brightness = 3
	l.Face = Enum.NormalId.Front
	l.Shadows = true
	l.Parent = holder
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Direction (à plat) d'un angle en degrés mesuré depuis l'arrière (-Z), sens horaire vu du dessus.
local function dir(angle: number): Vector3
	local a = math.rad(angle)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- Perpendiculaire (à plat) d'une direction.
local function side(d: Vector3): Vector3
	return Vector3.new(d.Z, 0, -d.X)
end

-- CFrame monde d'un point local tourné vers le centre de la place.
local function facingCentre(localPos: Vector3): CFrame
	local p = O + localPos
	local target = O + Vector3.new(0, localPos.Y, 0)
	if (target - p).Magnitude < 0.1 then
		return CFrame.new(p)
	end
	return CFrame.lookAt(p, target)
end

-- Kit 3D (Blender) -------------------------------------------------------------------------------------------
-- Les modèles détaillés de Config/KitMonstres (meshes importés une fois dans ServerStorage.KitMonstres). Chaque
-- fonction de construction essaie d'abord le kit et garde sa version en pièces si le kit n'est pas importé.

-- Place l'asset `name` au point de pose `cf`, avec une échelle par axe facultative ; nil sans le kit.
local function hasKit(): boolean
	return Config.useKit and ServerStorage:FindFirstChild("KitMonstres") ~= nil
end

local function kit(parent: Instance, name: string, cf: CFrame, scale: Vector3?): Model?
	local folder = if Config.useKit then ServerStorage:FindFirstChild("KitMonstres") else nil
	local spec = Kit.assets[name]
	if not folder or not spec then
		return nil
	end
	local s = scale or Vector3.one
	local m = Instance.new("Model")
	m.Name = name
	for _, p in spec do
		local src = folder:FindFirstChild(`{name}__{p.label}`, true)
		if not (src and src:IsA("MeshPart")) then
			m:Destroy()
			return nil
		end
		local mp = src:Clone()
		mp.Name = (string.gsub(p.label, "%.%d+$", "")) -- « NeonOrange.001 » (doublon de nom dans Blender) -> « NeonOrange »
		mp.Anchored = true
		mp.Size = p.size * s
		mp.CFrame = cf * CFrame.new(p.center * s) * CFrame.Angles(0, math.pi, 0) -- l'importateur FBX tourne les meshes d'un demi-tour
		local override = Kit.recolor[name]
		mp.Color = if p.neon then p.color else (override and override[p.label]) or Kit.palette[p.label] or p.color
		mp.TextureID = ""
		if p.neon then
			mp.Material = NEON
			mp.CastShadow = false
			mp.CanCollide = false
		else
			mp.Material = Enum.Material.SmoothPlastic -- couleur unie, comme la map des héros
		end
		mp.Parent = m
		tick()
	end
	m.WorldPivot = cf
	m.Parent = parent
	return m
end

-- Partie néon d'un asset du kit (pour y accrocher une lumière ou un feu).
local function glowOf(m: Model, ...: string): BasePart?
	for _, label in { ... } do
		local p = m:FindFirstChild(label)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

-- Décor en cubes de ServerStorage.VoxelLibMonstres (Generateurs/VoxelMonstres), mis à la hauteur voulue et posé
-- par sa base sur `cf` ; nil si la bibliothèque n'a pas été générée.
local function voxel(parent: Instance, group: string, names: { string }, cf: CFrame, height: number): Model?
	local lib = ServerStorage:FindFirstChild("VoxelLibMonstres")
	local g = lib and lib:FindFirstChild(group)
	local src = g and g:FindFirstChild(names[rng:NextInteger(1, #names)])
	if not (src and src:IsA("Model")) then
		return nil
	end
	local m = src:Clone()
	local _, size = m:GetBoundingBox()
	m:ScaleTo(math.max(0.2, height / size.Y))
	m:PivotTo(cf)
	m.Parent = parent
	tick()
	return m
end

-- Applique une planche d'animation du kit (Config/KitMonstres.flipbooks) à un émetteur de particules.
local function flipbook(p: ParticleEmitter, name: string)
	local f = Kit.flipbooks[name]
	p.Texture = f.texture
	p.FlipbookLayout = f.layout
	p.FlipbookMode = f.mode
	if f.fps > 0 then
		p.FlipbookFramerate = NumberRange.new(f.fps)
		p.FlipbookStartRandom = true
	end
end

-- Roche -----------------------------------------------------------------------------------------------------

-- Socle rocheux voxel en cône renversé sous un disque (centre local `c`, dessus à c.Y), avec de fines veines
-- incandescentes sur le pourtour et des pointes qui pendent dessous. Seule la coque est en blocs (le cœur est
-- un seul bloc) pour limiter le nombre de pièces. Renvoie les points bas des pointes.
local function rockBase(parent: Instance, c: Vector3, radius: number, depth: number, b: number): { Vector3 }
	-- socle du kit : cône rocheux de rayon 1 et de profondeur 0.5, étiré au rayon et à la profondeur voulus
	-- îlots : socle à rebord de mousse et racines (profondeur 0.6) ; île principale : socle à strates (0.5)
	local islet = b == D.isletBlock
	local rockName, rockDepth = if islet then "SocleIlot" else "SocleIle", if islet then 0.6 else 0.5
	-- le dessus du socle d'îlot est une calotte de mousse (z = 0.012 dans le mesh) : on la cache sous le sol
	local sink = if islet then 0.25 + 0.012 * depth / rockDepth else 0.3
	if kit(parent, rockName, CFrame.new(O + c - Vector3.new(0, sink, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Vector3.new(radius, depth / rockDepth, radius)) then
		local tips: { Vector3 } = {}
		for _ = 1, 4 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, radius * 0.25)
			table.insert(tips, c + Vector3.new(math.cos(a) * r, -depth * 0.85, math.sin(a) * r))
		end
		return tips
	end
	local lh = 7 -- hauteur d'une couche
	local layers = math.max(2, math.floor(depth / lh))
	for i = 0, layers - 1 do
		local t = i / layers
		local r = radius * (1 - t) ^ 0.85
		local y = c.Y - lh / 2 - 1 - i * lh
		for x = -radius, radius, b do
			for z = -radius, radius, b do
				local d = math.sqrt(x * x + z * z)
				local inShell = d < r + rng:NextNumber(-b / 3, b / 3) and d > r - b * 2
				if inShell or (d < r and i == layers - 1) then
					local s = b + rng:NextNumber(0, b * 0.25)
					local h = lh + rng:NextNumber(0, 2)
					local pos = O + Vector3.new(c.X + x + rng:NextNumber(-1, 1), y, c.Z + z + rng:NextNumber(-1, 1))
					local edge = d > r - b * 1.2
					if edge and i <= 3 and rng:NextNumber() < 0.08 then
						-- bloc de lave craquelée : texture à fissures orangées
						part(parent, Vector3.new(s, h, s), CFrame.new(pos), Color3.fromHex("#9A4A30"), LAVA)
					else
						local color, material = rockStyle()
						part(parent, Vector3.new(s, h, s), CFrame.new(pos), color, material)
					end
					-- mousse sombre sur le dessus de la première couche
					if i == 0 and edge and rng:NextNumber() < 0.3 then
						part(parent, Vector3.new(s * rng:NextNumber(0.5, 1), 0.6, s * rng:NextNumber(0.5, 1)), CFrame.new(pos + Vector3.new(0, h / 2 + 0.1, 0)), C.moss, MOSS)
					end
					-- bloc saillant qui jaillit du flanc (silhouette déchiquetée)
					if i <= layers - 2 and d > r - b * 1.2 and d > 0 and rng:NextNumber() < 0.14 then
						local out = Vector3.new(x, 0, z).Unit
						local js = s * rng:NextNumber(0.5, 0.85)
						local color, material = rockStyle()
						part(parent, Vector3.new(js, h * rng:NextNumber(0.7, 1.3), js), CFrame.new(pos + out * (s * 0.45)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), color, material)
					end
					-- fissure incandescente : fine veine néon qui affleure sur la face extérieure
					if i <= 2 and d > r - b * 1.2 and d > 0 and rng:NextNumber() < 0.2 then
						local out = Vector3.new(x, 0, z).Unit
						local vein = CFrame.lookAt(pos + out * (s / 2 + 0.05), pos + out * (s + 1))
						part(parent, Vector3.new(s * rng:NextNumber(0.3, 0.8), rng:NextNumber(0.5, 1.4), 0.3), vein * CFrame.new(0, rng:NextNumber(-h / 3, h / 3), 0), veinColor(), NEON)
					end
				end
			end
		end
	end
	-- cœur plein : disques empilés qui suivent le cône, à l'intérieur de la coque
	for i = 0, layers - 1, 2 do
		local r = radius * (1 - i / layers) ^ 0.85 - b * 1.2
		if r > 2 then
			disc(parent, r, lh * 2, -1 - i * lh, C.rockDark, ROCK, Vector3.new(c.X, 0, c.Z) + Vector3.new(0, c.Y, 0))
		end
	end
	-- pointes qui pendent sous le socle
	local tips: { Vector3 } = {}
	local spikes = math.max(3, math.floor(radius / 12))
	for _ = 1, spikes do
		local a = rng:NextNumber(0, math.pi * 2)
		local rr = rng:NextNumber(0, radius * 0.5)
		local x, z = math.cos(a) * rr, math.sin(a) * rr
		local y = c.Y - 1 - layers * lh + 4
		local w = rng:NextNumber(b * 0.5, b * 0.9)
		local len = rng:NextNumber(depth * 0.35, depth * 0.8)
		local steps = 4
		for k = 0, steps - 1 do
			local ww = w * (1 - k / steps) + 1.5
			local hh = len / steps
			part(parent, Vector3.new(ww, hh, ww), CFrame.new(O + Vector3.new(c.X + x, y - k * hh - hh / 2, c.Z + z)), C.rockDark, BASALT)
		end
		table.insert(tips, Vector3.new(c.X + x, y - len, c.Z + z))
	end
	-- pointes secondaires accrochées le long du cône, certaines au bout incandescent
	for _ = 1, spikes * 2 do
		local i = rng:NextInteger(1, math.max(1, layers - 2))
		local r = radius * (1 - i / layers) ^ 0.85 * rng:NextNumber(0.6, 0.9)
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local y = c.Y - 1 - (i + 1) * lh
		local w = rng:NextNumber(b * 0.3, b * 0.6)
		local len = rng:NextNumber(depth * 0.15, depth * 0.45)
		for k = 0, 2 do
			local ww = w * (1 - k / 3) + 1
			local hh = len / 3
			part(parent, Vector3.new(ww, hh, ww), CFrame.new(O + Vector3.new(c.X + x, y - k * hh - hh / 2, c.Z + z)), C.rockDark, ROCK)
		end
		if rng:NextNumber() < 0.35 then
			part(parent, Vector3.new(1.4, 2.2, 1.4), CFrame.new(O + Vector3.new(c.X + x, y - len - 1, c.Z + z)), veinColor(), NEON)
		end
	end
	return tips
end

-- Colonne de lumière qui tombe sous l'île (cœur néon + halo translucide).
-- Une colonne sur trois est violette (magie) pour casser la monochromie or/orange.
local function lightColumn(parent: Instance, top: Vector3, length: number)
	local magic = rng:NextNumber() < 0.33
	local core, halo = if magic then Color3.fromHex("#C9A2FF") else C.gold, if magic then C.violet else C.orange
	part(parent, Vector3.new(6, length, 6), CFrame.new(O + top - Vector3.new(0, length / 2, 0)), core, NEON, { Transparency = 0.05 })
	local glow = part(parent, Vector3.new(11, length * 0.95, 11), CFrame.new(O + top - Vector3.new(0, length * 0.475, 0)), halo, NEON, { Transparency = 0.78 })
	CollectionService:AddTag(glow, T.pulse)
	-- étincelles qui tombent le long de la colonne
	local p = Instance.new("ParticleEmitter")
	flipbook(p, "Etincelle") -- planche animée dessinée dans Blender (mm_flipbook.py)
	p.Color = ColorSequence.new(core, halo)
	p.LightEmission = 1
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new(0, 1)
	p.Lifetime = NumberRange.new(4, 7)
	p.Rate = 5
	p.Speed = NumberRange.new(4, 9)
	p.EmissionDirection = Enum.NormalId.Bottom
	p.SpreadAngle = Vector2.new(10, 10)
	p.Parent = glow
end

-- Petits détails ---------------------------------------------------------------------------------------------

-- Bougie / pointe lumineuse posée sur `cf` (base).
local function candle(parent: Instance, cf: CFrame, height: number?)
	local h = height or 2.4
	part(parent, Vector3.new(0.7, h, 0.7), cf * CFrame.new(0, h / 2, 0), C.gold, NEON)
end

-- Barre entre deux points monde (ferronnerie, crosses de lampadaire).
local function bar(parent: Instance, a: Vector3, b: Vector3, t: number, color: Color3?)
	part(parent, Vector3.new(t, t, (b - a).Magnitude + t * 0.5), CFrame.lookAt((a + b) / 2, b), color or C.roof, METAL)
end

-- Pilier de pierre (référence : piliers de grilles de cimetière victoriens) : socle évasé en deux gradins, fût
-- avec panneau gravé et fente lumineuse, corniche débordante, chapeau pyramidal et fleuron au hasard
-- (boule de fonte, bougie ou crâne aux yeux rouges).
local function pier(parent: Instance, cf: CFrame, h: number, w: number?)
	local names = { "PilierBoule", "PilierCrane", "PilierBougie" }
	local k = (w or 1.8) / 1.7
	if kit(parent, names[rng:NextInteger(1, #names)], cf, Vector3.new(k, h / 5.6, k)) then
		return
	end
	local s = w or 1.8
	part(parent, Vector3.new(s * 1.4, 0.6, s * 1.4), cf * CFrame.new(0, 0.3, 0), C.trim, SLATE)
	part(parent, Vector3.new(s * 1.18, 0.4, s * 1.18), cf * CFrame.new(0, 0.8, 0), C.stone, SLATE)
	local shaft = h - 1.9
	part(parent, Vector3.new(s, shaft, s), cf * CFrame.new(0, 1 + shaft / 2, 0), C.stone, SLATE)
	if shaft > 2.5 then
		local glow = if rng:NextNumber() < 0.5 then C.gold elseif rng:NextNumber() < 0.5 then C.violet else C.ember
		for _, sz in { -1, 1 } do
			part(parent, Vector3.new(s * 0.62, shaft * 0.62, 0.1), cf * CFrame.new(0, 1 + shaft / 2, sz * (s / 2 + 0.05)), C.roof, SLATE)
			part(parent, Vector3.new(0.16, shaft * 0.45, 0.1), cf * CFrame.new(0, 1 + shaft / 2, sz * (s / 2 + LAYER + 0.05)), glow, NEON)
		end
	end
	part(parent, Vector3.new(s * 1.3, 0.35, s * 1.3), cf * CFrame.new(0, h - 0.72, 0), C.trim, SLATE)
	part(parent, Vector3.new(s * 1.1, 0.35, s * 1.1), cf * CFrame.new(0, h - 0.38, 0), C.stone, SLATE)
	part(parent, Vector3.new(s * 0.75, 0.4, s * 0.75), cf * CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(45), 0), C.roof, SLATE)
	part(parent, Vector3.new(s * 0.42, 0.4, s * 0.42), cf * CFrame.new(0, h + 0.4, 0) * CFrame.Angles(0, math.rad(45), 0), C.roof, SLATE)
	local r = rng:NextNumber()
	if r < 0.45 then
		part(parent, Vector3.new(0.75, 0.75, 0.75), cf * CFrame.new(0, h + 0.9, 0), C.roof, METAL, { Shape = Enum.PartType.Ball })
	elseif r < 0.8 then
		candle(parent, cf * CFrame.new(0, h + 0.6, 0), 1.4)
	else
		local skull = cf * CFrame.new(0, h + 1.05, 0)
		part(parent, Vector3.new(1, 1, 1), skull, C.bone, GRANITE, { Shape = Enum.PartType.Ball })
		for _, sx in { -1, 1 } do
			part(parent, Vector3.new(0.18, 0.18, 0.1), skull * CFrame.new(sx * 0.2, 0.05, 0.47), C.crimson, NEON)
		end
	end
end

-- Grille de cimetière en fer forgé (référence : grilles victoriennes sur muret) : muret et couvertine en pierre,
-- lisses basse et haute, barreaux à pointe de lance dont la hauteur suit un arc entre deux piliers, un barreau
-- sur quatre plus haut, frise de losanges. Coupée en travées par des piliers (pas de longue ligne droite).
-- `a` : centre au sol, la grille court le long de son axe X.
local function railing(parent: Instance, a: CFrame, len: number, h: number?)
	local hh = h or 3
	local bays = math.max(1, math.ceil(len / 16))
	local bay = len / bays
	if hasKit() then
		-- travées du kit (12 studs de long, étirées à la longueur de la travée), piliers entre deux travées
		for b = 0, bays - 1 do
			kit(parent, "GrilleTravee", a * CFrame.new(-len / 2 + (b + 0.5) * bay, 0, 0), Vector3.new(bay / 12, hh / 3, 1))
			if b > 0 then
				pier(parent, a * CFrame.new(-len / 2 + b * bay, 0, 0), hh + 2.2, 1.4)
			end
		end
		return
	end
	part(parent, Vector3.new(len, 0.8, 0.9), a * CFrame.new(0, 0.4, 0), C.trim, SLATE)
	part(parent, Vector3.new(len, 0.2, 1.1), a * CFrame.new(0, 0.9, 0), C.stone, SLATE)
	for b = 0, bays - 1 do
		local x0 = -len / 2 + b * bay
		local rail = 1 + hh * 0.7
		part(parent, Vector3.new(bay, 0.2, 0.2), a * CFrame.new(x0 + bay / 2, 1.35, 0), C.roof, METAL)
		part(parent, Vector3.new(bay, 0.2, 0.2), a * CFrame.new(x0 + bay / 2, rail, 0), C.roof, METAL)
		local n = math.max(2, math.floor(bay / 1.7))
		for i = 1, n - 1 do
			local u = i / n
			local top = 1 + hh + math.sin(u * math.pi) * hh * 0.3 + (if i % 4 == 0 then 0.6 else 0)
			local x = x0 + u * bay
			part(parent, Vector3.new(0.15, top - 1, 0.15), a * CFrame.new(x, (1 + top) / 2, 0), C.roof, METAL)
			part(parent, Vector3.new(0.4, 0.4, 0.1), a * CFrame.new(x, top + 0.12, 0) * CFrame.Angles(0, 0, math.rad(45)), C.roof, METAL)
			if i % 3 == 1 and i < n - 1 then
				part(parent, Vector3.new(0.42, 0.42, 0.08), a * CFrame.new(x + bay / n / 2, (1.35 + rail) / 2, 0) * CFrame.Angles(0, 0, math.rad(45)), C.roof, METAL)
			end
		end
		if b > 0 then
			pier(parent, a * CFrame.new(x0, 0, 0), hh + 2.2, 1.4)
		end
	end
end

-- Lanterne suspendue sous `hook` : chaîne, toit pointu à gradins, verre lumineux entre quatre montants, pointe.
local function lantern(parent: Instance, hook: CFrame, color: Color3): BasePart
	part(parent, Vector3.new(0.14, 0.7, 0.14), hook * CFrame.new(0, -0.35, 0), C.roof, METAL)
	local body = hook * CFrame.new(0, -2, 0)
	part(parent, Vector3.new(1.7, 0.25, 1.7), body * CFrame.new(0, 0.95, 0), C.roof, METAL)
	part(parent, Vector3.new(1.15, 0.35, 1.15), body * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, math.rad(45), 0), C.roof, METAL)
	part(parent, Vector3.new(0.6, 0.35, 0.6), body * CFrame.new(0, 1.55, 0) * CFrame.Angles(0, math.rad(45), 0), C.roof, METAL)
	local glow = part(parent, Vector3.new(1.05, 1.5, 1.05), body, color, NEON)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(parent, Vector3.new(0.16, 1.75, 0.16), body * CFrame.new(c[1] * 0.58, 0, c[2] * 0.58), C.roof, METAL)
	end
	part(parent, Vector3.new(1.35, 0.22, 1.35), body * CFrame.new(0, -0.85, 0), C.roof, METAL)
	part(parent, Vector3.new(0.3, 0.45, 0.3), body * CFrame.new(0, -1.15, 0) * CFrame.Angles(0, math.rad(45), 0), C.roof, METAL)
	return glow
end

-- Lampadaire gothique (référence : réverbères victoriens en fonte) : socle mouluré, fût cannelé à bagues,
-- 1 à 3 crosses en col de cygne portant des lanternes suspendues, fleuron (pointe ou crâne). Hauteur, nombre
-- de bras et orientation varient, et le poteau penche à peine : pas deux lampadaires identiques.
local function lamp(parent: Instance, localPos: Vector3, withLight: boolean)
	local name = if rng:NextNumber() < 0.55 then "Lampadaire2Bras" else "Lampadaire1Bras"
	local m = kit(parent, name, CFrame.new(O + localPos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	if m then
		local glow = glowOf(m, "NeonOrange", "NeonTurquoise")
		if withLight and glow then
			light(glow, 20, nil, glow.Color, T.flamme)
		end
		return
	end
	local base = CFrame.new(O + localPos) * CFrame.Angles(rng:NextNumber(-0.03, 0.03), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.03, 0.03))
	local h = rng:NextNumber(8.5, 10.5)
	part(parent, Vector3.new(2.3, 0.5, 2.3), base * CFrame.new(0, 0.25, 0), C.stone, SLATE)
	part(parent, Vector3.new(1.5, 1.2, 1.5), base * CFrame.new(0, 1.1, 0), C.roof, METAL)
	part(parent, Vector3.new(1.1, 0.35, 1.1), base * CFrame.new(0, 1.85, 0) * CFrame.Angles(0, math.rad(45), 0), C.roof, METAL)
	part(parent, Vector3.new(0.5, h - 2, 0.5), base * CFrame.new(0, (h + 2) / 2, 0), C.roof, METAL)
	part(parent, Vector3.new(0.72, h - 3.2, 0.22), base * CFrame.new(0, (h + 2) / 2, 0), C.roof, METAL) -- cannelures
	part(parent, Vector3.new(0.22, h - 3.2, 0.72), base * CFrame.new(0, (h + 2) / 2, 0), C.roof, METAL)
	for _, y in { 2.4, h * 0.62, h - 0.4 } do
		part(parent, Vector3.new(0.9, 0.25, 0.9), base * CFrame.new(0, y, 0), C.roof, METAL)
	end
	local spectral = rng:NextNumber() < 0.3 -- certaines lanternes brûlent d'une flamme spectrale
	local color = if spectral then C.teal else C.orange
	local r = rng:NextNumber()
	local arms = if r < 0.4 then 1 elseif r < 0.8 then 2 else 3
	for i = 1, arms do
		local arm = base * CFrame.Angles(0, (i - 1) / arms * math.pi * 2, 0)
		local p = function(x: number, y: number): Vector3
			return (arm * CFrame.new(x, y, 0)).Position
		end
		bar(parent, p(0, h - 0.7), p(1.1, h + 0.1), 0.24)
		bar(parent, p(1.1, h + 0.1), p(2.3, h + 0.15), 0.24)
		bar(parent, p(2.3, h + 0.15), p(2.6, h - 0.15), 0.24)
		bar(parent, p(0, h - 2), p(1.3, h - 0.05), 0.16) -- console décorative sous la crosse
		local glow = lantern(parent, CFrame.new(p(2.6, h - 0.2)) * (base - base.Position), color)
		if withLight and i == 1 then
			light(glow, 20, nil, if spectral then C.teal else nil, T.flamme)
		end
	end
	if rng:NextNumber() < 0.25 then
		local skull = base * CFrame.new(0, h + 0.4, 0)
		part(parent, Vector3.new(0.9, 0.9, 0.9), skull, C.bone, GRANITE, { Shape = Enum.PartType.Ball })
		part(parent, Vector3.new(0.16, 0.16, 0.1), skull * CFrame.new(0.18, 0.05, 0.43), C.crimson, NEON)
		part(parent, Vector3.new(0.16, 0.16, 0.1), skull * CFrame.new(-0.18, 0.05, 0.43), C.crimson, NEON)
	else
		part(parent, Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(0, h + 0.1, 0) * CFrame.Angles(0, math.rad(45), 0), C.roof, METAL)
		part(parent, Vector3.new(0.18, 1.2, 0.18), base * CFrame.new(0, h + 0.8, 0), C.roof, METAL)
		part(parent, Vector3.new(0.35, 0.35, 0.1), base * CFrame.new(0, h + 1.1, 0) * CFrame.Angles(0, 0, math.rad(45)), C.roof, METAL)
	end
end

-- Arbre mort : tronc tordu + branches nues.
local function deadTree(parent: Instance, localPos: Vector3, height: number)
	local trees = { "ArbreMort1", "ArbreMort2", "ArbreMort3", "ArbreHante1", "ArbreHante2" }
	if voxel(parent, "Arbres", trees, CFrame.new(O + localPos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), height * 1.1) then
		return
	end
	if kit(parent, "ArbreMort", CFrame.new(O + localPos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Vector3.one * (height / 10)) then
		return
	end
	local base = CFrame.new(O + localPos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local w = height / 7
	part(parent, Vector3.new(w, height, w), base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(4)), C.wood, WOOD)
	for i = 1, 7 do
		local y = height * rng:NextNumber(0.45, 0.95)
		local len = height * rng:NextNumber(0.3, 0.6)
		local yaw = (i / 7) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local tilt = math.rad(rng:NextNumber(30, 60))
		local cf = base * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, -tilt) * CFrame.new(0, len / 2, 0)
		part(parent, Vector3.new(w * 0.4, len, w * 0.4), cf, C.wood, WOOD)
		local twig = cf * CFrame.new(0, len / 2, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-50, 50))) * CFrame.new(0, len * 0.2, 0)
		part(parent, Vector3.new(w * 0.25, len * 0.4, w * 0.25), twig, C.wood, WOOD)
	end
end

-- Bannière rouge à liseré doré, accrochée sur une façade (cf = centre, face avant vers -Z local).
local function banner(parent: Instance, cf: CFrame, w: number, h: number)
	part(parent, Vector3.new(w + 0.6, 0.4, 0.4), cf * CFrame.new(0, h / 2 + 0.2, 0), C.roof, METAL)
	part(parent, Vector3.new(w, h, 0.25), cf, C.banner, FABRIC)
	part(parent, Vector3.new(w, 0.35, 0.3), cf * CFrame.new(0, -h / 2 + 0.6, 0), C.gold, NEON)
	part(parent, Vector3.new(w * 0.35, w * 0.35, 0.3), cf * CFrame.new(0, h * 0.12, -0.05) * CFrame.Angles(0, 0, math.rad(45)), C.gold, NEON)
end

-- Fenêtres lumineuses sur une face : `face` = CFrame au centre de la face, -Z local vers l'extérieur.
local function windows(parent: Instance, face: CFrame, width: number, height: number, cols: number, rows: number, ww: number, wh: number)
	for c = 1, cols do
		for r = 1, rows do
			local x = (c - (cols + 1) / 2) * (width / cols)
			local y = (r - (rows + 1) / 2) * (height / rows)
			part(parent, Vector3.new(ww + 0.8, wh + 0.8, 0.4), face * CFrame.new(x, y, 0.05), C.roof, SLATE)
			part(parent, Vector3.new(ww, wh, 0.4), face * CFrame.new(x, y, -0.15), C.window, NEON)
			-- appui saillant + arc en ogive au-dessus (profondeur de façade)
			part(parent, Vector3.new(ww + 1.6, 0.45, 1), face * CFrame.new(x, y - wh / 2 - 0.55, -0.3), C.trim, SLATE)
			local bar = Vector3.new(ww * 0.78 + 0.4, 0.5, 0.7)
			for _, sx in { -1, 1 } do
				part(parent, bar, face * CFrame.new(x + sx * ww * 0.25, y + wh / 2 + ww * 0.25 + 0.35, -0.2) * CFrame.Angles(0, 0, -sx * math.rad(40)), C.trim, SLATE)
			end
		end
	end
end

-- Toit pyramidal en gradins (style voxel), base `cf` = centre du haut du corps de bâtiment.
local function steppedRoof(parent: Instance, cf: CFrame, w: number, d: number, h: number, steps: number): CFrame
	local sh = h / steps
	for i = 0, steps - 1 do
		local k = 1 - i / steps
		part(parent, Vector3.new(w * k + 1, sh, d * k + 1), cf * CFrame.new(0, sh * (i + 0.5), 0), C.roof, SLATE)
	end
	return cf * CFrame.new(0, h, 0)
end

-- Rempart crénelé entre deux points locaux au sol (créneaux un sur deux).
local function battlement(parent: Instance, a: Vector3, b: Vector3, h: number)
	local len = (b - a).Magnitude
	if len < 0.5 then
		return
	end
	local cf = CFrame.lookAt(O + (a + b) / 2, O + b)
	-- rempart du kit : 12 studs de long sur son axe X, ramené le long du segment
	if kit(parent, "Rempart", cf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new((len + 0.3) / 12, h / 3, 1)) then
		return
	end
	part(parent, Vector3.new(1.8, h, len + 0.3), cf * CFrame.new(0, h / 2, 0), C.trim, SLATE)
	part(parent, Vector3.new(2.3, 0.5, len + 0.3), cf * CFrame.new(0, h + 0.25, 0), C.stone, SLATE)
	local n = math.max(2, math.floor(len / 2.6))
	for k = 0, n - 1, 2 do
		local z = -len / 2 + (k + 0.5) * len / n
		local r = rng:NextNumber()
		if r < 0.12 then
			-- merlon effondré : bloc de travers au pied du mur
			part(parent, Vector3.new(1.5, 1.1, len / n * 0.8), cf * CFrame.new(1.6, 0.5, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.5, 0.5), rng:NextNumber(0.2, 0.6)), C.stone, SLATE)
		else
			local mh = rng:NextNumber(1.1, 1.8)
			part(parent, Vector3.new(1.8, mh, len / n), cf * CFrame.new(0, h + 0.5 + mh / 2, z), if r < 0.3 then C.trim else C.stone, SLATE)
			if r > 0.85 then
				part(parent, Vector3.new(1.9, 0.25, len / n * 0.7), cf * CFrame.new(0, h + 0.62 + mh, z), C.moss, MOSS)
			end
		end
	end
	if len > 6 and rng:NextNumber() < 0.4 then
		-- contrefort à l'extrémité du segment (rythme le mur)
		pier(parent, cf * CFrame.new(0, 0, -len / 2), h + 2.4, 2.4)
	end
end

-- Arche gothique : deux piliers à pinacle et un linteau en ogive souligné de néon. `cf` = centre au sol.
local function archGate(parent: Instance, cf: CFrame, width: number, height: number)
	if kit(parent, "Arche", cf, Vector3.new(width / 12, height / 10, 1)) then
		return
	end
	local m = model(parent, "Arche")
	local half = width / 2
	for _, sx in { -1, 1 } do
		local p = cf * CFrame.new(sx * half, 0, 0)
		part(m, Vector3.new(3.4, 1, 3.4), p * CFrame.new(0, 0.5, 0), C.trim, SLATE)
		part(m, Vector3.new(2.6, height, 2.6), p * CFrame.new(0, height / 2, 0), C.stone, SLATE)
		candle(m, steppedRoof(m, p * CFrame.new(0, height, 0), 2.6, 2.6, 3, 3), 2.5)
	end
	local rise = width * 0.3
	local seg = math.sqrt(half * half + rise * rise)
	local tilt = math.atan2(rise, half)
	local base = cf * CFrame.new(0, height - 1.5, 0)
	for _, sx in { -1, 1 } do
		local cfSeg = base * CFrame.new(sx * half / 2, rise / 2, 0) * CFrame.Angles(0, 0, -sx * tilt)
		part(m, Vector3.new(seg + 1.4, 1.6, 2), cfSeg, C.stone, SLATE)
		part(m, Vector3.new(seg, 0.4, 2.2), cfSeg * CFrame.new(0, -0.9, 0), C.gold, NEON)
	end
	candle(m, base * CFrame.new(0, rise + 0.8, 0), 2.5)
end

-- Rocher flottant autour de l'île (profondeur de la scène) : bloc principal, éclats dessous, pointe,
-- parfois une veine incandescente et une bougie.
local function floatingRock(parent: Instance, pos: Vector3, size: number)
	local names = { "RocherFlottant", "RocherFlottant", "Rocher1", "Rocher3" }
	local name = names[rng:NextInteger(1, #names)]
	local k = kit(parent, name, CFrame.new(O + pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Vector3.one * (size / (if name == "RocherFlottant" then 2.2 else 6)))
	if k then
		CollectionService:AddTag(k, T.flotte)
		return
	end
	local m = model(parent, "RocherFlottant")
	CollectionService:AddTag(m, T.flotte)
	local base = CFrame.new(O + pos) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.25, 0.25))
	local topColor, topMaterial = rockStyle()
	part(m, Vector3.new(size, size * 0.5, size), base, topColor, topMaterial)
	part(m, Vector3.new(size * 0.8, 0.5, size * 0.8), base * CFrame.new(0, size * 0.25 + 0.2, 0), C.moss, MOSS)
	for _ = 1, 4 do
		local s = size * rng:NextNumber(0.35, 0.6)
		part(m, Vector3.new(s, s * 0.8, s), base * CFrame.new(rng:NextNumber(-size / 3, size / 3), -size * 0.25 - s * 0.3, rng:NextNumber(-size / 3, size / 3)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), C.rockDark, ROCK)
	end
	part(m, Vector3.new(size * 0.3, size * 0.9, size * 0.3), base * CFrame.new(0, -size * 0.75, 0), C.rockDark, ROCK)
	if rng:NextNumber() < 0.6 then
		part(m, Vector3.new(size * 0.5, 0.45, 0.3), base * CFrame.new(0, -size * 0.05, -size / 2 - 0.05), if rng:NextNumber() < 0.5 then C.teal else C.violet, NEON)
	end
	if rng:NextNumber() < 0.4 then
		candle(m, base * CFrame.new(size * 0.2, size * 0.25, 0), 2)
	end
end

-- Brasero : socle, colonne, vasque métallique, braises néon et vraies flammes.
-- Brasero : socle, colonne, vasque métallique, braises néon et vraies flammes. `flame` change la couleur du feu
-- (par défaut orange ; turquoise = flamme spectrale, violet = feu magique).
local function brazier(parent: Instance, localPos: Vector3, flame: Color3?)
	local color = flame or C.orange
	local k = kit(parent, "Brasero", CFrame.new(O + localPos))
	if k then
		local glow = glowOf(k, "NeonOrange")
		if glow then
			if flame then
				glow.Color = flame:Lerp(Color3.new(0, 0, 0), 0.12)
			end
			-- flamme et fumée animées (planches Blender) à la place de l'effet Fire de Roblox
			local flame = Instance.new("ParticleEmitter")
			flipbook(flame, "Flamme")
			flame.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.35))
			flame.LightEmission = 1
			flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 1.4) })
			flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) })
			flame.Lifetime = NumberRange.new(0.5, 0.8)
			flame.Rate = 12
			flame.Speed = NumberRange.new(2, 3.5)
			flame.SpreadAngle = Vector2.new(8, 8)
			flame.Rotation = NumberRange.new(-8, 8)
			flame.Parent = glow
			local smoke = Instance.new("ParticleEmitter")
			flipbook(smoke, "Fumee")
			smoke.Color = ColorSequence.new(Color3.fromHex("#4A3E58"), Color3.fromHex("#2A2433"))
			smoke.LightEmission = 0
			smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			smoke.Lifetime = NumberRange.new(3, 4.5)
			smoke.Rate = 2.5
			smoke.Speed = NumberRange.new(2.5, 4)
			smoke.Acceleration = Vector3.new(0.6, 0.8, 0)
			smoke.SpreadAngle = Vector2.new(12, 12)
			smoke.Rotation = NumberRange.new(0, 360)
			smoke.RotSpeed = NumberRange.new(-25, 25)
			smoke.Parent = glow
			light(glow, 24, 1.8, color, T.flamme)
		end
		return
	end
	local base = CFrame.new(O + localPos)
	part(parent, Vector3.new(3.2, 1, 3.2), base * CFrame.new(0, 0.5, 0), C.trim, SLATE)
	part(parent, Vector3.new(1.5, 3.4, 1.5), base * CFrame.new(0, 2.7, 0), C.stone, SLATE)
	local bowl = part(parent, Vector3.new(4.2, 1.3, 4.2), base * CFrame.new(0, 4.9, 0), C.roof, METAL)
	part(parent, Vector3.new(3.4, 0.6, 3.4), base * CFrame.new(0, 5.6, 0), if flame then color else C.ember, NEON)
	local fire = Instance.new("Fire")
	fire.Color = color
	fire.SecondaryColor = if flame then color:Lerp(Color3.new(1, 1, 1), 0.4) else C.ember
	fire.Size = 5
	fire.Heat = 9
	fire.Parent = bowl
	light(bowl, 24, 2, color, T.flamme)
end

-- Modèles de la Toolbox ----------------------------------------------------------------------------------------

-- Recolore un modèle dans la palette de l'île : vitraux colorés -> néon doré, pierre claire -> pierre sombre,
-- toits -> ardoise, bois -> bois sombre, herbe -> mousse.
local function recolorGothic(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d:IsA("UnionOperation") then
				d.UsePartColor = true
			elseif d:IsA("MeshPart") then
				d.TextureID = "" -- sinon la texture d'origine (souvent claire) masque la nouvelle couleur
			end
			local _, sat, val = d.Color:ToHSV()
			local mat = d.Material
			if d.Transparency >= 0.95 then
				continue -- pièces invisibles (zones, collisions) : on n'y touche pas
			elseif d.Transparency > 0.1 or mat == Enum.Material.Glass then
				-- vitraux semi-transparents -> vitraux dorés lumineux
				local r = rng:NextNumber() -- vitraux multicolores : surtout or, quelques éclats violets et cramoisis
				d.Color = if r < 0.6 then C.window elseif r < 0.78 then C.orange elseif r < 0.92 then C.violet else C.crimson
				d.Material = NEON
				d.Transparency = 0.1
				d.CastShadow = false
			elseif (mat == Enum.Material.Plastic or mat == Enum.Material.SmoothPlastic) and sat > 0.4 then
				d.Color = C.banner -- tapis, tentures : tissu rouge sombre
				d.Material = FABRIC
			elseif mat == Enum.Material.Wood or mat == Enum.Material.WoodPlanks then
				d.Color = C.wood
			elseif mat == Enum.Material.Grass or mat == Enum.Material.LeafyGrass then
				d.Color = C.moss
				d.Material = MOSS
			elseif d:IsA("WedgePart") or sat > 0.2 then
				d.Color = C.roof
			else
				d.Color = if val > 0.75 then C.trim elseif val > 0.45 then C.stone else C.roof
				if mat == Enum.Material.Marble or mat == Enum.Material.Plastic or mat == Enum.Material.SmoothPlastic then
					d.Material = SLATE
				end
			end
		end
	end
end

-- Pose une copie d'un modèle de ServerStorage.AssetsMonstres : mis à l'échelle à `height` studs, posé au sol
-- sur `cf`, sa face avant (+Z du modèle) tournée vers -Z de `cf` (donc vers la place avec facingCentre).
-- Renvoie nil si le modèle n'existe pas (l'appelant construit alors sa version en blocs).
local function placeAsset(parent: Instance, name: string, cf: CFrame, height: number, recolor: ((Instance) -> ())?): Model?
	if not Config.useToolbox then
		return nil
	end
	local folder = ServerStorage:FindFirstChild("AssetsMonstres")
	local source = folder and folder:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return nil
	end
	local m = source:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy() -- sécurité : aucun script de la Toolbox n'entre dans la map
		elseif d:IsA("Light") then
			d:Destroy() -- les lumières des modèles dépasseraient le budget mobile (maxPointLights)
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * height / size.Y)
	local box, boxSize = m:GetBoundingBox()
	local pivotFromBox = box:ToObjectSpace(m:GetPivot())
	m:PivotTo(cf * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, boxSize.Y / 2, 0) * pivotFromBox)
	if recolor then
		recolor(m)
	end
	m.Parent = parent
	task.wait()
	return m
end

-- Décors du sol ------------------------------------------------------------------------------------------------

-- Gargouille sur piédestal, tournée vers -Z de `cf` (base au sol) : corps accroupi, tête cornue, yeux
-- incandescents, ailes repliées.
local function gargoyle(parent: Instance, cf: CFrame, scale: number?)
	local k = scale or 1
	local m = model(parent, "Gargouille")
	part(m, Vector3.new(3.6, 0.8, 3.6) * k, cf * CFrame.new(0, 0.4 * k, 0), C.trim, GRANITE)
	part(m, Vector3.new(2.8, 3, 2.8) * k, cf * CFrame.new(0, 2.3 * k, 0), C.stone, GRANITE)
	part(m, Vector3.new(3.4, 0.6, 3.4) * k, cf * CFrame.new(0, 4.1 * k, 0), C.trim, GRANITE)
	local body = cf * CFrame.new(0, 5.6 * k, 0.2 * k) * CFrame.Angles(math.rad(-15), 0, 0)
	part(m, Vector3.new(2.2, 2.6, 2) * k, body, C.rockDark, SLATE)
	local head = body * CFrame.new(0, 1.3 * k, -1.2 * k)
	part(m, Vector3.new(1.7, 1.5, 1.6) * k, head, C.rockDark, SLATE)
	part(m, Vector3.new(1, 0.6, 0.8) * k, head * CFrame.new(0, -0.4 * k, -1 * k), C.rockDark, SLATE) -- museau
	for _, sx in { -1, 1 } do
		part(m, Vector3.new(0.35, 0.3, 0.2) * k, head * CFrame.new(sx * 0.4 * k, 0.15 * k, -0.82 * k), C.crimson, NEON)
		part(m, Vector3.new(0.35, 1.3, 0.35) * k, head * CFrame.new(sx * 0.6 * k, 1 * k, 0.2 * k) * CFrame.Angles(math.rad(-25), 0, -sx * math.rad(20)), C.bone, GRANITE)
		part(m, Vector3.new(0.3, 2.6, 1.8) * k, body * CFrame.new(sx * 1.3 * k, 0.6 * k, 0.8 * k) * CFrame.Angles(math.rad(20), 0, sx * math.rad(15)), C.rockDark, SLATE) -- aile
		part(m, Vector3.new(0.7, 1.4, 0.8) * k, body * CFrame.new(sx * 0.8 * k, -1.2 * k, -0.6 * k), C.rockDark, SLATE) -- patte
	end
end

-- Petit cimetière dans un enclos en fer : pierres tombales, croix, monticules, bougies, arbre mort.
-- `cf` = centre au sol, l'enclos fait w × d.
local function graveyard(parent: Instance, cf: CFrame, w: number, d: number)
	local m = model(parent, "Cimetiere")
	part(m, Vector3.new(w, 0.3, d), cf * CFrame.new(0, 0.15, 0), C.rockDark, Enum.Material.Ground)
	for _, side in { { 0, -d / 2, w }, { 0, d / 2, w }, { -w / 2, 0, d }, { w / 2, 0, d } } do
		local a = cf * CFrame.new(side[1], 0, side[2]) * (if side[1] ~= 0 then CFrame.Angles(0, math.pi / 2, 0) else CFrame.new())
		local len = side[3]
		local gap = side[2] == d / 2 -- entrée côté +Z
		for _, h in { 1.1, 2.6 } do
			if gap then
				for _, sx in { -1, 1 } do
					part(m, Vector3.new(len / 2 - 2, 0.22, 0.22), a * CFrame.new(sx * (len / 4 + 1), h, 0), C.roof, METAL)
				end
			else
				part(m, Vector3.new(len, 0.22, 0.22), a * CFrame.new(0, h, 0), C.roof, METAL)
			end
		end
		for i = 0, math.floor(len / 2.5) do
			local x = -len / 2 + i * 2.5
			if not (gap and math.abs(x) < 2) then
				part(m, Vector3.new(0.22, 3.2, 0.22), a * CFrame.new(x, 1.6, 0), C.roof, METAL)
			end
		end
	end
	local rows, cols = math.max(1, math.floor(d / 5)), math.max(1, math.floor(w / 4))
	for r = 1, rows do
		for c = 1, cols do
			local x = (c - (cols + 1) / 2) * (w / cols)
			local z = (r - (rows + 1) / 2) * (d / rows) - 0.8
			local g = cf * CFrame.new(x + rng:NextNumber(-0.4, 0.4), 0, z) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8)))
			part(m, Vector3.new(1.8, 0.6, 3.2), g * CFrame.new(0, 0.5, 1.5), C.rockDark, Enum.Material.Ground) -- monticule
			if kit(m, "Tombe", g * CFrame.new(0, 0.2, 0), Vector3.one * 0.9) or voxel(m, "Decors", { "Tombe1", "Tombe2" }, g * CFrame.new(0, 0.2, 0), rng:NextNumber(2.4, 3.2)) then
				continue
			end
			if rng:NextNumber() < 0.35 then
				part(m, Vector3.new(0.6, 3.4, 0.6), g * CFrame.new(0, 1.7, 0), C.bone, GRANITE) -- croix
				part(m, Vector3.new(2, 0.55, 0.6), g * CFrame.new(0, 2.5, 0), C.bone, GRANITE)
			else
				part(m, Vector3.new(1.9, 2.4, 0.6), g * CFrame.new(0, 1.2, 0), if rng:NextNumber() < 0.5 then C.trim else C.bone, GRANITE)
				part(m, Vector3.new(1.9, 1.9, 0.6), g * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)), if rng:NextNumber() < 0.5 then C.trim else C.bone, GRANITE, { Shape = Enum.PartType.Cylinder })
			end
			if rng:NextNumber() < 0.3 then
				candle(m, g * CFrame.new(0.7, 0.8, 1), 0.9)
			end
		end
	end
	deadTree(m, (cf * CFrame.new(w / 2 - 2, 0, -d / 2 + 2)).Position - O, rng:NextNumber(10, 14))
end

-- Amas de cristaux magiques (verre translucide + cœur néon), légèrement inclinés.
local function crystals(parent: Instance, cf: CFrame, color: Color3, size: number)
	local v = voxel(parent, "Decors", { "Cristaux1", "Cristaux2" }, cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), size * 2.4)
	if v then
		local glow = part(v, Vector3.one, cf * CFrame.new(0, size * 1.2, 0), color, NEON, { Transparency = 1 })
		light(glow, 16, 1.4, color, T.flamme)
		return
	end
	local k = kit(parent, "Cristaux", cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Vector3.one * (size / 1.5))
	if k then
		local glow = glowOf(k, "NeonViolet")
		if glow then
			light(glow, 18, 1.6, glow.Color, T.flamme)
		end
		return
	end
	local m = model(parent, "Cristaux")
	part(m, Vector3.new(size * 1.6, size * 0.4, size * 1.4), cf * CFrame.new(0, size * 0.15, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C.rockDark, BASALT)
	for i = 1, 6 do
		local h = size * rng:NextNumber(1, 2.6)
		local w = size * rng:NextNumber(0.25, 0.45)
		local a = i / 6 * math.pi * 2
		local shard = cf * CFrame.new(math.cos(a) * size * 0.35, h / 2, math.sin(a) * size * 0.35) * CFrame.Angles(math.sin(a) * 0.35, rng:NextNumber(0, 3), -math.cos(a) * 0.35)
		part(m, Vector3.new(w, h, w), shard, color, Enum.Material.Glass, { Transparency = 0.25, CastShadow = false })
		part(m, Vector3.new(w * 0.4, h * 0.8, w * 0.4), shard, color, NEON)
	end
	local core = part(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, size, 0), color, NEON, { Transparency = 1 })
	light(core, 18, 2.2, color, T.flamme)
end

-- Ruines : colonnes brisées de hauteurs variées, une colonne tombée et des blocs épars.
local function ruins(parent: Instance, cf: CFrame)
	if kit(parent, "Ruines", cf) then
		return
	end
	local m = model(parent, "Ruines")
	for i = -1, 1 do
		local base = cf * CFrame.new(i * 5, 0, rng:NextNumber(-1, 1))
		local h = rng:NextNumber(3, 10)
		part(m, Vector3.new(3.2, 1, 3.2), base * CFrame.new(0, 0.5, 0), C.trim, GRANITE)
		part(m, Vector3.new(2.2, h, 2.2), base * CFrame.new(0, 1 + h / 2, 0), C.stone, GRANITE)
		part(m, Vector3.new(2.6, 1, 2.6), base * CFrame.new(0.3, 1.4 + h, 0) * CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), 0, math.rad(rng:NextNumber(-25, 25))), C.trim, GRANITE)
		if rng:NextNumber() < 0.5 then
			part(m, Vector3.new(h * 0.15, 0.4, 0.3), base * CFrame.new(0, 1 + h * 0.6, -1.15), C.moss, MOSS)
		end
	end
	part(m, Vector3.new(2.2, 8, 2.2), cf * CFrame.new(1, 1.1, 5) * CFrame.Angles(0, math.rad(70), math.rad(90)), C.stone, GRANITE) -- colonne tombée
	for _ = 1, 5 do
		local s = rng:NextNumber(0.8, 2)
		part(m, Vector3.new(s, s, s), cf * CFrame.new(rng:NextNumber(-7, 7), s / 2, rng:NextNumber(-4, 7)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), C.trim, GRANITE)
	end
end

-- Potence avec une cage suspendue à une chaîne.
local function cage(parent: Instance, cf: CFrame)
	if kit(parent, "Potence", cf) then
		-- la cage pend au bout de la potence (origine de l'asset = crochet) et se balance côté client
		local hook = cf * CFrame.new(6.3, 13, 0)
		local c = kit(parent, "CageSuspendue", hook)
		if c then
			c:SetAttribute("Crochet", hook)
			CollectionService:AddTag(c, T.balance)
			local glow = glowOf(c, "NeonCramoisi")
			if glow then
				light(glow, 16, 1.6, glow.Color, T.flamme)
			end
		end
		return
	end
	local m = model(parent, "Cage")
	part(m, Vector3.new(1.4, 14, 1.4), cf * CFrame.new(0, 7, 0), C.wood, WOOD)
	part(m, Vector3.new(7, 1, 1), cf * CFrame.new(3, 13.5, 0), C.wood, WOOD)
	part(m, Vector3.new(0.8, 4, 0.8), cf * CFrame.new(1.2, 11.6, 0) * CFrame.Angles(0, 0, math.rad(-40)), C.wood, WOOD) -- jambe de force
	local c = cf * CFrame.new(6, 7.5, 0)
	-- la cage et sa lanterne pendent du bout de la potence (le client les fait se balancer)
	m = model(m, "Suspendue")
	m:SetAttribute("Crochet", cf * CFrame.new(6, 13, 0))
	CollectionService:AddTag(m, T.balance)
	for i = 0, 3 do
		part(m, Vector3.new(0.25, 0.9, 0.5), cf * CFrame.new(6, 12.6 - i * 0.8, 0) * CFrame.Angles(0, (i % 2) * math.pi / 2, 0), C.roof, METAL)
	end
	part(m, Vector3.new(3.4, 0.3, 3.4), c * CFrame.new(0, -2.3, 0), C.roof, METAL)
	part(m, Vector3.new(3.4, 0.3, 3.4), c * CFrame.new(0, 2.3, 0), C.roof, METAL)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part(m, Vector3.new(0.2, 4.6, 0.2), c * CFrame.new(math.cos(a) * 1.6, 0, math.sin(a) * 1.6), C.roof, METAL)
	end
	part(m, Vector3.new(1, 1, 1), c * CFrame.new(0, -1.6, 0), C.bone, GRANITE, { Shape = Enum.PartType.Ball }) -- crâne
	local lantern = part(m, Vector3.new(0.6, 0.8, 0.6), c * CFrame.new(0.3, 3.6, 0), C.crimson, NEON) -- lanterne au-dessus
	light(lantern, 16, 2, C.crimson, T.flamme)
end

-- Butte rocheuse moussue posée sur le dallage (relief).
local function outcrop(parent: Instance, cf: CFrame, size: number)
	local m = model(parent, "Butte")
	for i = 1, 9 do
		local s = size * rng:NextNumber(0.35, 0.7)
		local h = s * rng:NextNumber(0.6, 1.4) * (1 - i / 14)
		local p = cf * CFrame.new(rng:NextNumber(-size / 2, size / 2), h / 2, rng:NextNumber(-size / 2, size / 2)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2))
		local color, material = rockStyle()
		part(m, Vector3.new(s, h, s), p, color, material)
		if rng:NextNumber() < 0.5 then
			part(m, Vector3.new(s * 0.8, 0.4, s * 0.8), p * CFrame.new(0, h / 2 + 0.15, 0), C.moss, MOSS)
		end
	end
	if rng:NextNumber() < 0.6 then
		part(m, Vector3.new(size * 0.4, 0.4, 0.3), cf * CFrame.new(0, size * 0.25, -size * 0.3), C.ember, NEON)
	end
end

-- Tonneaux et caisses empilés.
local function barrels(parent: Instance, cf: CFrame)
	if kit(parent, "Tonneaux", cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Vector3.one * 1.2) then
		return
	end
	local m = model(parent, "Tonneaux")
	for i = 1, 4 do
		local p = cf * CFrame.new(rng:NextNumber(-3, 3), 1.5, rng:NextNumber(-2, 2))
		if i % 2 == 0 then
			part(m, Vector3.new(2.6, 2.6, 2.6), p * CFrame.new(0, -0.2, 0) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), C.wood, WOOD)
		else
			local b = p * CFrame.Angles(0, 0, math.rad(90))
			part(m, Vector3.new(3, 2.4, 2.4), b, C.wood, WOOD, { Shape = Enum.PartType.Cylinder })
			for _, x in { -0.9, 0.9 } do
				part(m, Vector3.new(0.25, 2.55, 2.55), b * CFrame.new(x, 0, 0), C.roof, METAL, { Shape = Enum.PartType.Cylinder })
			end
		end
	end
end

-- Bâtiments ---------------------------------------------------------------------------------------------------

-- Tour carrée : corps en brique, contreforts d'angle à pinacles, fenêtres sur les 4 faces, liserés orange,
-- toit en gradins, flèche lumineuse. `cf` = centre au sol, face avant -Z.
-- Petits décors (pièces lisses, comme la végétation de la map des héros) ----------------------------------

local CAPS = { Color3.fromHex("#D8468E"), Color3.fromHex("#9257E0"), Color3.fromHex("#2FB8A6"), Color3.fromHex("#F07A3A") }

-- Champignons : pieds clairs, chapeaux colorés à pois lumineux ; `glow` ajoute une lueur colorée.
local function mushrooms(parent: Instance, base: CFrame, glow: boolean)
	local v = voxel(parent, "Plantes", { "Champignon1", "Champignon2", "Champignon3" }, base, rng:NextNumber(2.2, 4.2))
	if v then
		if glow then
			local core = part(v, Vector3.one, base * CFrame.new(0, 2, 0), C.violet, NEON, { Transparency = 1 })
			light(core, 14, 1.3, Color3.fromHex("#B48CFF"))
		end
		return
	end
	local m = model(parent, "Champignons")
	local cap = CAPS[rng:NextInteger(1, #CAPS)]
	for k = 1, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(0.8, 2.4) * (if k == 1 then 1.4 else 1)
		local r = h * rng:NextNumber(0.45, 0.6)
		local p = base * CFrame.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		part(m, Vector3.new(h, h * 0.28, h * 0.28), p * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromHex("#F2E6D2"), SMOOTH, { Shape = Enum.PartType.Cylinder })
		part(m, Vector3.new(r * 0.5, r * 2, r * 2), p * CFrame.new(0, h, 0) * CFrame.Angles(0, 0, math.rad(90)), cap, SMOOTH, { Shape = Enum.PartType.Cylinder })
		part(m, Vector3.new(r * 1.7, r * 1.7, r * 1.7), p * CFrame.new(0, h + r * 0.15, 0), cap, SMOOTH, { Shape = Enum.PartType.Ball })
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			part(m, Vector3.one * r * 0.32, p * CFrame.new(math.cos(a) * r * 0.55, h + r * 0.7, math.sin(a) * r * 0.55), Color3.fromHex("#FFF4C8"), NEON, { Shape = Enum.PartType.Ball })
		end
	end
	if glow then
		local core = part(m, Vector3.one, base * CFrame.new(0, 1.5, 0), cap, NEON, { Transparency = 1 })
		light(core, 14, 1.4, cap)
	end
end

-- Citrouille côtelée avec sa tige.
local function pumpkin(parent: Instance, base: CFrame, size: number)
	local lantern = rng:NextNumber() < 0.2
	local v = voxel(parent, "Plantes", if lantern then { "CitrouilleLanterne" } else { "Citrouille1", "Citrouille2" }, base, size * 1.1)
	if v then
		if lantern then
			local core = part(v, Vector3.one, base * CFrame.new(0, size * 0.5, 0), C.orange, NEON, { Transparency = 1 })
			light(core, 12, 1.3, C.orange)
		end
		return
	end
	local m = model(parent, "Citrouille")
	local orange = if rng:NextNumber() < 0.7 then Color3.fromHex("#F08A24") else Color3.fromHex("#E8C23A")
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		part(m, Vector3.new(size * 0.62, size * 0.82, size * 0.62), base * CFrame.Angles(0, a, 0) * CFrame.new(size * 0.22, size * 0.4, 0), orange, SMOOTH, { Shape = Enum.PartType.Ball })
	end
	part(m, Vector3.new(size * 0.35, size * 0.15, size * 0.15), base * CFrame.new(0, size * 0.85, 0) * CFrame.Angles(0, 0, math.rad(80)), Color3.fromHex("#4E7A2E"), SMOOTH, { Shape = Enum.PartType.Cylinder })
end

-- Buisson : boules de feuillage de deux tons.
local function bush(parent: Instance, base: CFrame, size: number)
	if voxel(parent, "Plantes", { "Buisson1", "Buisson2", "Buisson3" }, base, size * 0.9) then
		return
	end
	local m = model(parent, "Buisson")
	local tones = if rng:NextNumber() < 0.6 then { Color3.fromHex("#4E9A3A"), Color3.fromHex("#3C7C30") } else { Color3.fromHex("#7A4EB0"), Color3.fromHex("#5E3A90") }
	for k = 1, rng:NextInteger(3, 5) do
		local s = size * rng:NextNumber(0.6, 1)
		part(m, Vector3.one * s, base * CFrame.new(rng:NextNumber(-size, size) * 0.5, s * 0.4, rng:NextNumber(-size, size) * 0.5), tones[1 + k % 2], SMOOTH, { Shape = Enum.PartType.Ball })
	end
end

-- Touffe d'herbe : quelques brins inclinés.
local function tuft(parent: Instance, base: CFrame)
	if voxel(parent, "Plantes", { "Herbe1", "Herbe2" }, base, rng:NextNumber(1.2, 2)) then
		return
	end
	local m = model(parent, "Herbe")
	for k = 1, 5 do
		local h = rng:NextNumber(0.8, 1.6)
		part(m, Vector3.new(0.18, h, 0.35), base * CFrame.Angles(0, k / 5 * math.pi * 2, 0) * CFrame.new(0.2, h / 2 - 0.1, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(10, 30))), Color3.fromHex("#6CBA48"), SMOOTH)
	end
end

-- Sème des décors sur le sol libre : ni sur la place, le chemin, les allées, l'avenue ni dans les parcelles.
local function scatterDecor(parent: Instance, avenueDeg: number)
	local m = model(parent, "Decors")
	local P = Config.plots
	local frames = {}
	for k = 0, P.count - 1 do
		local a = math.rad(k * P.angleStep)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local c = d * (P.inner + P.outer) / 2
		table.insert(frames, CFrame.lookAt(c, c + d))
	end
	local function free(p: Vector3): boolean
		local r = p.Magnitude
		if r < D.plazaRadius + 3 or (r > D.ringRoad[1] - 2 and r < D.ringRoad[2] + 3) or r > D.islandRadius - 9 then
			return false
		end
		for _, f in frames do
			local l = f:PointToObjectSpace(p)
			if math.abs(l.X) < P.size / 2 + 3 and math.abs(l.Z) < P.size / 2 + 3 then
				return false
			end
		end
		local deg = math.deg(math.atan2(p.Z, p.X))
		for j = 0, P.count - 1 do
			if r < P.inner + 2 and math.abs(((deg - j * P.angleStep + 180) % 360) - 180) * math.pi / 180 * r < 9 then
				return false -- allée
			end
		end
		return math.abs(((deg - avenueDeg + 180) % 360) - 180) * math.pi / 180 * r > 13
	end
	local placed, glowing = 0, 0
	for _ = 1, 900 do
		if placed >= 170 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(D.plazaRadius + 3, D.islandRadius - 9)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if free(p) then
			placed += 1
			local base = CFrame.new(O + p + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local roll = rng:NextNumber()
			if roll < 0.05 and voxel(m, "Arbres", { "ChampignonGeant1", "ChampignonGeant2" }, base, rng:NextNumber(7, 11)) then
				-- champignon géant
			elseif roll < 0.11 and voxel(m, "Arbres", { "ArbreHante1", "ArbreHante2", "ArbreMort2" }, base, rng:NextNumber(11, 16)) then
				-- grand arbre
			elseif roll < 0.36 then
				local glow = glowing < 10 and rng:NextNumber() < 0.3
				if glow then
					glowing += 1
				end
				mushrooms(m, base, glow)
			elseif roll < 0.5 then
				pumpkin(m, base, rng:NextNumber(1.4, 2.6))
			elseif roll < 0.72 then
				bush(m, base, rng:NextNumber(1.8, 3.4))
			else
				tuft(m, base)
			end
		end
	end
end

local function tower(parent: Instance, cf: CFrame, w: number, h: number, roofH: number, spire: number)
	if kit(parent, "Tour", cf * CFrame.Angles(0, math.pi, 0), Vector3.new(w / 10, h / 28, w / 10)) then
		return
	end
	local m = model(parent, "Tour")
	part(m, Vector3.new(w, h, w), cf * CFrame.new(0, h / 2, 0), C.brick, BRICK)
	part(m, Vector3.new(w + 3, 2.5, w + 3), cf * CFrame.new(0, 1.25, 0), C.stone, SLATE) -- soubassement
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local corner = cf * CFrame.new(sx * w / 2, 0, sz * w / 2)
			part(m, Vector3.new(3, h + 3, 3), corner * CFrame.new(0, (h + 3) / 2, 0), C.stone, SLATE)
			candle(m, steppedRoof(m, corner * CFrame.new(0, h + 3, 0), 3, 3, 4, 3), 3)
		end
	end
	for y = 10, h - 3, 10 do
		part(m, Vector3.new(w + 0.6, 0.6, w + 0.6), cf * CFrame.new(0, y, 0), C.orange, NEON, { Transparency = 0.15 })
	end
	local rows = math.max(1, math.floor((h - 8) / 10))
	for i = 0, 3 do
		local face = cf * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, h / 2 + 3, -w / 2)
		windows(m, face, w * 0.7, h - 12, 2, rows, w * 0.12, 4.5)
	end
	part(m, Vector3.new(w * 0.3, 8, 0.4), cf * CFrame.new(0, 6.5, -w / 2 - 0.15), C.orange, NEON) -- porte
	-- balcon crénelé à mi-hauteur sur les grandes tours
	if h >= 40 then
		local by = math.floor(h * 0.58)
		local hw = w / 2 + 2.5
		part(m, Vector3.new(w + 5, 1, w + 5), cf * CFrame.new(0, by, 0), C.trim, SLATE)
		local corners = {}
		for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			table.insert(corners, (cf * CFrame.new(c[1] * hw, by + 0.5, c[2] * hw)).Position - O)
		end
		for i = 1, 4 do
			battlement(m, corners[i], corners[i % 4 + 1], 1.4)
		end
	end
	local top = steppedRoof(m, cf * CFrame.new(0, h, 0), w + 1, w + 1, roofH, 6)
	part(m, Vector3.new(1.4, spire, 1.4), top * CFrame.new(0, spire / 2, 0), C.gold, NEON)
	local beacon = part(m, Vector3.new(2.2, 2.2, 2.2), top * CFrame.new(0, spire, 0), C.gold, NEON)
	light(beacon, 30)
	return m
end

-- Maison à pignon : murs en brique, toit à deux pans (WedgeParts), cheminée, fenêtres en grille.
local function house(parent: Instance, cf: CFrame, w: number, d: number, h: number)
	if kit(parent, "Maison", cf * CFrame.Angles(0, math.pi, 0), Vector3.new(w / 16, h / 10, d / 11)) then
		return
	end
	local m = model(parent, "Maison")
	part(m, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), C.brick, BRICK)
	part(m, Vector3.new(w + 2, 2, d + 2), cf * CFrame.new(0, 1, 0), C.stone, SLATE)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, Vector3.new(2, h, 2), cf * CFrame.new(sx * w / 2, h / 2, sz * d / 2), C.stone, SLATE)
		end
	end
	local roofH = d * 0.7
	local ridge = cf * CFrame.new(0, h, 0)
	-- pente avant (vers -Z) puis pente arrière (tournée de 180°)
	wedge(m, Vector3.new(w + 3, roofH, d / 2 + 1.5), ridge * CFrame.new(0, roofH / 2, -(d / 2 + 1.5) / 2), C.roof)
	wedge(m, Vector3.new(w + 3, roofH, d / 2 + 1.5), ridge * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, roofH / 2, -(d / 2 + 1.5) / 2), C.roof)
	part(m, Vector3.new(w + 3.4, 0.7, 1), ridge * CFrame.new(0, roofH + 0.2, 0), C.orange, NEON, { Transparency = 0.2 })
	part(m, Vector3.new(3.5, roofH + 4, 3.5), ridge * CFrame.new(w * 0.3, (roofH + 4) / 2, d * 0.15), C.stone, BRICK)
	for _, sx in { -1, 1 } do
		candle(m, ridge * CFrame.new(sx * (w / 2 + 1), roofH * 0.15, 0), 3)
	end
	for _, rot in { 0, math.pi } do
		windows(m, cf * CFrame.Angles(0, rot, 0) * CFrame.new(0, h / 2 + 0.5, -d / 2), w * 0.75, h * 0.6, 3, 2, 3, 3.6)
	end
	for _, rot in { math.pi / 2, -math.pi / 2 } do
		windows(m, cf * CFrame.Angles(0, rot, 0) * CFrame.new(0, h / 2 + 0.5, -w / 2), d * 0.5, h * 0.6, 2, 2, 2.4, 3.6)
	end
	local door = part(m, Vector3.new(4, 7, 0.4), cf * CFrame.new(0, 5.5, -d / 2 - 0.15), C.orange, NEON)
	light(door, 22, 1.4)
	return m
end

-- Cathédrale (tour principale, nettement plus haute que tout le reste) : 3 étages en retrait, rosace dorée,
-- grandes fenêtres en ogive, contreforts à pinacles, bannières, perron, flèche lumineuse.
local function cathedral(parent: Instance, cf: CFrame)
	local m = model(parent, "Cathedrale")
	local tiers = {
		{ w = 62, d = 42, h = 52 },
		{ w = 46, d = 34, h = 44 },
		{ w = 28, d = 24, h = 38 },
	}
	local y = 0
	for i, t in tiers do
		local base = cf * CFrame.new(0, y, 0)
		part(m, Vector3.new(t.w, t.h, t.d), base * CFrame.new(0, t.h / 2, 0), C.brick, BRICK)
		part(m, Vector3.new(t.w + 1, 1.2, t.d + 1), base * CFrame.new(0, t.h - 0.6, 0), C.orange, NEON, { Transparency = 0.2 })
		wedge(m, Vector3.new(t.w * 0.6, t.h * 0.35, 4), base * CFrame.new(0, t.h + t.h * 0.175, -t.d / 2 + 2), C.roof)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = base * CFrame.new(sx * t.w / 2, 0, sz * t.d / 2)
				part(m, Vector3.new(4, t.h + 5, 4), corner * CFrame.new(0, (t.h + 5) / 2, 0), C.stone, SLATE)
				candle(m, steppedRoof(m, corner * CFrame.new(0, t.h + 5, 0), 4, 4, 6, 3), 4.5)
			end
		end
		for _, sx in { -0.25, 0.25 } do
			local p = base * CFrame.new(sx * t.w, t.h, -t.d / 2 + 1)
			part(m, Vector3.new(2, 5, 2), p * CFrame.new(0, 2.5, 0), C.stone, SLATE)
			candle(m, p * CFrame.new(0, 5, 0), 3)
		end
		for _, rot in { math.pi / 2, -math.pi / 2 } do
			windows(m, base * CFrame.Angles(0, rot, 0) * CFrame.new(0, t.h / 2, -t.w / 2), t.d * 0.7, t.h * 0.55, 3, 1, 2.4, t.h * 0.4)
		end
		windows(m, base * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, t.h / 2, -t.d / 2), t.w * 0.6, t.h * 0.5, 3, 1, 2.4, t.h * 0.35)
		if i == 1 then
			-- grandes fenêtres en ogive, porte lumineuse, bannières
			windows(m, base * CFrame.new(0, 22, -t.d / 2), 38, 1, 2, 1, 5, 24)
			part(m, Vector3.new(14, 20, 1), base * CFrame.new(0, 10, -t.d / 2 - 0.3), C.stone, SLATE)
			local door = part(m, Vector3.new(10, 16, 0.5), base * CFrame.new(0, 8, -t.d / 2 - 0.85), C.orange, NEON)
			-- portail en ogive devant la porte, pilastres et frise de façade
			archGate(m, base * CFrame.new(0, 0, -t.d / 2 - 2.5), 15, 18)
			for _, px in { -0.36, -0.12, 0.12, 0.36 } do
				local pil = base * CFrame.new(px * t.w + (if px > 0 then 2 else -2), 0, -t.d / 2 - 0.8)
				if math.abs(px) > 0.2 then
					part(m, Vector3.new(2.4, t.h - 4, 1.6), pil * CFrame.new(0, (t.h - 4) / 2, 0), C.stone, SLATE)
					candle(m, pil * CFrame.new(0, t.h - 4, 0), 2.4)
				end
			end
			for k = -5, 5 do
				part(m, Vector3.new(2, 2, 0.8), base * CFrame.new(k * 5, t.h - 4, -t.d / 2 - 0.5), if k % 2 == 0 then C.trim else C.stone, SLATE)
			end
			light(door, 28, 2)
			for _, sx in { -1, 1 } do
				banner(m, base * CFrame.new(sx * 23, 28, -t.d / 2 - 0.4), 6, 16)
			end
		elseif i == 2 then
			-- rosace dorée
			local rose = base * CFrame.new(0, t.h * 0.55, -t.d / 2 - 0.3)
			local axis = CFrame.Angles(0, math.rad(90), 0) -- axe du cylindre (X) vers l'avant
			part(m, Vector3.new(0.8, 27, 27), rose * axis, C.stone, SLATE, { Shape = Enum.PartType.Cylinder })
			local glow = part(m, Vector3.new(0.9, 22, 22), rose * CFrame.new(0, 0, -0.1) * axis, C.gold, NEON, { Shape = Enum.PartType.Cylinder })
			part(m, Vector3.new(1, 8, 8), rose * CFrame.new(0, 0, -0.2) * axis, C.roof, SLATE, { Shape = Enum.PartType.Cylinder })
			for k = 0, 7 do
				part(m, Vector3.new(0.9, 21, 1), rose * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, 0, k * math.pi / 8), C.roof, SLATE)
			end
			part(m, Vector3.new(4, 4, 1.1), rose * CFrame.new(0, 0, -0.3), C.gold, NEON)
			light(glow, 34, 2)
			windows(m, base * CFrame.new(0, t.h * 0.2, -t.d / 2), 26, 1, 2, 1, 3, 9)
		else
			windows(m, base * CFrame.new(0, t.h * 0.5, -t.d / 2), 12, 1, 2, 1, 2.6, 11)
		end
		y += t.h
	end
	-- rangées de pinacles sur les bords des toits des deux premiers étages
	local ty = 0
	for i = 1, 2 do
		local t = tiers[i]
		ty += t.h
		for _, sx in { -1, 1 } do
			for z = -t.d / 2 + 6, t.d / 2 - 6, 7 do
				local p = cf * CFrame.new(sx * (t.w / 2 - 1.2), ty, z)
				part(m, Vector3.new(1.4, 3, 1.4), p * CFrame.new(0, 1.5, 0), C.stone, SLATE)
				candle(m, p * CFrame.new(0, 3, 0), 1.8)
			end
		end
	end
	-- deux hautes tours de flanc reliées à la nef par des arcs-boutants
	for _, sx in { -1, 1 } do
		local tcf = cf * CFrame.new(sx * (tiers[1].w / 2 + 9), 0, 6)
		tower(m, tcf, 12, 70, 16, 16)
		for _, h in { 24, 44 } do
			local a = cf * CFrame.new(sx * tiers[1].w / 2, h, 6)
			local b = tcf * CFrame.new(-sx * 6, h + 6, 0)
			local mid = a.Position:Lerp(b.Position, 0.5)
			local len = (b.Position - a.Position).Magnitude
			part(m, Vector3.new(2, 2.4, len), CFrame.lookAt(mid, b.Position), C.stone, SLATE)
		end
	end
	local top = steppedRoof(m, cf * CFrame.new(0, y, 0), 28, 24, 30, 9)
	part(m, Vector3.new(3, 56, 3), top * CFrame.new(0, 28, 0), C.gold, NEON)
	part(m, Vector3.new(5, 1, 5), top * CFrame.new(0, 0.5, 0), C.orange, NEON)
	-- perron : trois marches basses devant la porte (la plus haute contre la façade)
	for s = 1, 3 do
		part(m, Vector3.new(36 - s * 3, 0.6 * s, 3), cf * CFrame.new(0, PLAZA_TOP + 0.3 * s, -21 - (4 - s) * 3 + 1.5), C.stone, COBBLE)
	end
	return m
end

-- Plateforme principale ----------------------------------------------------------------------------------------

-- Sol dans le style de la map des héros : beaucoup de petites pièces SmoothPlastic de teintes voisines
-- (bordures irrégulières, pierres plates éparses, grandes taches de couleur) plutôt que de grandes surfaces texturées.
local CURB = { Color3.fromHex("#4E4858"), Color3.fromHex("#5A5466"), Color3.fromHex("#665F72"), Color3.fromHex("#433E4C") }
local WARM = { Color3.fromHex("#9A8262"), Color3.fromHex("#86704F"), Color3.fromHex("#A48C6C"), Color3.fromHex("#7A6446") }
local FIELD = { Color3.fromHex("#4B4553"), Color3.fromHex("#3F3A47"), Color3.fromHex("#524B5C"), Color3.fromHex("#443F4E") }
local MOSSES = { Color3.fromHex("#4A5A3A"), Color3.fromHex("#556640"), Color3.fromHex("#3F4E33") }

local function pick(list: { Color3 }): Color3
	return list[rng:NextInteger(1, #list)]
end

-- Bordure en petits blocs irréguliers posés bout à bout de `a` à `b` (points monde, base au sol).
local function curbLine(parent: Instance, a: Vector3, b: Vector3, hMin: number, hMax: number)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(a, b)
	local z = 0
	while z < len - 0.3 do
		local l = math.min(rng:NextNumber(1.1, 1.8), len - z)
		local h = rng:NextNumber(hMin, hMax)
		part(parent, Vector3.new(1.1, h, l - 0.08), cf * CFrame.new(0, h / 2, -(z + l / 2)), pick(CURB), SMOOTH)
		z += l
	end
end

-- Pierre plate posée sur une surface dont le dessus est à `top` (CFrame `at` à plat, hauteur ignorée).
local function flatStone(parent: Instance, at: Vector3, top: number, palette: { Color3 })
	local cf = CFrame.new(at.X, O.Y + top + LAYER - 0.05, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	part(parent, Vector3.new(rng:NextNumber(1.2, 3), 0.1, rng:NextNumber(1, 2.4)), cf, pick(palette), SMOOTH)
end

-- Grande tache de couleur irrégulière (2 ou 3 rectangles qui se chevauchent, même teinte).
local function patch(parent: Instance, at: Vector3, top: number, size: number, color: Color3)
	for _ = 1, rng:NextInteger(2, 3) do
		local off = Vector3.new(rng:NextNumber(-size, size) * 0.3, 0, rng:NextNumber(-size, size) * 0.3)
		local cf = CFrame.new(at.X + off.X, O.Y + top + LAYER - 0.05, at.Z + off.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		part(parent, Vector3.new(size * rng:NextNumber(0.6, 1), 0.1, size * rng:NextNumber(0.4, 0.8)), cf, color, SMOOTH)
	end
end

-- Place centrale : dallage chaud, anneaux dorés, étoile centrale, obélisques et lampadaires.
local function plaza(parent: Instance, cathedralZone: (Vector3) -> boolean)
	local m = model(parent, "Place")
	local R = D.plazaRadius
	local top0 = PLAZA_TOP
	-- place du kit (dessus des dalles à top0 + LAYER), sinon disque, anneaux et rosace en pièces
	if not kit(m, "Place", CFrame.new(O + Vector3.new(0, top0 + LAYER, 0))) then
		disc(m, R, 1, top0, C.plaza, COBBLE)
		for k = 0, 23 do
			local a = k / 24 * math.pi * 2
			local mid = (R + 12) / 2
			part(m, Vector3.new(0.5, LAYER, R - 12), CFrame.new(O + Vector3.new(math.cos(a) * mid, top0 + LAYER / 2, math.sin(a) * mid)) * CFrame.Angles(0, -a + math.pi / 2, 0), C.plazaInner, SLATE)
		end
		-- anneaux lumineux : néon puis dallage par-dessus, un peu plus petit, chaque couche LAYER plus haut
		local top = top0 + LAYER * 2
		for i, r in D.rings do
			disc(m, r, 0.3, top, if i == 2 then C.violet else C.gold, NEON) -- anneau du milieu violet
			disc(m, r - 2.2, 0.3, top + LAYER, if i == #D.rings then C.stone else C.plazaInner, COBBLE)
			top += LAYER * 2
		end
		-- pierres plates éparses sur le pourtour de la place
		for _ = 1, 140 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(D.rings[1] + 3, R - 2.5)
			flatStone(m, O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), top0 + LAYER, WARM)
		end
		disc(m, 4.5, 0.3, top, C.violet, NEON)
		disc(m, 2.5, 0.3, top + LAYER, C.roof, SLATE)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			part(m, Vector3.new(0.8, 0.2, 6), CFrame.new(O + Vector3.new(math.cos(a) * 8, top - LAYER, math.sin(a) * 8)) * CFrame.Angles(0, -a + math.pi / 2, 0), C.gold, NEON)
		end
	end
	for k = 0, 15 do
		local a = (k + 0.5) / 16 * math.pi * 2
		local r = (D.rings[1] + D.rings[2]) / 2
		local p = Vector3.new(math.cos(a) * r, top0, math.sin(a) * r)
		if not cathedralZone(p) then
			pier(m, facingCentre(p), rng:NextNumber(3.8, 5), 1.2)
		end
	end
	for k = 0, 11 do
		local a = (k + 0.5) / 12 * math.pi * 2
		local p = Vector3.new(math.cos(a) * (R - 6), top0, math.sin(a) * (R - 6))
		if not cathedralZone(p) then
			lamp(m, p, k % 3 == 0)
		end
	end
end

-- Dallage de l'île : grand disque sombre, chemin circulaire, allées vers les parcelles, muret au bord,
-- veines incandescentes sur la tranche, rochers et arbres morts.
-- Sol en modules du kit : dalles de 16 × 16 (hors place et parcelles), arcs du chemin circulaire, allées.
-- Renvoie false si le kit n'est pas importé.
local function kitGround(m: Instance): boolean
	if not (hasKit() and Kit.assets.DalleA) then
		return false
	end
	local R = D.islandRadius
	local P = Config.plots
	local plotFrames = {}
	for k = 0, P.count - 1 do
		local a = math.rad(k * P.angleStep)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local c = d * (P.inner + P.outer) / 2
		table.insert(plotFrames, CFrame.lookAt(c, c + d))
	end
	local function underPlot(corners: { Vector3 }): boolean
		for _, f in plotFrames do
			local inside = true
			for _, p in corners do
				local l = f:PointToObjectSpace(p)
				if math.abs(l.X) > P.size / 2 or math.abs(l.Z) > P.size / 2 then
					inside = false
					break
				end
			end
			if inside then
				return true
			end
		end
		return false
	end
	local tiles = { "DalleA", "DalleB", "DalleC" }
	local n = math.ceil(R / 16)
	for i = -n, n - 1 do
		for j = -n, n - 1 do
			local corners = {}
			local far, near = 0, math.huge
			for _, c in { { 0, 0 }, { 16, 0 }, { 0, 16 }, { 16, 16 } } do
				local p = Vector3.new(i * 16 + c[1], 0, j * 16 + c[2])
				table.insert(corners, p)
				far = math.max(far, p.Magnitude)
				near = math.min(near, p.Magnitude)
			end
			if far <= R - 6 and far > D.plazaRadius - 1 and not underPlot(corners) then
				local centre = Vector3.new(i * 16 + 8, 0.45, j * 16 + 8)
				kit(m, tiles[rng:NextInteger(1, #tiles)], CFrame.new(O + centre) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0))
			end
		end
	end
	-- chemin circulaire : 18 arcs de 20°, bordure ouverte face aux allées (tous les 40°) et à l'avenue
	local avenueDeg = 270
	for _, spec in Config.islets do
		if spec.kind == "cathedrale" then
			avenueDeg = spec.angle - 90
		end
	end
	for k = 0, 17 do
		local deg = k * 20
		local open = deg % P.angleStep == 0 or math.abs(((deg - avenueDeg + 180) % 360) - 180) < 1
		kit(m, if open then "AnneauPassage" else "AnneauPlein", CFrame.new(O + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, -math.rad(deg), 0))
	end
	-- allées : 3 modules de 12 studs entre la place et chaque parcelle
	local len = P.inner - D.plazaRadius + 2
	for k = 0, P.count - 1 do
		local a = math.rad(k * P.angleStep)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = d * (D.plazaRadius + len / 2 - 1) + Vector3.new(0, 0.85, 0)
		local cf = CFrame.lookAt(O + mid, O + mid + d)
		for z = -1, 1 do
			kit(m, "Allee", cf * CFrame.new(0, 0, z * len / 3), Vector3.new(1, 1, len / 36))
		end
	end
	return true
end

local function ground(parent: Instance)
	local m = model(parent, "Sol")
	local R = D.islandRadius
	disc(m, R, 6, 0, C.stone, SLATE)
	disc(m, R - 4, 0.4, LAYER * 1.5, C.trim, COBBLE) -- bande du bord
	disc(m, R - 7, 0.4, LAYER * 3, C.stone, SLATE)
	local useKit = kitGround(m)
	if not useKit then
		disc(m, D.ringRoad[2], 0.4, LAYER * 4.5, C.plazaInner, COBBLE) -- chemin circulaire, pavé chaud comme les routes des héros
		disc(m, D.ringRoad[1], 0.4, LAYER * 6, C.stone, SLATE)
	end
	local P = Config.plots
	if not useKit then
		-- allées de la place vers chaque parcelle, bordées de néon
		for k = 0, P.count - 1 do
			local a = math.rad(k * P.angleStep)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local len = P.inner - D.plazaRadius + 2
			local mid = d * (D.plazaRadius + len / 2 - 1) + Vector3.new(0, LAYER * 7.5 - 0.15, 0) -- au-dessus du chemin circulaire
			local cf = CFrame.lookAt(O + mid, O + mid + d)
			part(m, Vector3.new(10, 0.3, len), cf, C.plazaInner, COBBLE)
			for _, sx in { -1, 1 } do
				part(m, Vector3.new(0.5, 0.3, len), cf * CFrame.new(sx * 5.2, LAYER, 0), C.gold, NEON)
				local a0 = (cf * CFrame.new(sx * 6.1, 0, len / 2 - 1)).Position
				local a1 = (cf * CFrame.new(sx * 6.1, 0, -len / 2 + 1)).Position
				curbLine(m, Vector3.new(a0.X, O.Y + LAYER * 3, a0.Z), Vector3.new(a1.X, O.Y + LAYER * 3, a1.Z), 0.9, 1.05)
			end
			for _ = 1, 22 do
				flatStone(m, (cf * CFrame.new(rng:NextNumber(-3.2, 3.2), 0, rng:NextNumber(-len / 2, len / 2))).Position, LAYER * 7.5, WARM)
			end
		end
		-- chemin circulaire : pierres éparses et bordure extérieure, coupée aux allées et à l'avenue
		for _ = 1, 170 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(D.ringRoad[1] + 1.2, D.ringRoad[2] - 1.2)
			flatStone(m, O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), LAYER * 4.5, WARM)
		end
		local segs = 140
		local rc = D.ringRoad[2] + 0.6
		for k = 0, segs - 1 do
			local a1, a2 = k / segs * math.pi * 2, (k + 1) / segs * math.pi * 2
			local mid = math.deg((a1 + a2) / 2)
			local open = false
			for j = 0, P.count - 1 do
				if math.abs(((mid - j * P.angleStep + 180) % 360) - 180) < 5 then
					open = true
				end
			end
			for _, spec in Config.islets do
				if spec.kind == "cathedrale" and math.abs(((mid - (spec.angle - 90) + 180) % 360) - 180) < 7 then
					open = true -- avenue de la Tour
				end
			end
			if not open then
				curbLine(m, O + Vector3.new(math.cos(a1) * rc, LAYER * 3, math.sin(a1) * rc), O + Vector3.new(math.cos(a2) * rc, LAYER * 3, math.sin(a2) * rc), 0.6, 0.75)
			end
		end
		-- grandes taches de couleur sur le dallage (comme les taches d'herbe de la map des héros) ; jamais sous une
		-- allée ni au bord du chemin circulaire, pour ne pas finir presque au même niveau qu'eux (scintillement)
		local paths = {}
		for j = 0, P.count - 1 do
			table.insert(paths, { j * P.angleStep, 6 })
		end
		for _, spec in Config.islets do
			if spec.kind == "cathedrale" then
				table.insert(paths, { spec.angle - 90, 10 }) -- avenue de la Tour
			end
		end
		local function nearAlley(a: number, r: number, size: number): boolean
			for _, path in paths do
				local gap = math.abs(((math.deg(a) - path[1] + 180) % 360) - 180)
				if math.rad(gap) * r < path[2] + size then
					return true
				end
			end
			return false
		end
		for _ = 1, 120 do
			local a = rng:NextNumber(0, math.pi * 2)
			local size = rng:NextNumber(6, 15)
			local r = rng:NextNumber(D.ringRoad[2] + size, R - 8)
			if not nearAlley(a, r, size) then
				patch(m, O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), LAYER * 3, size, if rng:NextNumber() < 0.3 then pick(MOSSES) else pick(FIELD))
			end
		end
		for _ = 1, 30 do
			local a = rng:NextNumber(0, math.pi * 2)
			local size = rng:NextNumber(3, 6)
			local r = rng:NextNumber(D.plazaRadius + size, D.ringRoad[1] - size)
			if not nearAlley(a, r, size) then
				patch(m, O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), LAYER * 6, size, pick(FIELD))
			end
		end
		for _ = 1, 90 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(D.plazaRadius + 2, D.ringRoad[1] - 2)
			if not nearAlley(a, r, 1.5) then
				flatStone(m, O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), LAYER * 6, CURB)
			end
		end
	end
	-- muret au bord, ouvert aux ponts
	local gaps = {}
	for _, islet in Config.islets do
		table.insert(gaps, { islet.angle, if islet.kind == "cathedrale" then 6 else 3 })
	end
	local count = 90
	for k = 0, count - 1 do
		local deg = k / count * 360 - 180
		local deg2 = (k + 1) / count * 360 - 180
		local open = false
		for _, g in gaps do
			if math.abs((((deg + deg2) / 2 - g[1] + 180) % 360) - 180) < g[2] then
				open = true
			end
		end
		if not open then
			battlement(m, dir(deg) * (R - 1.5), dir(deg2) * (R - 1.5), 3)
			if k % 3 == 0 then
				local p = dir(deg) * (R - 1.5)
				if useKit then
					pier(m, facingCentre(p), 6.8, 2.6)
				else
					part(m, Vector3.new(3, 6.5, 3), CFrame.new(O + p + Vector3.new(0, 3.25, 0)), C.stone, SLATE)
					candle(m, CFrame.new(O + p + Vector3.new(0, 6.5, 0)), 2.2)
				end
			end
		end
	end
	-- veines incandescentes sur la tranche du disque
	for _ = 1, if useKit then 25 else 70 do
		local deg = rng:NextNumber(-180, 180)
		local p = dir(deg) * (R + 0.05) + Vector3.new(0, rng:NextNumber(-5, -1), 0)
		local cf = CFrame.lookAt(O + p, O + p + dir(deg))
		part(m, Vector3.new(rng:NextNumber(2, 7), rng:NextNumber(0.4, 1.2), 0.3), cf, veinColor(), NEON)
	end
	if not useKit then
		-- gravats épars (rochers lisses, comme les rochers de la map des héros)
		for _ = 1, 45 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(D.ringRoad[2] + 2, R - 6)
			local g = rng:NextNumber(0.6, 1.6)
			part(m, Vector3.new(g, g, g), CFrame.new(O + Vector3.new(math.cos(a) * r, LAYER * 3 + g / 2 - 0.1, math.sin(a) * r)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), pick(CURB), SMOOTH)
		end
	end
	-- rochers et arbres morts entre les parcelles
	for k = 0, P.count - 1 do
		local a = math.rad(k * P.angleStep + P.angleStep / 2)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		for _ = 1, 4 do
			local s = rng:NextNumber(2.5, 5)
			local p = d * rng:NextNumber(P.inner, R - 8) + side(d) * rng:NextNumber(-4, 4)
			local names = { "Rocher1", "Rocher2", "Rocher3" }
			local at = CFrame.new(O + p + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			if not kit(m, names[rng:NextInteger(1, 3)], at, Vector3.one * (s / 5)) and not voxel(m, "Rochers", names, at, s * 0.8) then
				part(m, Vector3.new(s, s, s), CFrame.new(O + p + Vector3.new(0, s / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), pick({ C.rockDark, C.rock, C.trim }), SMOOTH)
			end
		end
	end
end

-- Parcelles des bases : dalle sombre bordée d'un liseré doré, ouverte côté place, poteaux à bougie aux coins.
local function plots(parent: Instance)
	local m = model(parent, "Parcelles")
	local P = Config.plots
	local s = P.size
	for k = 0, P.count - 1 do
		local a = math.rad(k * P.angleStep)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local centre = d * (P.inner + P.outer) / 2 + Vector3.new(0, 0.4, 0)
		local cf = CFrame.lookAt(O + centre, O + centre + d) -- -Z vers l'extérieur, +Z vers la place
		if kit(m, "Parcelle", cf * CFrame.new(0, 0.4, 0)) then
			-- repère invisible au nom de la parcelle (les futurs systèmes de base s'y accrochent)
			part(m, Vector3.new(s, 0.4, s), cf, C.trim, SLATE, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }).Name = `Parcelle{k + 1}`
			-- lueur douce sur l'emblème : la parcelle se détache du sol
			local glow = part(m, Vector3.one, cf * CFrame.new(0, 2.5, 0), C.violet, NEON, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
			light(glow, 26, 1.2, Color3.fromHex("#7FE6D2"))
		else
			local slab = part(m, Vector3.new(s, 0.4, s), cf, C.trim, COBBLE)
			slab.Name = `Parcelle{k + 1}`
			-- cadre intérieur plus sombre + emblème doré au centre
			part(m, Vector3.new(s - 8, 0.2, s - 8), cf * CFrame.new(0, 0.2, 0), C.stone, SLATE)
			part(m, Vector3.new(s - 11, 0.2, s - 11), cf * CFrame.new(0, 0.3, 0), C.trim, COBBLE)
			-- pierres plates éparses (pas sur l'emblème central, qui est au même niveau)
			for _ = 1, 26 do
				local x, z = rng:NextNumber(-(s - 14) / 2, (s - 14) / 2), rng:NextNumber(-(s - 14) / 2, (s - 14) / 2)
				if math.max(math.abs(x), math.abs(z)) > 6 then
					flatStone(m, (cf * CFrame.new(x, 0, z)).Position, 0.8, CURB)
				end
			end
			part(m, Vector3.new(5, 0.2, 5), cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.rad(45), 0), C.violet, NEON)
			part(m, Vector3.new(3.2, 0.2, 3.2), cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(45), 0), C.roof, SLATE)
			part(m, Vector3.new(s, 0.15, 0.6), cf * CFrame.new(0, 0.25, -s / 2), C.gold, NEON)
		end
		for _, sx in { -1, 1 } do
			if not hasKit() then -- liseré déjà dans la dalle du kit
				part(m, Vector3.new(0.6, 0.15, s), cf * CFrame.new(sx * s / 2, 0.25, 0), C.gold, NEON)
				-- côté place : ouverture de 12 studs au milieu
				part(m, Vector3.new((s - 12) / 2, 0.15, 0.6), cf * CFrame.new(sx * (s + 12) / 4, 0.25, s / 2), C.gold, NEON)
			end
			for _, sz in { -1, 1 } do
				pier(m, cf * CFrame.new(sx * s / 2, 0, sz * s / 2), 5.6, 2)
			end
		end
		-- grille de cimetière sur les trois côtés fermés, de part et d'autre de l'entrée côté place
		local function fence(a: CFrame, len: number)
			railing(m, a * CFrame.new(0, 0.2, 0), len - 2, 2.8)
		end
		fence(cf * CFrame.new(0, 0, -s / 2), s)
		fence(cf * CFrame.new(-s / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), s)
		fence(cf * CFrame.new(s / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), s)
		for _, sx in { -1, 1 } do
			fence(cf * CFrame.new(sx * (s + 12) / 4, 0, s / 2), (s - 12) / 2)
		end
		archGate(m, cf * CFrame.new(0, 0, s / 2), 12, 10)
	end
end

-- Pont entre deux points locaux (sol), avec garde-corps et poteaux à bougies.
local function bridge(parent: Instance, a: Vector3, b: Vector3, width: number?)
	local m = model(parent, "Pont")
	local w = width or 9
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(O + mid, O + b)
	local n = math.max(1, math.floor(len / 12 + 0.5))
	if hasKit() then
		for k = 0, n - 1 do
			kit(m, "PontTravee", cf * CFrame.new(0, 0, -len / 2 + (k + 0.5) * len / n), Vector3.new(w / 9, 1, len / n / 12))
		end
		for _, z in { -len / 4, len / 4 } do
			part(m, Vector3.new(5, 9, 5), cf * CFrame.new(0, -7, z), C.rockDark, ROCK) -- piles de soutien
		end
		return
	end
	part(m, Vector3.new(w, 1, len), cf * CFrame.new(0, -0.5, 0), C.wood, WOOD)
	part(m, Vector3.new(w + 0.6, 2, len), cf * CFrame.new(0, -2, 0), C.stone, SLATE)
	for _, sx in { -1, 1 } do
		local x = sx * (w / 2 - 0.5)
		railing(m, cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), len - 3, 2.4)
		for _, z in { -len / 2 + 1, len / 2 - 1 } do
			pier(m, cf * CFrame.new(x, 0, z), 5.2, 1.8)
		end
	end
	for _, z in { -len / 4, len / 4 } do
		part(m, Vector3.new(5, 9, 5), cf * CFrame.new(0, -7, z), C.rockDark, ROCK) -- piles de soutien
	end
end

-- Îlot : socle rocheux, pavés du dessus, bâtiments selon le type, pont vers la plateforme principale.
local function islet(parent: Instance, rocks: Instance, effects: Instance, spec: Config.Islet, index: number)
	local m = model(parent, `Ilot{index}_{spec.kind}`)
	local d = dir(spec.angle)
	local c = d * spec.dist + Vector3.new(0, spec.y, 0)
	local r = spec.radius
	disc(m, r, 4, spec.y - 0.1, C.stone, SLATE, c - Vector3.new(0, spec.y, 0))
	local t = D.tile
	local tiles = { "DalleA", "DalleB", "DalleC" }
	local kitTiles = hasKit()
	if kitTiles then
		-- dalles du kit (16 × 16) entièrement dans l'îlot ; le bord reste le disque d'ardoise sous les remparts
		local n = math.ceil(r / 16)
		for i = -n, n - 1 do
			for j = -n, n - 1 do
				local far = 0
				for _, cc in { { 0, 0 }, { 16, 0 }, { 0, 16 }, { 16, 16 } } do
					far = math.max(far, Vector2.new(i * 16 + cc[1], j * 16 + cc[2]).Magnitude)
				end
				if far <= r - 2 then
					kit(m, tiles[rng:NextInteger(1, #tiles)], CFrame.new(O + c + Vector3.new(i * 16 + 8, 0.35, j * 16 + 8)) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0))
				end
			end
		end
	end
	for x = -r, r, t do
		for z = -r, r, t do
			local dd = math.sqrt(x * x + z * z)
			if dd < r - 1 and not kitTiles then
				local glow = dd > r - t and rng:NextNumber() < 0.07
				part(m, Vector3.new(t - 0.2, 1 + rng:NextNumber(0, 0.4), t - 0.2), CFrame.new(O + c + Vector3.new(x, -0.3, z)), if glow then C.ember else (if rng:NextNumber() < 0.5 then C.stone else C.trim), if glow then NEON else COBBLE)
			end
		end
	end
	local tips = rockBase(rocks, c, r + 3, r * 1.4, D.isletBlock)
	local L = D.lightColumnLength
	lightColumn(effects, tips[1] + Vector3.new(0, 3, 0), rng:NextNumber(L[1], L[2]))
	local cf = facingCentre(c + d * (r * 0.2))
	local perp = side(d)
	if spec.kind == "cathedrale" then
		-- la Tour des monstres : grande cathédrale gothique (modèle de la Toolbox recoloré), sinon version en blocs
		-- cathédrale du kit (modélisée à l'échelle 1/3, façade tournée vers la place), sinon modèle Toolbox
		local front = facingCentre(c + d * (r * 0.08))
		if not kit(m, "Cathedrale", facingCentre(c + d * (r * 0.12)) * CFrame.Angles(0, math.pi, 0), Vector3.one * 3)
			and not placeAsset(m, "Cathedrale", front, 175, recolorGothic)
		then
			cathedral(m, front)
		end
		-- projecteurs au pied de la façade, tournés vers le haut : or au centre, violet sur les côtés
		for i, sx in { -1, 0, 1 } do
			local base = c - d * (r * 0.6) + perp * (sx * 30) + Vector3.new(0, 0.6, 0)
			local target = c + perp * (sx * 20) + Vector3.new(0, 90, 0)
			spot(m, CFrame.lookAt(O + base, O + target), if i == 2 then C.window else C.violet, 120)
		end
		for _, sx in { -1, 1 } do
			brazier(m, c - d * (r * 0.78) + perp * (sx * 16), C.violet)
			local g = facingCentre(c - d * (r * 0.7) + perp * (sx * 26))
			if not placeAsset(m, "Gargouille", g, 11, recolorGothic) then
				gargoyle(m, g, 1.3)
			end
		end
	elseif spec.kind == "tour" then
		tower(m, cf, 18, 56, 18, 18)
		deadTree(m, c - d * (r * 0.1) + perp * (r * 0.6), 16)
		local cc = CFrame.new(O + c - d * (r * 0.35) - perp * (r * 0.5))
		if not placeAsset(m, "Cristaux", cc, 7) then
			crystals(m, cc, C.crystal, 2.5)
		end
	elseif spec.kind == "chapelle" then
		if not kit(m, "Chapelle", cf * CFrame.Angles(0, math.pi, 0), Vector3.one * 1.3) then
			tower(m, cf, 14, 34, 13, 12)
		end
		deadTree(m, c + perp * (r * 0.55), 13)
		graveyard(m, facingCentre(c - perp * (r * 0.45)) * CFrame.Angles(0, math.pi, 0), 10, 14)
	elseif spec.kind == "manoir" then
		-- manoir hanté (modèle de la Toolbox recoloré), sinon maison en blocs
		if not kit(m, "Manoir", cf * CFrame.Angles(0, math.pi, 0), Vector3.one * 1.3) and not placeAsset(m, "Manoir", cf, 34, recolorGothic) then
			house(m, cf, 30, 20, 18)
		end
		deadTree(m, c - perp * (r * 0.7), 15)
		barrels(m, CFrame.new(O + c - d * (r * 0.55) + perp * (r * 0.5)))
	elseif spec.kind == "maison" then
		house(m, cf * CFrame.new(-r * 0.25, 0, 0), 30, 20, 18)
		tower(m, cf * CFrame.new(r * 0.45, 0, r * 0.1), 10, 30, 12, 8)
		deadTree(m, c + d * (r * 0.5) + perp * (r * 0.55), 18)
		deadTree(m, c - perp * (r * 0.65), 13)
		barrels(m, CFrame.new(O + c - d * (r * 0.5) - perp * (r * 0.3)))
		graveyard(m, facingCentre(c + perp * (r * 0.5) - d * (r * 0.3)) * CFrame.Angles(0, math.pi, 0), 10, 12)
	elseif spec.kind == "porte" then
		-- îlot d'entrée : deux piliers à pinacles, une arche, des bannières et une petite tour
		local gate = facingCentre(c)
		local gatehouse = kit(m, "Porterie", gate * CFrame.new(0, 0, -r * 0.5) * CFrame.Angles(0, math.pi, 0), Vector3.one * 1.1)
		for _, sx in if gatehouse then {} else { -1, 1 } do
			local p = gate * CFrame.new(sx * 7.5, 0, -r * 0.5)
			part(m, Vector3.new(4, 16, 4), p * CFrame.new(0, 8, 0), C.stone, SLATE)
			candle(m, steppedRoof(m, p * CFrame.new(0, 16, 0), 4, 4, 5, 3), 4)
			banner(m, p * CFrame.new(0, 9, -2.2), 3, 8)
		end
		if not gatehouse then
			part(m, Vector3.new(19, 2.5, 4), gate * CFrame.new(0, 16, -r * 0.5), C.trim, SLATE)
			part(m, Vector3.new(19, 0.6, 4.2), gate * CFrame.new(0, 14.6, -r * 0.5), C.orange, NEON)
		end
		tower(m, gate * CFrame.new(0, 0, r * 0.3), 12, 22, 10, 8)
		for _, sx in { -1, 1 } do
			brazier(m, c - d * (r * 0.3) + perp * (sx * 12), C.teal)
		end
	end
	-- remparts crénelés sur le pourtour, ouverts face au pont
	local seg = 18
	for k = 0, seg - 1 do
		local a1, a2 = k / seg * math.pi * 2, (k + 1) / seg * math.pi * 2
		local mid = Vector3.new(math.cos((a1 + a2) / 2), 0, math.sin((a1 + a2) / 2))
		if mid:Dot(-d) < 0.93 then
			local p1 = c + Vector3.new(math.cos(a1), 0, math.sin(a1)) * (r - 1.5)
			local p2 = c + Vector3.new(math.cos(a2), 0, math.sin(a2)) * (r - 1.5)
			battlement(m, p1, p2, 2.6)
		end
	end
	lamp(m, c - d * (r * 0.55) + perp * (r * 0.35), index % 2 == 0)
	lamp(m, c - d * (r * 0.55) - perp * (r * 0.35), false)
	-- décors sur le pourtour de l'îlot (pas devant le pont)
	for _ = 1, math.floor(r / 4) do
		local a = rng:NextNumber(0, math.pi * 2)
		local dir2 = Vector3.new(math.cos(a), 0, math.sin(a))
		if dir2:Dot(-d) < 0.8 then
			local base = CFrame.new(O + c + dir2 * (r * rng:NextNumber(0.62, 0.86)) + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local roll = rng:NextNumber()
			if roll < 0.35 then
				mushrooms(m, base, false)
			elseif roll < 0.55 then
				pumpkin(m, base, rng:NextNumber(1.4, 2.4))
			elseif roll < 0.8 then
				bush(m, base, rng:NextNumber(1.8, 3))
			else
				tuft(m, base)
			end
		end
	end
	bridge(parent, d * (D.islandRadius - 1), d * (spec.dist - r + 1) + Vector3.new(0, spec.y, 0), if spec.kind == "cathedrale" then 22 else 9)
end

-- Braises qui montent (peu d'émetteurs, débit faible : performances mobiles). `props` remplace les réglages
-- par défaut pour les autres effets (lucioles magiques, brume au sol).
local function embers(parent: Instance, localPos: Vector3, size: number, props: { [string]: any }?)
	local anchor = part(parent, Vector3.new(size, 1, size), CFrame.new(O + localPos), C.ember, SLATE, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local p = Instance.new("ParticleEmitter")
	flipbook(p, "Braise")
	p.Color = ColorSequence.new(C.gold, C.ember)
	p.LightEmission = 1
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new(0.1, 1)
	p.Lifetime = NumberRange.new(5, 8)
	p.Rate = 6
	p.Speed = NumberRange.new(2, 5)
	p.SpreadAngle = Vector2.new(35, 35)
	p.Acceleration = Vector3.new(0, 1.5, 0)
	p.Shape = Enum.ParticleEmitterShape.Box
	if props then
		for k, v in props do
			if k == "Flipbook" then
				flipbook(p, v) -- planche animée du kit
			elseif k == "Texture" then
				p.Texture = v -- texture fixe : plus de découpage en grille
				p.FlipbookLayout = Enum.ParticleFlipbookLayout.None
			else
				(p :: any)[k] = v
			end
		end
	end
	p.Parent = anchor
end

-- Construction ----------------------------------------------------------------------------------------------

function IleMonstres.build(): Model
	local old = Workspace:FindFirstChild("MondeMonstres")
	if old then
		old:Destroy()
	end
	rng = Random.new(1337)
	created, lights = 0, 0

	local root = model(Workspace, "MondeMonstres")
	local platform = model(root, "Plateforme")
	local buildings = model(root, "Batiments")
	local rocks = model(root, "Rochers")
	local effects = model(root, "Effets")

	ground(platform)
	plaza(platform, function()
		return false
	end)
	plots(platform)
	-- grande avenue de la place jusqu'au pont de la Tour des monstres (îlot du fond, entre deux parcelles)
	local avenueDeg = 270
	for _, spec in Config.islets do
		if spec.kind == "cathedrale" then
			avenueDeg = spec.angle - 90 -- même direction exprimée depuis +X
		end
	end
	local avenueDir = Vector3.new(math.cos(math.rad(avenueDeg)), 0, math.sin(math.rad(avenueDeg)))
	local avenueLen = D.islandRadius - D.plazaRadius
	local avenueMid = avenueDir * (D.plazaRadius + avenueLen / 2) + Vector3.new(0, LAYER * 7.5, 0)
	local avenue = CFrame.lookAt(O + avenueMid, O + avenueMid + avenueDir)
	local avenueKit = hasKit()
	if avenueKit then
		local count = math.max(1, math.floor(avenueLen / 12 + 0.5))
		for z = 0, count - 1 do
			kit(platform, "Avenue", avenue * CFrame.new(0, 0.85 - LAYER * 7.5, -avenueLen / 2 + (z + 0.5) * avenueLen / count), Vector3.new(1, 1, avenueLen / count / 12))
		end
	else
		part(platform, Vector3.new(16, 0.3, avenueLen), avenue * CFrame.new(0, -0.15, 0), C.plazaInner, COBBLE)
	end
	for _, sx in { -1, 1 } do
		if not avenueKit then
			part(platform, Vector3.new(0.6, 0.3, avenueLen), avenue * CFrame.new(sx * 8.3, -0.05, 0), C.gold, NEON)
		end
		for z = -avenueLen / 2 + 8, avenueLen / 2 - 8, 18 do
			lamp(platform, (avenue * CFrame.new(sx * 11, 0, z)).Position - O, false)
		end
	end
	if not avenueKit then -- bordures et pierres déjà dans les modules du kit
		for _, sx in { -1, 1 } do
			local a0 = (avenue * CFrame.new(sx * 9.2, 0, avenueLen / 2 - 1)).Position
			local a1 = (avenue * CFrame.new(sx * 9.2, 0, -avenueLen / 2 + 1)).Position
			curbLine(platform, Vector3.new(a0.X, O.Y + LAYER * 3, a0.Z), Vector3.new(a1.X, O.Y + LAYER * 3, a1.Z), 0.9, 1.05)
		end
		for _ = 1, 70 do
			flatStone(platform, (avenue * CFrame.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-avenueLen / 2, avenueLen / 2))).Position, LAYER * 7.5, WARM)
		end
	end
	archGate(platform, facingCentre(avenueDir * (D.plazaRadius + 2) + Vector3.new(0, PLAZA_TOP, 0)), 18, 22)

	local tips = rockBase(rocks, Vector3.zero, D.islandRadius, D.rockDepth, D.block)
	local L = D.lightColumnLength
	for i = 1, math.min(4, #tips) do
		lightColumn(effects, tips[i] + Vector3.new(0, 3, 0), L[1] + (L[2] - L[1]) * (i % 3) / 2)
	end

	for i, spec in Config.islets do
		islet(buildings, rocks, effects, spec, i)
	end

	-- bordure de pierre autour de la place, ouverte sur les allées et devant la cathédrale
	local P = Config.plots
	local curbCount = 60
	for k = 0, curbCount - 1 do
		local a1, a2 = k / curbCount * math.pi * 2, (k + 1) / curbCount * math.pi * 2
		local mid = (a1 + a2) / 2
		local open = math.abs(((math.deg(mid) - avenueDeg + 180) % 360) - 180) < 10 -- avenue de la Tour
		for j = 0, P.count - 1 do
			if math.abs(((math.deg(mid) - j * P.angleStep + 180) % 360) - 180) < 6 then
				open = true
			end
		end
		if not open then
			local r = D.plazaRadius + 1
			local p1 = Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r)
			local p2 = Vector3.new(math.cos(a2) * r, 0, math.sin(a2) * r)
			local cf = CFrame.lookAt(O + (p1 + p2) / 2, O + p2)
			part(platform, Vector3.new(2.4, 1.2, (p2 - p1).Magnitude + 0.2), cf * CFrame.new(0, 0.6, 0), C.trim, SLATE)
		end
	end
	-- braseros sur la place
	for i, deg in { 0, 60, 120, 180 } do
		local a = math.rad(deg)
		brazier(platform, Vector3.new(math.cos(a) * 52, PLAZA_TOP, math.sin(a) * 52), if i % 2 == 0 then C.teal else nil)
	end

	-- petites tours et maisons le long du bord, entre les parcelles (sauf devant les ponts)
	local bridgeAngles = {}
	for _, spec in Config.islets do
		table.insert(bridgeAngles, spec.angle - 90) -- même angle exprimé depuis +X
	end
	for k = 0, P.count - 1 do
		local deg = k * P.angleStep + P.angleStep / 2
		local clear = true
		for _, b in bridgeAngles do
			if math.abs(((deg - b + 180) % 360) - 180) < 10 then
				clear = false
			end
		end
		if clear then
			local a = math.rad(deg)
			local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * (D.islandRadius - 18)
			local cf = facingCentre(pos)
			if k % 2 == 0 then
				tower(buildings, cf, 10, 28, 10, 8)
			else
				house(buildings, cf, 16, 11, 10)
			end
		end
	end

	-- scènes entre les parcelles : cimetières, ruines et cristaux, buttes et cages
	local scenes = model(platform, "Scenes")
	for k = 0, P.count - 1 do
		local deg = k * P.angleStep + P.angleStep / 2
		local a = math.rad(deg)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local y = Vector3.new(0, LAYER * 3, 0)
		local onAvenue = math.abs(((deg - avenueDeg + 180) % 360) - 180) < 6
		local kind = if onAvenue then -1 else k % 3
		if kind == 0 then
			graveyard(scenes, facingCentre(d * 122 + y) * CFrame.Angles(0, math.pi, 0), 12, 26)
			local grave = facingCentre(d * 104 + y)
			if not kit(scenes, "Tombe", grave * CFrame.Angles(0, math.pi, 0), Vector3.one * 1.6) and not voxel(scenes, "Decors", { "Tombe1", "Tombe2" }, grave, 5) then
				placeAsset(scenes, "Tombe", grave, 6)
			end
		elseif kind == 1 then
			ruins(scenes, facingCentre(d * 108 + y))
			local cc = facingCentre(d * 136 + y)
			local asset = if hasKit() then nil else placeAsset(scenes, "Cristaux", cc, 8)
			if asset then
				local glow = part(scenes, Vector3.new(1, 1, 1), cc * CFrame.new(0, 5, 0), C.violet, NEON, { Transparency = 1 })
				light(glow, 18, 2.2, C.violet, T.flamme)
			else
				crystals(scenes, cc, C.crystal, 3)
			end
		elseif kind == 2 then
			outcrop(scenes, facingCentre(d * 112 + y), 10)
			cage(scenes, facingCentre(d * 136 + y))
		end
		-- gargouille sur l'anneau intérieur, face à la place (de part et d'autre de l'avenue)
		local g = facingCentre(d * 69 + Vector3.new(0, LAYER * 6, 0))
		if onAvenue then
			for _, sx in { -1, 1 } do
				local gg = facingCentre(d * 69 + side(d) * (sx * 13) + Vector3.new(0, LAYER * 6, 0))
				if not placeAsset(scenes, "Gargouille", gg, 9, recolorGothic) then
					gargoyle(scenes, gg)
				end
			end
		elseif not placeAsset(scenes, "Gargouille", g, 9, recolorGothic) then
			gargoyle(scenes, g)
		end
		-- tonneaux contre le rempart, derrière chaque parcelle
		local back = math.rad(k * P.angleStep)
		barrels(scenes, facingCentre(Vector3.new(math.cos(back), 0, math.sin(back)) * (D.islandRadius - 9) + y))
	end

	scatterDecor(platform, avenueDeg)

	-- rochers flottants autour de l'île (profondeur)
	local debris = model(rocks, "Debris")
	local placed = 0
	local tries = 0
	while placed < 32 and tries < 400 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(D.islandRadius + 25, 360)
		local pos = Vector3.new(math.cos(a) * dist, rng:NextNumber(-90, 50), math.sin(a) * dist)
		local ok = true
		for _, spec in Config.islets do
			local c = dir(spec.angle) * spec.dist
			if (Vector3.new(pos.X, 0, pos.Z) - c).Magnitude < spec.radius + 28 then
				ok = false
			end
		end
		if ok then
			placed += 1
			floatingRock(debris, pos, rng:NextNumber(6, 16))
		end
	end

	-- braises : au-dessus de la place et sous quelques îlots
	embers(effects, Vector3.new(0, 1, 0), 80)
	for i = 1, Config.emberEmitters - 1 do
		local spec = Config.islets[i]
		if spec then
			embers(effects, dir(spec.angle) * spec.dist + Vector3.new(0, spec.y - 30, 0), 50)
		end
	end

	-- lucioles magiques turquoise et violettes qui dérivent au-dessus de la place
	embers(effects, Vector3.new(0, 3, 0), 110, {
		Texture = Kit.particles.Lueur,
		Color = ColorSequence.new(C.teal, C.violet),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.45), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(6, 10),
		Rate = 10,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.4, 0),
		RotSpeed = NumberRange.new(-90, 90),
	})
	-- cercles de runes qui s'élèvent lentement de la rosace centrale, à plat
	embers(effects, Vector3.new(0, 1.4, 0), 6, {
		Flipbook = "Rune",
		Color = ColorSequence.new(Color3.fromHex("#B48CFF"), Color3.fromHex("#7B5CD6")),
		LightEmission = 0.8,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 7) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(5, 6),
		Rate = 0.6,
		Speed = NumberRange.new(1.2, 1.6),
		SpreadAngle = Vector2.zero,
		Acceleration = Vector3.zero,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		RotSpeed = NumberRange.new(-20, 20),
		Rotation = NumberRange.new(0, 360),
	})
	-- brume violette qui rampe au ras du sol, autour de la place et le long du rempart
	local mist = {
		Flipbook = "Fumee",
		Color = ColorSequence.new(Color3.fromHex("#8A6AC8"), Color3.fromHex("#C07AA8")),
		LightEmission = 0.15,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 18) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.82), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(10, 14),
		Rate = 2,
		Speed = NumberRange.new(0.5, 1.2),
		SpreadAngle = Vector2.new(80, 0),
		Acceleration = Vector3.zero,
		RotSpeed = NumberRange.new(-8, 8),
		Rotation = NumberRange.new(0, 360),
	}
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.3
		embers(effects, Vector3.new(math.cos(a), 0, math.sin(a)) * 125 + Vector3.new(0, 2, 0), 40, mist)
	end
	-- âmes qui montent autour de la Tour des monstres
	for _, spec in Config.islets do
		if spec.kind == "cathedrale" then
			embers(effects, dir(spec.angle) * spec.dist + Vector3.new(0, spec.y + 6, 0), 70, {
				Flipbook = "Ame",
				Color = ColorSequence.new(Color3.fromHex("#C9A2FF"), C.violet),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0) }),
				Lifetime = NumberRange.new(8, 12),
				Rate = 8,
				Speed = NumberRange.new(3, 6),
				Acceleration = Vector3.new(0, 2, 0),
			})
		end
	end

	-- Point d'apparition sécurisé : sur la place, face à la cathédrale (comme le spawn de la map des héros, près
	-- du centre). Désactivé tant que le choix du monde n'existe pas, sinon les joueurs apparaîtraient au hasard
	-- sur l'une des deux maps.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnMonstres"
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(O + Vector3.new(0, 1, 30), O + Vector3.new(0, 1, -30))
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = root

	-- Cadrage de la vue d'ensemble (comme la référence : de face, légèrement au-dessus).
	local view = Instance.new("CFrameValue")
	view.Name = "VueEnsemble"
	view.Value = CFrame.lookAt(O + Vector3.new(0, 230, 700), O + Vector3.new(0, -20, 0))
	view.Parent = root

	-- Détail « pixel » des murs, toits et boiseries (ServerStorage.SurfaceDetail), comme les maisons de la map
	-- des héros : petites tuiles posées sur les faces visibles, fusionnées par bâtiment.
	local detailModule = ServerStorage:FindFirstChild("SurfaceDetail")
	if detailModule and not hasKit() then
		local Detail = require(detailModule) :: any
		local kinds = {
			[C.stone:ToHex()] = "stone",
			[C.trim:ToHex()] = "stone",
			[C.brick:ToHex()] = "stone",
			[C.roof:ToHex()] = "roof",
			[C.wood:ToHex()] = "wood",
		}
		local detailRng = Random.new(77)
		local targets: { Instance } = {}
		for _, b in buildings:GetChildren() do
			table.insert(targets, b)
		end
		for _, name in { "Parcelles", "Place" } do
			local t = platform:FindFirstChild(name)
			if t then
				table.insert(targets, t)
			end
		end
		for _, target in targets do
			local tiles = {}
			for _, d in target:GetDescendants() do
				if d:IsA("Part") and d.Transparency < 0.5 and d.Material ~= NEON then
					local kind = kinds[d.Color:ToHex()]
					if kind then
						Detail.decorate(d, { target }, detailRng, tiles, 1, kind)
					end
				end
			end
			-- fusion par paquets (une fusion trop grosse échoue)
			for i = 1, #tiles, 600 do
				Detail.union(table.move(tiles, i, math.min(i + 599, #tiles), 1, {}), "Details", target)
				task.wait()
			end
		end
	end

	root.WorldPivot = CFrame.new(O)
	print(`[IleMonstres] {created} pièces, {lights} lumières`)
	return root
end

return IleMonstres
