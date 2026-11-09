--!strict
-- Ambiance de la map (côté client, purement visuel) : ailes du moulin qui tournent, drapeau de la tour qui flotte,
-- cycle jour/nuit (lanternes, fenêtres et torches allumées la nuit seulement), papillons autour des fleurs le jour.
-- L'heure vient de workspace:GetServerTimeNow() : tous les joueurs voient la même heure sans réplication serveur.
-- Script autonome (pas un contrôleur) : ne dépend d'aucun autre module, il tourne même si le bootstrap client bloque.
-- Ne fait rien si Workspace.Map n'existe pas.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ROTOR_SPEED = 0.6 -- rad/s
local FLAG_SWAY = 0.25 -- rad

local CYCLE_SECONDS = 15 * 60 -- un jour complet
local DAY_SHARE = 0.7 -- part du cycle passée de 6 h à 18 h 30 ; la nuit défile plus vite
local LIGHTS_ON_AT = 18 -- heure d'allumage
local LIGHTS_OFF_AT = 6.3 -- heure d'extinction
local SWITCH_SPREAD = 4 -- secondes : les lampes s'allument une à une

-- Pièces néon allumées la nuit, et leur couleur « éteinte » le jour.
local DAY_COLORS: { [string]: Color3 } = {
	Lantern = Color3.fromHex("#8A7A5A"),
	TorchFlame = Color3.fromHex("#5A3A1E"),
	Window = Color3.fromHex("#A9C4D6"),
	GableWindow = Color3.fromHex("#A9C4D6"),
}

local DAY_LIGHTING = { ambient = Color3.fromRGB(150, 150, 160), brightness = 2.5, tint = Color3.new(1, 1, 1) }
local NIGHT_LIGHTING = { ambient = Color3.fromRGB(70, 80, 125), brightness = 1, tint = Color3.fromRGB(190, 205, 255) }

-- Heure (0-24) au temps serveur `t`.
local function clockAt(t: number): number
	local phase = (t % CYCLE_SECONDS) / CYCLE_SECONDS
	if phase < DAY_SHARE then
		return 6 + phase / DAY_SHARE * 12.5
	end
	return (18.5 + (phase - DAY_SHARE) / (1 - DAY_SHARE) * 11.5) % 24
end

-- 0 en plein jour, 1 en pleine nuit, transition douce au crépuscule et à l'aube.
local function nightness(clock: number): number
	if clock >= 17 and clock < 19 then
		return (clock - 17) / 2
	elseif clock >= 5.5 and clock < 7 then
		return 1 - (clock - 5.5) / 1.5
	end
	return (clock >= 19 or clock < 5.5) and 1 or 0
end

local function startDayNight(map: Instance)
	type Lamp = { set: (on: boolean) -> (), delay: number }
	-- Clés faibles : une lampe retirée par le streaming disparaît d'elle-même de la liste.
	local lamps: { [Instance]: Lamp } = setmetatable({}, { __mode = "k" }) :: any
	local pollen: { [ParticleEmitter]: true } = setmetatable({}, { __mode = "k" }) :: any
	local rng = Random.new()
	local lightsOn: boolean? = nil

	-- Avec le StreamingEnabled, la map arrive par morceaux (et revient après un streaming out) :
	-- chaque lampe est enregistrée à son arrivée et reçoit tout de suite l'état en cours.
	local function register(inst: Instance)
		local lamp: Lamp? = nil
		if inst:IsA("BasePart") and DAY_COLORS[inst.Name] and inst.Material == Enum.Material.Neon then
			local nightColor, dayColor = inst.Color, DAY_COLORS[inst.Name]
			lamp = {
				delay = rng:NextNumber(0, SWITCH_SPREAD),
				set = function(on)
					inst.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
					inst.Color = on and nightColor or dayColor
				end,
			}
		elseif
			inst:IsA("PointLight")
			or inst:IsA("Fire")
			or (inst:IsA("ParticleEmitter") and inst.Name == "Embers")
		then
			lamp = {
				delay = rng:NextNumber(0, SWITCH_SPREAD),
				set = function(on)
					inst.Enabled = on
				end,
			}
		elseif inst:IsA("ParticleEmitter") and inst.Name == "Pollen" then
			pollen[inst] = true
			if lightsOn ~= nil then
				inst.Rate = lightsOn and 10 or 4
			end
		end
		if lamp then
			lamps[inst] = lamp
			if lightsOn ~= nil then
				lamp.set(lightsOn)
			end
		end
	end
	for _, inst in map:GetDescendants() do
		register(inst)
	end
	map.DescendantAdded:Connect(register)
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")

	local function apply(on: boolean, instant: boolean)
		lightsOn = on
		for _, lamp in lamps do
			if instant then
				lamp.set(on)
			else
				task.delay(lamp.delay, function()
					if lightsOn == on then -- ignore un changement annulé entre-temps
						lamp.set(on)
					end
				end)
			end
		end
		for emitter in pollen do
			emitter.Rate = on and 10 or 4 -- lucioles plus nombreuses la nuit
		end
	end

	RunService.Heartbeat:Connect(function()
		if Lighting:GetAttribute("MondeMonstres") then
			return -- l'île des monstres impose son crépuscule (AmbianceMonstres)
		end
		local clock = clockAt(Workspace:GetServerTimeNow())
		Lighting.ClockTime = clock
		local n = nightness(clock)
		Lighting.OutdoorAmbient = DAY_LIGHTING.ambient:Lerp(NIGHT_LIGHTING.ambient, n)
		Lighting.Brightness = DAY_LIGHTING.brightness + (NIGHT_LIGHTING.brightness - DAY_LIGHTING.brightness) * n
		if correction then
			correction.TintColor = DAY_LIGHTING.tint:Lerp(NIGHT_LIGHTING.tint, n)
		end
		local on = clock >= LIGHTS_ON_AT or clock < LIGHTS_OFF_AT
		if on ~= lightsOn then
			apply(on, lightsOn == nil)
		end
	end)
end

-- Papillons : créés côté client (rien ne transite par le réseau), ils voltigent autour des fleurs proches de la caméra,
-- se posent de temps en temps, changent de fleur, et disparaissent la nuit.
local BUTTERFLY_COUNT = 28
local BUTTERFLY_RANGE = 110 -- studs autour de la caméra
local FLOWER_PREFIXES = { "Tulips", "Daisies", "Lavender", "FlowerBush", "YellowBush" }
local WING_COLORS = {
	Color3.fromHex("#F28C28"),
	Color3.fromHex("#4A8CF0"),
	Color3.fromHex("#F4F4F4"),
	Color3.fromHex("#FFD93D"),
	Color3.fromHex("#FF8FB1"),
}

local function isFlower(name: string): boolean
	for _, prefix in FLOWER_PREFIXES do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function startButterflies(map: Instance)
	local rng = Random.new()
	local folder = Instance.new("Folder")
	folder.Name = "Butterflies"

	local function part(size: Vector3, color: Color3): BasePart
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size, p.Color, p.Material = size, color, Enum.Material.SmoothPlastic
		p.Parent = folder
		return p
	end

	type Butterfly = {
		body: BasePart,
		left: BasePart,
		right: BasePart,
		pos: Vector3,
		home: Vector3?,
		switchAt: number,
		restUntil: number,
		seed: number,
		yaw: number,
	}
	local butterflies: { Butterfly } = {}
	for _ = 1, BUTTERFLY_COUNT do
		local wing = WING_COLORS[rng:NextInteger(1, #WING_COLORS)]
		table.insert(butterflies, {
			body = part(Vector3.new(0.14, 0.14, 0.55), Color3.fromHex("#2B2B2B")),
			left = part(Vector3.new(0.6, 0.04, 0.55), wing),
			right = part(Vector3.new(0.6, 0.04, 0.55), wing),
			pos = Vector3.zero,
			home = nil,
			switchAt = 0,
			restUntil = 0,
			seed = rng:NextNumber(0, 100),
			yaw = 0,
		})
	end

	-- Fleurs proches de la caméra (rafraîchies régulièrement : la map arrive par streaming).
	local flowers: { Vector3 } = {}
	local function refreshFlowers(around: Vector3)
		table.clear(flowers)
		local plants = map:FindFirstChild("Plants")
		if not plants then
			return
		end
		for _, plant in plants:GetChildren() do
			if plant:IsA("Model") and isFlower(plant.Name) then
				local cf, size = plant:GetBoundingBox()
				local top = Vector3.new(cf.X, cf.Y + size.Y / 2, cf.Z) -- sommet de la fleur
				if (top - around).Magnitude < BUTTERFLY_RANGE then
					table.insert(flowers, top)
				end
			end
		end
	end

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local sinceRefresh = math.huge
	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local clock = Lighting.ClockTime
		local day = clock >= 6.5 and clock < 18.5
		if not day or not camera then
			folder.Parent = nil
			return
		end
		local camPos = camera.CFrame.Position
		sinceRefresh += dt
		if sinceRefresh > 5 then
			sinceRefresh = 0
			refreshFlowers(camPos)
		end
		if #flowers == 0 then
			folder.Parent = nil
			return
		end
		folder.Parent = Workspace

		local t = os.clock()
		table.clear(parts)
		table.clear(cframes)
		for _, b in butterflies do
			local home = b.home
			if not home or t > b.switchAt or (home - camPos).Magnitude > BUTTERFLY_RANGE * 1.3 then
				local newHome = flowers[rng:NextInteger(1, #flowers)]
				if not home then
					b.pos = newHome + Vector3.new(0, 1, 0) -- apparition directement sur une fleur
				end
				b.home, home = newHome, newHome
				b.switchAt = t + rng:NextNumber(6, 16)
				if rng:NextNumber() < 0.35 then
					b.restUntil = t + rng:NextNumber(2, 5) -- se pose sur la fleur
				end
			end
			local at = home :: Vector3 -- toujours défini ici (choisi juste au-dessus)
			local resting = t < b.restUntil
			local s = b.seed
			local target = resting and at + Vector3.new(0, 0.15, 0)
				or at
					+ Vector3.new(
						math.sin(t * 0.9 + s) * 2.4,
						1.2 + math.sin(t * 1.7 + s * 2) * 0.6,
						math.cos(t * 1.1 + s * 3) * 2.4
					)
			local previous = b.pos
			b.pos = previous:Lerp(target, math.min(1, dt * (resting and 4 or 2.2)))
			local move = b.pos - previous
			if move.Magnitude > 1e-3 then
				b.yaw = math.atan2(-move.X, -move.Z)
			end
			-- battement : rapide en vol, lent et ailes ouvertes une fois posé
			local flap = resting and (0.25 + math.sin(t * 3 + s) * 0.2) or (math.sin(t * 22 + s) * 0.9 + 0.2)
			local bodyCf = CFrame.new(b.pos) * CFrame.Angles(0, b.yaw, 0)
			table.insert(parts, b.body)
			table.insert(cframes, bodyCf)
			table.insert(parts, b.left)
			table.insert(cframes, bodyCf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.33, 0, 0))
			table.insert(parts, b.right)
			table.insert(cframes, bodyCf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.33, 0, 0))
		end
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

local function start()
	local map = Workspace:WaitForChild("Map", 10)
	if not map then
		return
	end
	startDayNight(map)
	startButterflies(map)

	-- Moulin et drapeau : recherchés à nouveau tant qu'ils ne sont pas arrivés (streaming) ou s'ils ont été retirés.
	local rotor: Model?, hubStart: CFrame?, rotorOffset: CFrame?
	local pole: BasePart?
	local flags: { BasePart } = {}
	local flagOffsets: { CFrame } = {}
	local function resolve()
		if not (rotor and rotor.Parent) then
			local windmill = map:FindFirstChild("Windmill")
			local found = windmill and windmill:FindFirstChild("Rotor") :: Model?
			local hub = found and found.PrimaryPart
			rotor, hubStart, rotorOffset = nil, nil, nil
			if found and hub then
				rotor, hubStart = found, hub.CFrame
				rotorOffset = hub.CFrame:ToObjectSpace(found:GetPivot())
			end
		end
		if not (pole and pole.Parent) then
			local tower = map:FindFirstChild("Tower")
			local detail = tower and tower:FindFirstChild("Detail")
			pole = detail and detail:FindFirstChild("FlagPole") :: BasePart?
			flags, flagOffsets = {}, {}
			if detail and pole then
				for _, name in { "Flag", "FlagStripe" } do
					local part = detail:FindFirstChild(name)
					if part and part:IsA("BasePart") then
						table.insert(flags, part)
						table.insert(
							flagOffsets,
							CFrame.new(pole.Position.X, part.Position.Y, pole.Position.Z):ToObjectSpace(part.CFrame)
						)
					end
				end
			end
		end
	end
	resolve()

	local angle = 0
	local sinceResolve = 0
	RunService.RenderStepped:Connect(function(dt)
		angle += dt * ROTOR_SPEED
		sinceResolve += dt
		if sinceResolve > 1 then
			sinceResolve = 0
			resolve()
		end
		if rotor and hubStart and rotorOffset then
			rotor:PivotTo(hubStart * CFrame.Angles(0, 0, angle) * rotorOffset)
		end
		if pole then
			local sway = math.sin(os.clock() * 2) * FLAG_SWAY
			for i, flag in flags do
				local base = CFrame.new(pole.Position.X, flag.Position.Y, pole.Position.Z)
				flag.CFrame = base * CFrame.Angles(0, sway, 0) * flagOffsets[i]
			end
		end
	end)
end

start()
