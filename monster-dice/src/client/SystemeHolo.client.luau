-- Système holographique (local) : panneau 3D projeté depuis le personnage, ouvert avec M ou le bouton mobile.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ===== Réglages =====
local TOUCHE = "M" -- lettre affichée sur le clavier (marche en AZERTY comme en QWERTY)
local TAILLE_ECRAN = 0.52 -- hauteur du panneau en fraction de la hauteur d'écran (reste lisible quel que soit le zoom)
local MARGE = 3.0 -- espace (studs) entre le perso et le bord gauche du panneau
local HAUTEUR = 1.3 -- hauteur du centre du panneau au-dessus du torse (studs)
local DESCENTE = 0.07 -- abaisse le panneau d'une fraction de sa hauteur (il grandit vers le bas)
local INCLINAISON = 0 -- rotation 3D du panneau en degrés (0 = bien face à l'écran, négatif = vers la gauche)
local LISSAGE = 10 -- vitesse de suivi (plus haut = plus collé au perso)
local DUREE_OUVERTURE, DUREE_FERMETURE = 0.5, 0.35
local SOURCE = Vector3.new(0.9, 0.5, 0) -- point de projection : droite / haut / avant, depuis le HumanoidRootPart
local DESIGN = Vector2.new(620, 460) -- résolution de travail de l'UI en pixels

-- ===== Données de démonstration =====
local DEMO = {
	niveau = 24,
	classe = "Aucune",
	titre = "Assassin des Loups",
	pv = { 2450, 2450 },
	mana = { 380, 500 },
	-- EXEMPLE TEMPORAIRE : utilisé seulement si les vraies données (voir lireProgression) sont absentes
	progression = { multiMonnaies = 25, multiLuck = 10e12, monstres = { 4, 56 }, artefacts = { 2, 30 } },
	quetes = {
		{ "Entraînement quotidien", 75, 100 },
		{ "Nettoyer le donjon E", 3, 5 },
		{ "Rapport à la Guilde", 0, 1 },
	},
	inventaire = {
		{ "Dague", 1 }, { "Potion PV", 5 }, { "Potion MP", 3 }, { "Clé", 1 },
		{ "Cristal", 12 }, { "Parchemin", 2 },
	},
}

local CYAN = Color3.fromRGB(80, 210, 255)
local FOND = Color3.fromRGB(6, 14, 34)
local TEXTE = Color3.fromRGB(220, 240, 255)
local TEXTE_DIM = Color3.fromRGB(140, 175, 210)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Évite les doublons si le script est relancé
for _, nom in { "SystemeHolo", "SystemeHoloArriere", "SystemeBoutonMobile" } do
	local ancien = playerGui:FindFirstChild(nom)
	if ancien then ancien:Destroy() end
end
local ancienFx = workspace:FindFirstChild("SystemeHoloFx")
if ancienFx then ancienFx:Destroy() end

local function new(class, props, enfants)
	local o = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do o[k] = v end
	for _, e in enfants or {} do e.Parent = o end
	o.Parent = parent
	return o
end

local function texte(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or TEXTE
	props.TextSize = props.TextSize or 14
	return new("TextLabel", props)
end

-- ===== Supports 3D locaux (créés par le client => invisibles pour les autres joueurs) =====
local fx = new("Folder", { Name = "SystemeHoloFx", Parent = workspace })
local function support(nom)
	return new("Part", {
		Name = nom, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		CastShadow = false, Transparency = 1, Size = Vector3.new(1, 1, 0.02), Parent = fx,
	})
end
local avant = support("Avant") -- cadre + contenu
local arriere = support("Arriere") -- fond translucide + second contour, en retrait
local source = new("Part", {
	Name = "Source", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = CYAN, Transparency = 1,
	Size = Vector3.one * 0.2, Parent = fx,
})
local lumiere = new("PointLight", { Color = CYAN, Range = 6, Brightness = 0, Parent = source })
-- Étincelles projetées à l'ouverture / aspirées à la fermeture
local etincelles = new("ParticleEmitter", {
	Color = ColorSequence.new(CYAN, Color3.new(1, 1, 1)), LightEmission = 1, LightInfluence = 0,
	Size = NumberSequence.new(0.18, 0), Transparency = NumberSequence.new(0, 1),
	Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(180, 180),
	Drag = 4, Rate = 0, Parent = source,
})
local filament = new("Beam", {
	Attachment0 = new("Attachment", { Parent = source }),
	Attachment1 = new("Attachment", { Parent = avant }),
	Color = ColorSequence.new(CYAN), LightEmission = 1, FaceCamera = true,
	Width0 = 0.05, Width1 = 0.25, Segments = 1, Enabled = false, Parent = source,
})

local function surface(nom, adornee, zOffset, actif)
	return new("SurfaceGui", {
		Name = nom, Adornee = adornee, Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = DESIGN,
		AlwaysOnTop = true, ZOffset = zOffset, LightInfluence = 0, Brightness = 1.4,
		Active = actif, ResetOnSpawn = false, Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui, -- dans PlayerGui (pas Workspace) sinon pas de clics
	})
end
local guiArriere = surface("SystemeHoloArriere", arriere, 0, false)
local guiAvant = surface("SystemeHolo", avant, 1, true)

-- Couche arrière : fond sombre + contour fantôme
new("Frame", {
	Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4),
	BackgroundColor3 = FOND, BackgroundTransparency = 0.25, Parent = guiArriere,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
	new("UIStroke", { Color = CYAN, Thickness = 1.5, Transparency = 0.6 }),
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.3) }),
})

-- Couche avant : cadre lumineux + contenu
local panneau = new("Frame", {
	Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4),
	BackgroundColor3 = FOND, BackgroundTransparency = 0.75, Parent = guiAvant,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 4) }),
})
-- Cadre avec une lueur blanche qui tourne en continu autour du bord
local lueurCadre = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CYAN), ColorSequenceKeypoint.new(0.42, CYAN),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.58, CYAN), ColorSequenceKeypoint.new(1, CYAN),
	}),
})
new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2.5, Parent = panneau }, { lueurCadre })

-- Angles géométriques lumineux
for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
	local ap = Vector2.new(c[1], c[2])
	local pos = UDim2.new(c[1], c[1] == 0 and -3 or 3, c[2], c[2] == 0 and -3 or 3)
	new("Frame", { AnchorPoint = ap, Position = pos, Size = UDim2.fromOffset(18, 3), BackgroundColor3 = CYAN, BorderSizePixel = 0, Parent = panneau })
	new("Frame", { AnchorPoint = ap, Position = pos, Size = UDim2.fromOffset(3, 18), BackgroundColor3 = CYAN, BorderSizePixel = 0, Parent = panneau })
end

-- Reflet qui traverse le panneau de temps en temps
local clip = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5, Parent = panneau })
local reflet = new("Frame", {
	Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(-0.3, 0, 0, 0),
	BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, BorderSizePixel = 0, Parent = clip,
}, {
	new("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.88), NumberSequenceKeypoint.new(1, 1),
		}),
	}),
})

-- Lignes de balayage holographiques qui défilent lentement
local scanlines = new("Frame", { Size = UDim2.new(1, 0, 1, 8), BackgroundTransparency = 1, Parent = clip })
for y = 0, DESIGN.Y + 8, 4 do
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, y),
		BackgroundColor3 = CYAN, BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = scanlines,
	})
end

-- Textes qui se "décryptent" à l'ouverture
local decryptables = {}
local function decryptable(label)
	table.insert(decryptables, { label, label.Text })
	return label
end

decryptable(texte({
	Text = "S Y S T È M E", TextSize = 24, Font = Enum.Font.GothamBlack,
	Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 8), TextColor3 = Color3.new(1, 1, 1), Parent = panneau,
}))
local titre = decryptables[1][1]
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CYAN), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, CYAN),
	}),
	Parent = titre,
})
new("UIStroke", { Color = CYAN, Thickness = 1, Transparency = 0.55, Parent = titre })
-- Losanges de part et d'autre du titre
for _, x in { -110, 110 } do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0, 23), Size = UDim2.fromOffset(7, 7),
		Rotation = 45, BackgroundColor3 = CYAN, BorderSizePixel = 0, Parent = panneau,
	})
	new("Frame", {
		AnchorPoint = Vector2.new(x < 0 and 1 or 0, 0.5), Position = UDim2.new(0.5, x + (x < 0 and -8 or 8), 0, 23),
		Size = UDim2.fromOffset(60, 1), BackgroundColor3 = CYAN, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = panneau,
	})
end
decryptable(texte({
	Text = string.upper(player.DisplayName) .. "  •  NIV. " .. DEMO.niveau,
	TextSize = 12, TextColor3 = TEXTE_DIM, Font = Enum.Font.Gotham,
	Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 42), Parent = panneau,
}))
new("Frame", { Size = UDim2.new(1, -40, 0, 1), Position = UDim2.fromOffset(20, 64), BackgroundColor3 = CYAN, BorderSizePixel = 0, Parent = panneau }, {
	new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1),
	}) }),
})

local fermerBtn = new("TextButton", {
	Text = "X", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = CYAN,
	BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0, 8),
	Parent = panneau,
})

local contenu = new("Frame", { Size = UDim2.new(1, -32, 1, -164), Position = UDim2.fromOffset(12, 114), BackgroundTransparency = 1, Parent = panneau })

local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
texte({
	Text = touchOnly and "SYS  •  FERMER" or "[M]  FERMER",
	TextSize = 12, TextColor3 = TEXTE_DIM,
	Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -30), Parent = panneau,
})

local barres = {}
local function barre(parent, nom, val, max, couleur, y)
	texte({ Text = nom, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.7, 0, 0, 16), Position = UDim2.fromOffset(0, y), Parent = parent })
	texte({ Text = val .. " / " .. max, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, y), Parent = parent })
	local fond = new("Frame", {
		Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, y + 19),
		BackgroundColor3 = Color3.fromRGB(20, 35, 60), BorderSizePixel = 0, Parent = parent,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = CYAN, Transparency = 0.6 }) })
	local rempli = new("Frame", { Size = UDim2.fromScale(math.clamp(val / max, 0, 1), 1), BackgroundColor3 = couleur, BorderSizePixel = 0, Parent = fond }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		-- bout lumineux de la barre
		new("UIGradient", { Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, couleur), ColorSequenceKeypoint.new(0.85, couleur), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		}) }),
	})
	table.insert(barres, { rempli, math.clamp(val / max, 0, 1) })
end

-- Compteurs qui défilent de 0 à leur valeur
local compteurs = {}
local function compteur(label, prefixe, valeur)
	table.insert(compteurs, { label, prefixe, valeur })
	return label
end

-- ===== Données de progression =====
-- Sources lues (adapte les noms à ton jeu) :
--   Attributs du joueur : "MultiMonnaies", "MultiLuck" (nombres) -> multiplicateurs de gain, jamais le solde
--   Catalogues : ReplicatedStorage.Catalogues.Monstres / .Artefacts (un enfant par entrée)
--   Découvertes : Player.Index.Monstres / .Artefacts (un enfant par découverte, doublons ignorés)
-- Si une source manque, l'EXEMPLE TEMPORAIRE DEMO.progression est affiché à la place.
local SUFFIXES = { "", "K", "M", "B", "T" }
local function abreger(n)
	local i = 1
	while math.abs(n) >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	return (string.format("%.1f", n):gsub("%.0$", "")) .. SUFFIXES[i]
end
assert(abreger(25) == "25" and abreger(10e12) == "10T" and abreger(1500) == "1.5K" and abreger(999) == "999")

local function lireIndex(nom, exemple)
	local catalogues = ReplicatedStorage:FindFirstChild("Catalogues")
	local catalogue = catalogues and catalogues:FindFirstChild(nom)
	if not catalogue then return exemple[1], exemple[2] end
	local index = player:FindFirstChild("Index")
	local decouvertes = index and index:FindFirstChild(nom)
	local vus, trouves = {}, 0
	for _, e in decouvertes and decouvertes:GetChildren() or {} do
		-- unique + doit exister dans le catalogue
		if not vus[e.Name] and catalogue:FindFirstChild(e.Name) then
			vus[e.Name] = true
			trouves += 1
		end
	end
	return trouves, #catalogue:GetChildren()
end

local LIGNES = {
	{ icone = "💰", couleur = Color3.fromRGB(255, 200, 60), libelle = "Multi monnaies", lire = function()
		return "×" .. abreger(player:GetAttribute("MultiMonnaies") or DEMO.progression.multiMonnaies)
	end },
	{ icone = "🍀", couleur = Color3.fromRGB(60, 220, 120), libelle = "Multi luck", lire = function()
		return "×" .. abreger(player:GetAttribute("MultiLuck") or DEMO.progression.multiLuck)
	end },
	{ icone = "👹", couleur = Color3.fromRGB(255, 80, 90), libelle = "Index monstres", index = true, lire = function()
		return lireIndex("Monstres", DEMO.progression.monstres)
	end },
	{ icone = "💎", couleur = Color3.fromRGB(170, 120, 255), libelle = "Index artefacts", index = true, lire = function()
		return lireIndex("Artefacts", DEMO.progression.artefacts)
	end },
}

local function rafraichir()
	for _, def in LIGNES do
		if def.index then
			local trouves, total = def.lire()
			def.valeur.Text = abreger(trouves) .. " / " .. abreger(total)
			local ratio = total > 0 and math.clamp(trouves / total, 0, 1) or 0
			if ratio ~= def.barre[2] then
				def.barre[2] = ratio
				TweenService:Create(def.barre[1], TweenInfo.new(0.4), { Size = UDim2.fromScale(ratio, 1) }):Play()
			end
		else
			def.valeur.Text = def.lire()
		end
	end
end

-- ===== Pages =====
local pages = {}

pages.Statut = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = contenu })
do
	local p = pages.Statut
	local niv = texte({ Text = tostring(DEMO.niveau), TextSize = 44, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(70, 44), Parent = p })
	new("UIStroke", { Color = CYAN, Thickness = 1.5, Transparency = 0.5, Parent = niv })
	compteur(niv, "", DEMO.niveau)
	texte({ Text = "NIVEAU", TextSize = 11, TextColor3 = TEXTE_DIM, Size = UDim2.fromOffset(70, 14), Position = UDim2.fromOffset(0, 44), Parent = p })
	texte({ Text = "CLASSE : " .. DEMO.classe, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -80, 0, 18), Position = UDim2.fromOffset(80, 8), Parent = p })
	texte({ Text = "TITRE : " .. DEMO.titre, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, -80, 0, 32), Position = UDim2.fromOffset(80, 28), Parent = p })
	barre(p, "PV", DEMO.pv[1], DEMO.pv[2], Color3.fromRGB(40, 220, 150), 72)
	barre(p, "MANA", DEMO.mana[1], DEMO.mana[2], Color3.fromRGB(40, 140, 255), 110)
	-- Lignes de progression : icône | libellé | valeur (+ barre fine pour les index)
	local y = 150
	for _, def in LIGNES do
		local icone = new("Frame", {
			Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(0, y + 2),
			BackgroundColor3 = def.couleur, BackgroundTransparency = 0.75, Parent = p,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = def.couleur, Thickness = 1.5 }) })
		texte({ Text = def.icone, TextSize = 14, Size = UDim2.fromScale(1, 1), Parent = icone })
		texte({
			Text = def.libelle, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -170, 0, 28), Position = UDim2.fromOffset(34, y), Parent = p,
		})
		def.valeur = texte({
			Text = "", TextSize = 15, Font = Enum.Font.GothamBlack, TextColor3 = CYAN,
			TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.fromOffset(130, 28), Position = UDim2.new(1, -130, 0, y), Parent = p,
		})
		y += 30
		if def.index then
			local fond = new("Frame", {
				Size = UDim2.new(1, -34, 0, 3), Position = UDim2.fromOffset(34, y - 2),
				BackgroundColor3 = Color3.fromRGB(20, 35, 60), BorderSizePixel = 0, Parent = p,
			}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local rempli = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN, BorderSizePixel = 0, Parent = fond },
				{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			def.barre = { rempli, 0 }
			table.insert(barres, def.barre)
			y += 8
		end
	end
end

pages["Quêtes"] = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = contenu })
for i, q in DEMO.quetes do
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromOffset(0, (i - 1) * 62), BackgroundTransparency = 1, Parent = pages["Quêtes"] })
	barre(f, q[1], q[2], q[3], CYAN, 6)
end

pages.Inventaire = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = contenu }, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(62, 62), CellPadding = UDim2.fromOffset(6, 6) }),
})
for _, it in DEMO.inventaire do
	new("Frame", { BackgroundColor3 = Color3.fromRGB(14, 28, 56), BackgroundTransparency = 0.2, Parent = pages.Inventaire }, {
		new("UICorner", { CornerRadius = UDim.new(0, 4) }),
		new("UIStroke", { Color = CYAN, Transparency = 0.5 }),
		texte({ Text = it[1], TextSize = 10, TextWrapped = true, Size = UDim2.new(1, -6, 0, 30), Position = UDim2.fromOffset(3, 8) }),
		texte({ Text = "x" .. it[2], TextSize = 11, TextColor3 = CYAN, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, -6, 0, 14), Position = UDim2.new(0, 0, 1, -17) }),
	})
end

-- ===== Onglets =====
-- L'onglet actif change de couleur/épaisseur (pas de transparence : le fondu gère déjà la transparence)
local ONGLET_ACTIF = Color3.fromRGB(25, 85, 120)
local onglets = {}
local interactif = false
local pageActive = "Statut"
local generation = 0 -- annule les animations de texte en cours si on en relance une

local function animerPage(nom)
	local page = pages[nom]
	generation += 1
	local gen = generation
	page.Position = UDim2.fromOffset(18, 0)
	TweenService:Create(page, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Position = UDim2.fromOffset(0, 0) }):Play()
	for _, b in barres do
		if b[1]:IsDescendantOf(page) then
			b[1].Size = UDim2.fromScale(0, 1)
			TweenService:Create(b[1], TweenInfo.new(0.8, Enum.EasingStyle.Quart), { Size = UDim2.fromScale(b[2], 1) }):Play()
		end
	end
	task.spawn(function()
		local debut = os.clock()
		repeat
			local k = 1 - (1 - math.min((os.clock() - debut) / 0.7, 1)) ^ 3
			for _, c in compteurs do
				if gen == generation and c[1]:IsDescendantOf(page) then c[1].Text = c[2] .. math.floor(c[3] * k + 0.5) end
			end
			task.wait()
		until k >= 1 or gen ~= generation
	end)
end

local CARACTERES = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&@$"
local function decrypter()
	task.spawn(function()
		local debut = os.clock()
		repeat
			local k = math.min((os.clock() - debut) / 0.55, 1)
			for _, d in decryptables do
				local sortie = {}
				local i, n = 0, utf8.len(d[2])
				for _, code in utf8.codes(d[2]) do
					i += 1
					local c = utf8.char(code)
					if c ~= " " and i > n * k then
						local r = math.random(#CARACTERES)
						c = CARACTERES:sub(r, r)
					end
					table.insert(sortie, c)
				end
				d[1].Text = table.concat(sortie)
			end
			task.wait(0.03)
		until k >= 1
	end)
end

local function afficherPage(nom)
	pageActive = nom
	for n, page in pages do page.Visible = n == nom end
	for n, b in onglets do
		local actif = n == nom
		b.BackgroundColor3 = actif and ONGLET_ACTIF or FOND
		b.UIStroke.Thickness = actif and 2.5 or 1
	end
	animerPage(nom)
end
for i, nom in { "Statut", "Quêtes", "Inventaire" } do
	local b = new("TextButton", {
		Text = ({ Statut = "STATUT", ["Quêtes"] = "QUÊTES", Inventaire = "INVENTAIRE" })[nom], TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = TEXTE,
		AutoButtonColor = false, BackgroundTransparency = 0.3,
		Size = UDim2.fromOffset((DESIGN.X - 44) / 3, 30), Position = UDim2.fromOffset(12 + (i - 1) * ((DESIGN.X - 44) / 3 + 6), 74),
		Parent = panneau,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 3) }), new("UIStroke", { Color = CYAN, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	b.Activated:Connect(function()
		if interactif and nom ~= pageActive then afficherPage(nom) end
	end)
	-- Survol : l'onglet s'illumine
	b.MouseEnter:Connect(function()
		b.TextColor3, b.UIStroke.Color = CYAN, Color3.new(1, 1, 1)
	end)
	b.MouseLeave:Connect(function()
		b.TextColor3, b.UIStroke.Color = TEXTE, CYAN
	end)
	onglets[nom] = b
end
rafraichir()
afficherPage("Statut")

-- ===== Fondus (mémorise la transparence de base) : le cadre apparaît d'abord, le contenu ensuite =====
local fondusCadre, fondusContenu = {}, {}
for _, g in { guiAvant, guiArriere } do
	for _, o in g:GetDescendants() do
		local estContenu = o:IsDescendantOf(contenu) or o:IsA("TextButton") or o.Parent:IsA("TextButton") or o.Parent:IsA("TextLabel")
		local liste = estContenu and fondusContenu or fondusCadre
		if o:IsA("GuiObject") then table.insert(liste, { o, "BackgroundTransparency", o.BackgroundTransparency }) end
		if o:IsA("TextLabel") or o:IsA("TextButton") then table.insert(fondusContenu, { o, "TextTransparency", o.TextTransparency }) end
		if o:IsA("UIStroke") then table.insert(liste, { o, "Transparency", o.Transparency }) end
	end
end
local alphas = {}
local function appliquerAlpha(liste, a)
	if alphas[liste] == a then return end
	alphas[liste] = a
	for _, f in liste do f[1][f[2]] = 1 - (1 - f[3]) * a end
end

-- ===== Animation : une seule progression t (0 = fermé, 1 = ouvert), réversible à tout moment =====
local t, cibleT = 0, 0
local aEmettre = 0
local dernierRoot, posRepos

local function aplatir(v, defaut)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 1e-3 and v.Unit or defaut
end

local function easeOutBack(x) -- léger dépassement puis amortissement à l'arrivée
	local s, u = 1.3, x - 1
	return 1 + (s + 1) * u ^ 3 + s * u ^ 2
end
local function easeOutCubic(x)
	return 1 - (1 - x) ^ 3
end
local function phase(x, debut, fin) -- remappe t sur [debut, fin] -> [0, 1]
	return math.clamp((x - debut) / (fin - debut), 0, 1)
end

local function afficher(visible)
	guiAvant.Enabled, guiArriere.Enabled = visible, visible
	if not visible then
		filament.Enabled = false
		source.Transparency, lumiere.Brightness = 1, 0
	end
end

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or (hum and hum.Health <= 0) then
		-- mort / respawn : on coupe net et on nettoie les effets
		if t > 0 or cibleT > 0 then t, cibleT, interactif = 0, 0, false; afficher(false) end
		return
	end

	local cam = workspace.CurrentCamera
	local camPos = cam.CFrame.Position
	local droite = aplatir(cam.CFrame.RightVector, root.CFrame.RightVector)
	local versCam = aplatir(-cam.CFrame.LookVector, -root.CFrame.LookVector)

	-- Taille monde calculée pour garder une taille stable à l'écran
	local H = 2 * (camPos - root.Position).Magnitude * math.tan(math.rad(cam.FieldOfView / 2)) * TAILLE_ECRAN
	local W = H * DESIGN.X / DESIGN.Y
	local repos = root.Position + droite * (W / 2 + MARGE) + Vector3.yAxis * (HAUTEUR - H * DESCENTE)

	if root ~= dernierRoot or not posRepos then
		dernierRoot, posRepos = root, repos
	end
	posRepos = posRepos:Lerp(repos, 1 - math.exp(-LISSAGE * dt))

	if cibleT > t then
		t = math.min(1, t + dt / DUREE_OUVERTURE)
	elseif cibleT < t then
		t = math.max(0, t - dt / DUREE_FERMETURE)
	end
	interactif = cibleT == 1 and t >= 1
	guiAvant.Active = interactif
	if t <= 0 then
		if guiAvant.Enabled then afficher(false) end
		return
	end
	if not guiAvant.Enabled then afficher(true) end

	-- Ouverture en 3 temps (la fermeture rejoue la même chose à l'envers) :
	-- 1) une fine ligne de lumière jaillit du perso et monte à sa place en tournant
	-- 2) la ligne se déplie en largeur jusqu'au panneau complet
	-- 3) le contenu s'allume avec un flash
	local pVol = phase(t, 0, 0.55)
	local eVol = easeOutCubic(pVol)
	local sy = math.max(easeOutBack(pVol), 0.02)
	local sx = math.max(easeOutBack(phase(t, 0.4, 1)), 0.025)
	local r = 1 - eVol -- reste à parcourir (rotation de projection)

	local origine = root.Position + droite * SOURCE.X + Vector3.yAxis * SOURCE.Y + versCam * SOURCE.Z
	local oscillation = math.sin(os.clock() * 1.6) * 0.02 * H * eVol
	local pos = origine:Lerp(posRepos, eVol) + Vector3.yAxis * oscillation

	local cf = CFrame.new(pos) * cam.CFrame.Rotation * CFrame.Angles(0, math.pi, 0) -- parallèle à l'écran, sans pivot de perspective
		* CFrame.Angles(0, math.rad(INCLINAISON) + r * math.rad(60), r * math.rad(-15))
	avant.Size = Vector3.new(W * sx, H * sy, 0.02)
	avant.CFrame = cf
	arriere.Size = Vector3.new(W * sx + H * 0.03, H * sy + H * 0.03, 0.02) -- dépasse d'une même marge tout autour
	arriere.CFrame = cf * CFrame.new(0, 0, H * 0.01) -- centré, très légèrement en retrait

	appliquerAlpha(fondusCadre, phase(t, 0, 0.25))
	appliquerAlpha(fondusContenu, phase(t, 0.6, 1))
	local flash = math.sin(math.pi * phase(t, 0.5, 1))
	guiAvant.Brightness = 1.4 + 2.5 * flash
	guiArriere.Brightness = 1.4 + 1.5 * flash

	-- Source lumineuse + filament : visibles surtout pendant le mouvement
	local g = math.sin(math.pi * t)
	source.CFrame = CFrame.new(origine)
	if aEmettre > 0 then etincelles:Emit(aEmettre); aEmettre = 0 end -- après placement de la source
	source.Size = Vector3.one * (0.12 + 0.3 * g)
	source.Transparency = 1 - 0.9 * g
	lumiere.Brightness = 3 * g
	filament.Enabled = g > 0.02
	filament.Transparency = NumberSequence.new(1 - 0.8 * g, 1 - 0.5 * g)

	-- Effets continus : lueur qui tourne autour du cadre, lignes de balayage, glitch pendant l'allumage
	local horloge = os.clock()
	lueurCadre.Rotation = (horloge * 70) % 360
	scanlines.Position = UDim2.fromOffset(0, -((horloge * 12) % 4))
	local glitch = t > 0.55 and t < 0.9 and math.random() < 0.5
	contenu.Position = glitch and UDim2.fromOffset(12 + math.random(-4, 4), 114 + math.random(-1, 1)) or UDim2.fromOffset(12, 114)
	titre.Position = glitch and UDim2.fromOffset(math.random(-3, 3), 8) or UDim2.fromOffset(0, 8)
end)

-- Reflet occasionnel (uniquement panneau ouvert)
task.spawn(function()
	while fx.Parent do
		task.wait(4 + math.random() * 3)
		if interactif then
			reflet.Position = UDim2.new(-0.3, 0, 0, 0)
			TweenService:Create(reflet, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Position = UDim2.new(1.1, 0, 0, 0) }):Play()
		end
	end
end)

-- ===== Ouverture / fermeture =====
local function basculer()
	if not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) then return end
	cibleT = cibleT == 1 and 0 or 1 -- inverse simplement la direction : pas de saut si on spamme
	if cibleT == 1 then
		aEmettre = 35
		decrypter()
		rafraichir()
		animerPage(pageActive)
	else
		aEmettre = 15
	end
end

fermerBtn.Activated:Connect(function()
	if interactif then basculer() end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- gameProcessed = chat / zone de texte / clic sur une UI ; la touche n'est pas consommée donc le déplacement continue
	if gameProcessed or UserInputService:GetFocusedTextBox() then return end
	if UserInputService:GetStringForKeyCode(input.KeyCode):upper() == TOUCHE then basculer() end
end)

-- Bouton tactile (mobile uniquement)
if UserInputService.TouchEnabled then
	local sg = new("ScreenGui", { Name = "SystemeBoutonMobile", ResetOnSpawn = false, Parent = playerGui })
	local b = new("TextButton", {
		Text = "SYS", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = CYAN,
		BackgroundColor3 = FOND, BackgroundTransparency = 0.2,
		Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -170),
		Parent = sg,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }), new("UIStroke", { Color = CYAN, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	b.Activated:Connect(basculer)
end

-- Actualisation automatique pendant que le panneau est ouvert
-- shortcut: sondage toutes les 0,5 s, à remplacer par des signaux (AttributeChanged / ChildAdded) si le panneau doit rester ouvert longtemps avec beaucoup de données
task.spawn(function()
	while fx.Parent do
		if cibleT == 1 then rafraichir() end
		task.wait(0.5)
	end
end)
