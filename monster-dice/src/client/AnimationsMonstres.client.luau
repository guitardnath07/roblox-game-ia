--!strict
-- Vie du monde des monstres (côté client, purement visuel), active seulement quand la caméra est sur l'île
-- (attribut Lighting.MondeMonstres posé par AmbianceMonstres) :
-- - rochers flottants qui montent, descendent et tournent ; cages qui se balancent ;
-- - flammes qui vacillent, colonnes de lumière qui respirent (tags posés par le générateur, Config.tags) ;
-- - chauves-souris autour de la Tour des monstres, feux follets sur la place, éclairs au loin.
-- Réglages : ReplicatedStorage.Shared.Config.MondeMonstres.animation.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.MondeMonstres)
local T = Config.tags
local A = Config.animation
local C = Config.colors
local O = Config.origin

local rng = Random.new()

local function active(): boolean
	return Lighting:GetAttribute("MondeMonstres") == true
end

-- Suit les objets d'un tag (y compris ceux qui arrivent plus tard avec le streaming).
local function watch<I>(tag: string, add: (I) -> (), remove: (I) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(add :: any)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove :: any)
	for _, i in CollectionService:GetTagged(tag) do
		add(i :: any)
	end
end

type Moving = { base: CFrame, phase: number, speed: number, amp: number }
local floaters: { [Model]: Moving } = {}
local swings: { [Model]: Moving & { hook: CFrame } } = {}
local flames: { [PointLight]: { base: number, seed: number } } = {}
local pulses: { [BasePart]: { base: number, phase: number } } = {}

watch(T.flotte, function(m: Model)
	floaters[m] = { base = m:GetPivot(), phase = rng:NextNumber(0, 6.3), speed = rng:NextNumber(0.5, 0.9), amp = rng:NextNumber(1.2, 3) }
end, function(m: Model)
	floaters[m] = nil
end)
watch(T.balance, function(m: Model)
	local hook = m:GetAttribute("Crochet")
	if typeof(hook) == "CFrame" then
		swings[m] = { base = m:GetPivot(), hook = hook, phase = rng:NextNumber(0, 6.3), speed = rng:NextNumber(1.1, 1.5), amp = math.rad(rng:NextNumber(5, 9)) }
	end
end, function(m: Model)
	swings[m] = nil
end)
watch(T.flamme, function(l: PointLight)
	flames[l] = { base = l.Brightness, seed = rng:NextNumber(0, 100) }
end, function(l: PointLight)
	flames[l] = nil
end)
watch(T.pulse, function(p: BasePart)
	pulses[p] = { base = p.Transparency, phase = rng:NextNumber(0, 6.3) }
end, function(p: BasePart)
	pulses[p] = nil
end)

-- Créatures et feux follets (créés ici, invisibles pour le serveur) ----------------------------------------

local old = Workspace:FindFirstChild("VieMonstres")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "VieMonstres"
folder.Parent = Workspace

local function piece(size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

-- centre de la Tour des monstres (même calcul que dir() dans le générateur)
local towerCentre = O
for _, spec in Config.islets do
	if spec.kind == "cathedrale" then
		local a = math.rad(spec.angle)
		towerCentre = O + Vector3.new(math.sin(a), 0, -math.cos(a)) * spec.dist + Vector3.new(0, spec.y, 0)
	end
end

type Bat = { body: Part, wings: { Part }, centre: Vector3, radius: number, height: number, speed: number, phase: number }
local bats: { Bat } = {}
local BAT = Color3.fromHex("#16111C")
for i = 1, A.bats do
	local aroundTower = i <= math.ceil(A.bats * 2 / 3)
	local body = piece(Vector3.new(0.9, 0.7, 1.4), BAT, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local wings = { piece(Vector3.new(2.4, 0.12, 1.3), BAT, Enum.Material.SmoothPlastic), piece(Vector3.new(2.4, 0.12, 1.3), BAT, Enum.Material.SmoothPlastic) }
	table.insert(bats, {
		body = body,
		wings = wings,
		centre = if aroundTower then towerCentre else O,
		radius = if aroundTower then rng:NextNumber(35, 95) else rng:NextNumber(90, 170),
		height = if aroundTower then rng:NextNumber(70, 170) else rng:NextNumber(45, 90),
		speed = rng:NextNumber(0.25, 0.5) * (if rng:NextNumber() < 0.5 then 1 else -1),
		phase = rng:NextNumber(0, 6.3),
	})
end

type Wisp = { part: Part, rx: number, rz: number, wx: number, wz: number, phase: number }
local wisps: { Wisp } = {}
for _ = 1, A.wisps do
	local p = piece(Vector3.new(0.9, 0.9, 0.9), C.teal, Enum.Material.Neon, Enum.PartType.Ball)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.35, 0), Vector3.new(0, -0.35, 0)
	a0.Parent, a1.Parent = p, p
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(C.teal, C.violet)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 1
	trail.Lifetime = 0.9
	trail.FaceCamera = true
	trail.Parent = p
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = C.teal, 10, 1.4
	l.Parent = p
	table.insert(wisps, { part = p, rx = rng:NextNumber(18, 52), rz = rng:NextNumber(18, 52), wx = rng:NextNumber(0.15, 0.35), wz = rng:NextNumber(0.15, 0.35), phase = rng:NextNumber(0, 6.3) })
end

-- Éclairs au loin : flash de l'image (effet sous la caméra pour ne pas gêner l'ambiance) + éclair néon -----

local flash = Instance.new("ColorCorrectionEffect")
flash.Name = "EclairMonstres"
flash.TintColor = Color3.fromHex("#E9DDFF")

local function lightning()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	flash.Parent = camera
	-- éclair en zigzag sur un grand cercle autour de l'île
	local a = rng:NextNumber(0, math.pi * 2)
	local pos = O + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(480, 700) + Vector3.new(0, 300, 0)
	local segments = {}
	for _ = 1, 8 do
		local nextPos = pos + Vector3.new(rng:NextNumber(-30, 30), -rng:NextNumber(35, 55), rng:NextNumber(-30, 30))
		local s = piece(Vector3.new(2.2, 2.2, (nextPos - pos).Magnitude), Color3.fromHex("#F1E8FF"), Enum.Material.Neon)
		s.CFrame = CFrame.lookAt((pos + nextPos) / 2, nextPos)
		table.insert(segments, s)
		pos = nextPos
	end
	flash.Brightness = 0.28
	task.wait(0.06)
	flash.Brightness = 0.05
	task.wait(0.08)
	flash.Brightness = 0.4
	TweenService:Create(flash, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	task.wait(0.18)
	for _, s in segments do
		s:Destroy()
	end
end

task.spawn(function()
	while true do
		task.wait(rng:NextNumber(A.lightning[1], A.lightning[2]))
		if active() then
			lightning()
		end
	end
end)

-- Boucle d'animation ------------------------------------------------------------------------------------------

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

RunService.Heartbeat:Connect(function()
	if not active() then
		return
	end
	local t = os.clock()
	for m, f in floaters do
		local y = math.sin(t * f.speed + f.phase) * f.amp
		m:PivotTo(f.base * CFrame.new(0, y, 0) * CFrame.Angles(0, math.sin(t * 0.1 + f.phase) * 0.6, 0))
	end
	for m, s in swings do
		local x = math.sin(t * s.speed + s.phase)
		m:PivotTo(s.hook * CFrame.Angles(x * s.amp * 0.4, 0, x * s.amp) * s.hook:Inverse() * s.base)
	end
	for l, f in flames do
		l.Brightness = f.base * (0.85 + math.noise(t * 5, f.seed) * 0.6)
	end
	for p, s in pulses do
		p.Transparency = s.base + (0.95 - s.base) * (0.5 + 0.5 * math.sin(t * 1.4 + s.phase)) * 0.6
	end

	table.clear(moveParts)
	table.clear(moveCFrames)
	for _, b in bats do
		local angle = t * b.speed + b.phase
		local pos = b.centre + Vector3.new(math.cos(angle) * b.radius, b.height + math.sin(t * 1.7 + b.phase) * 6, math.sin(angle) * b.radius)
		local ahead = b.centre + Vector3.new(math.cos(angle + 0.05 * math.sign(b.speed)) * b.radius, b.height, math.sin(angle + 0.05 * math.sign(b.speed)) * b.radius)
		local cf = CFrame.lookAt(pos, ahead) * CFrame.Angles(0, 0, -0.35 * math.sign(b.speed)) -- s'incline dans le virage
		local flap = math.sin(t * 16 + b.phase) * 0.8
		table.insert(moveParts, b.body)
		table.insert(moveCFrames, cf)
		for i, w in b.wings do
			local sx = if i == 1 then 1 else -1
			table.insert(moveParts, w)
			table.insert(moveCFrames, cf * CFrame.Angles(0, 0, sx * flap) * CFrame.new(sx * 1.4, 0, 0))
		end
	end
	for _, w in wisps do
		local pos = O + Vector3.new(math.cos(t * w.wx + w.phase) * w.rx, 3.5 + math.sin(t * 1.3 + w.phase) * 1.5, math.sin(t * w.wz + w.phase * 2) * w.rz)
		table.insert(moveParts, w.part)
		table.insert(moveCFrames, CFrame.new(pos))
	end
	Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end)
