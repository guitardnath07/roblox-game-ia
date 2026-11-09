--!strict
-- Parcelles attitrées : chaque joueur reçoit à son arrivée une parcelle libre (la même dans les deux mondes),
-- retenue dans l'attribut Player.Parcelle. Un panneau devant chaque parcelle affiche son propriétaire.
-- La parcelle est sauvegardée (DataStore « Parcelles ») : au retour, le joueur la retrouve si elle est libre
-- sur ce serveur ; sinon il en reçoit une autre pour la session, sans perdre la sienne.
-- WorldService fait apparaître le joueur devant sa parcelle.
-- shortcut: au-delà de Mondes.plotCount joueurs, les suivants n'ont pas de parcelle (garder la taille du serveur ≤ 9).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Mondes = require(ReplicatedStorage.Shared.Config.Mondes)
local SocleKit = require(script.Parent.Parent.Data.SocleKit)

local PlotService = {}

local owners: { [number]: Player } = {}
local labels: { [number]: { TextLabel } } = {} -- un panneau par monde pour chaque parcelle, texte sur les deux faces

local WOOD = Color3.fromHex("#6B4426")

local store: DataStore? = nil
pcall(function() -- échoue en Studio sans « Enable Studio Access to API Services » : pas de sauvegarde
	store = DataStoreService:GetDataStore("Parcelles")
end)

-- Position du panneau dans le repère de la parcelle, à droite de l'entrée (vu depuis la place).
-- Monstres : juste après la bordure de l'allée. Héros : contre la face extérieure de la clôture de l'enclos
-- (avant à z = 34, portail entre x = ±7,6), hors de la parcelle ; ailleurs, rochers et lanternes gênent.
local SIGN = { heros = Vector3.new(19, 0, 34.6), monstres = Vector3.new(11, 0, Mondes.plotSize / 2 + 3) }

local function sign(parent: Instance, plot: CFrame, offset: Vector3, color: Color3, into: { TextLabel })
	local base = plot * CFrame.new(offset)
	local function part(size: Vector3, cf: CFrame, c: Color3): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Material = Enum.Material.Wood
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	part(Vector3.new(0.6, 4, 0.6), base * CFrame.new(0, 2, 0), WOOD)
	local board = part(Vector3.new(8, 3, 0.4), base * CFrame.new(0, 5, 0), WOOD)
	local edge = part(Vector3.new(8.4, 3.4, 0.3), base * CFrame.new(0, 5, 0), color) -- liseré à la couleur du monde
	edge.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = label
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = gui:Clone()
		g.Face = face
		g.Parent = board
		table.insert(into, g.TextLabel :: TextLabel)
	end
end

-- Socles des parcelles : modèle Blender (outils/blender/kit_socle.py), une MeshPart par couleur, cloné depuis
-- ServerStorage.Socle. 2 rangées de 5, allée centrale libre (23 studs).
-- Rangée gauche (vue de la place) Socle1..5 de l'entrée vers le fond, rangée droite Socle6..10.
local SOCLE = { x = 14, spacing = 10, first = 20 }
local FLOOR = { heros = 0, monstres = 0.8 } -- herbe des enclos / dessus des dalles de parcelle

local function socle(parent: Instance, name: string, base: CFrame, kit: Instance, rng: Random)
	local m = Instance.new("Model")
	m.Name = name
	-- quart de tour au hasard : les 180 socles ne se ressemblent pas tous
	local cf = base * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0)
	for _, p in SocleKit do
		local src = kit:FindFirstChild(`Socle__{p.label}`, true)
		if src and src:IsA("MeshPart") then
			local mp = src:Clone()
			mp.Name = p.label
			mp.Anchored = true
			mp.Size = p.size
			mp.CFrame = cf * CFrame.new(p.center) * CFrame.Angles(0, math.pi, 0) -- l'importateur FBX tourne les meshes d'un demi-tour
			mp.Color = p.color
			mp.Material = Enum.Material.SmoothPlastic
			mp.TextureID = ""
			if p.label == "SocleBrin" then -- brins : ni collision, ni ombre
				mp.CanCollide = false
				mp.CanQuery = false
				mp.CanTouch = false
				mp.CastShadow = false
			end
			mp.Parent = m
		end
	end
	m.WorldPivot = base
	m.Parent = parent
end

local function socles(parent: Instance, plot: CFrame, floorY: number, kit: Instance, rng: Random)
	local floor = plot * CFrame.new(0, floorY, 0)
	for row, sx in { -1, 1 } do
		for i = 1, 5 do
			local base = floor * CFrame.new(sx * SOCLE.x, 0, SOCLE.first - (i - 1) * SOCLE.spacing)
			socle(parent, `Socle{(row - 1) * 5 + i}`, base, kit, rng)
		end
	end
end

local function refresh(k: number)
	local owner = owners[k]
	for _, label in labels[k] do
		label.Text = if owner then `Parcelle de\n{owner.DisplayName}` else "Parcelle libre"
	end
end

local function take(player: Player, k: number)
	owners[k] = player
	player:SetAttribute(Mondes.plotAttribute, k)
	refresh(k)
end

local function assign(player: Player)
	local key = tostring(player.UserId)
	local saved: any = nil
	local readOk = false -- une lecture ratée ne doit jamais écraser la sauvegarde
	if store then
		local ok, value = pcall(store.GetAsync, store, key)
		readOk = ok
		saved = ok and value or nil
		if not ok then
			warn("Parcelles : lecture impossible pour", player.Name, value)
		end
	end
	if player.Parent ~= Players then
		return -- parti pendant la lecture
	end
	if type(saved) == "number" and saved >= 1 and saved <= Mondes.plotCount and not owners[saved] then
		take(player, saved)
		return
	end
	for k = 1, Mondes.plotCount do
		if not owners[k] then
			take(player, k)
			-- première parcelle : on la retient (une parcelle de dépannage n'écrase pas celle sauvegardée)
			if store and readOk and saved == nil then
				local ok, err = pcall(store.SetAsync, store, key, k)
				if not ok then
					warn("Parcelles : sauvegarde impossible pour", player.Name, err)
				end
			end
			return
		end
	end
end

local function release(player: Player)
	for k, owner in owners do
		if owner == player then
			owners[k] = nil
			refresh(k)
		end
	end
end

function PlotService:Init()
	local folder = Instance.new("Folder")
	folder.Name = "PanneauxParcelles"
	for k = 1, Mondes.plotCount do
		labels[k] = {}
		for _, monde in Mondes.list do
			sign(folder, Mondes.plot(monde.id, k) :: CFrame, SIGN[monde.id], monde.color, labels[k])
		end
		refresh(k)
	end
	folder.Parent = workspace

	local kit = ServerStorage:FindFirstChild("Socle")
	if kit then
		local all = Instance.new("Folder")
		all.Name = "SoclesParcelles"
		all.Parent = workspace
		for _, monde in Mondes.list do
			local world = Instance.new("Folder")
			world.Name = monde.id
			world.Parent = all
			for k = 1, Mondes.plotCount do
				local plot = Instance.new("Folder")
				plot.Name = `Parcelle{k}`
				socles(plot, Mondes.plot(monde.id, k) :: CFrame, FLOOR[monde.id] or 0, kit, Random.new(k))
				plot.Parent = world -- une parcelle à la fois : petits sous-arbres à insérer
			end
		end
	else
		warn("PlotService : ServerStorage.Socle manquant (importer ~/Desktop/jeux roblox ia /Blender/Socle.fbx), pas de socles")
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(assign, player) -- la lecture du DataStore attend
	end)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(assign, player)
	end
end

return PlotService
