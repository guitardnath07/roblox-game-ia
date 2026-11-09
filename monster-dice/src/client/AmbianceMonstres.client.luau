--!strict
-- Ambiance du monde des monstres (côté client, purement visuel) : quand la caméra entre dans la zone de l'île
-- flottante, l'éclairage passe en douceur au rendu de jour lavande (proche de la map des héros, brume légère) ;
-- en sortant, il revient à l'état d'avant et le cycle jour/nuit reprend (Ambience).
-- Le ciel clair (skybox rendue dans Blender, Config/KitMonstres.sky) et le soleil de Roblox remplacent le ciel
-- du monde des héros pendant le séjour sur l'île.
-- Réglages : ReplicatedStorage.Shared.Config.MondeMonstres.lighting.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.MondeMonstres)
local Kit = require(ReplicatedStorage.Shared.Config.KitMonstres)
local L = Config.lighting

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Parent = Lighting
local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
correction.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "BloomMonstres"
bloom.Enabled = false
bloom.Intensity, bloom.Size, bloom.Threshold = 0, L.bloom.Size, L.bloom.Threshold
bloom.Parent = Lighting
-- rayons du soleil couchant et léger flou au loin, actifs seulement sur l'île
local sunRays = Instance.new("SunRaysEffect")
sunRays.Name = "RayonsMonstres"
sunRays.Enabled = false
sunRays.Intensity, sunRays.Spread = 0, L.sunRays.Spread
sunRays.Parent = Lighting
local depth = Instance.new("DepthOfFieldEffect")
depth.Name = "ProfondeurMonstres"
depth.Enabled = false
depth.FarIntensity, depth.NearIntensity = 0, 0
depth.FocusDistance, depth.InFocusRadius = L.depthOfField.FocusDistance, L.depthOfField.InFocusRadius
depth.Parent = Lighting

-- Ciel du monde des monstres ; le ciel d'origine (s'il y en a un) est mis de côté pendant le séjour.
local sky = Instance.new("Sky")
sky.Name = "CielMonstres"
for face, id in Kit.sky do
	(sky :: any)[face] = id
end
sky.CelestialBodiesShown = true -- le soleil blanc de Roblox, aligné sur la direction de la lumière
sky.SunAngularSize = 14
sky.StarCount = 0
local heroSkies: { Instance } = {}

local function useMonsterSky(on: boolean)
	if on then
		for _, s in Lighting:GetChildren() do
			if s:IsA("Sky") and s ~= sky then
				table.insert(heroSkies, s)
				s.Parent = nil
			end
		end
		sky.Parent = Lighting
	else
		sky.Parent = nil
		for _, s in heroSkies do
			s.Parent = Lighting
		end
		table.clear(heroSkies)
	end
end

type Saved = { [Instance]: { [string]: any } }
local saved: Saved? = nil
local tweens: { Tween } = {}

local function play(o: Instance, props: { [string]: any })
	local t = TweenService:Create(o, TweenInfo.new(L.fadeSeconds, Enum.EasingStyle.Sine), props)
	table.insert(tweens, t)
	t:Play()
end

local function target(): { [Instance]: { [string]: any } }
	return {
		[Lighting] = {
			ClockTime = L.clockTime,
			Brightness = L.brightness,
			ExposureCompensation = L.exposure,
			EnvironmentDiffuseScale = L.environmentScale,
			EnvironmentSpecularScale = L.environmentScale,
			Ambient = L.ambient,
			OutdoorAmbient = L.outdoorAmbient,
			FogColor = L.fogColor,
		},
		[atmosphere] = L.atmosphere,
		[correction] = { TintColor = L.tint, Saturation = L.saturation, Contrast = L.contrast },
		[bloom] = { Intensity = L.bloom.Intensity, Size = L.bloom.Size, Threshold = L.bloom.Threshold },
		[sunRays] = { Intensity = L.sunRays.Intensity },
		[depth] = { FarIntensity = L.depthOfField.FarIntensity },
	}
end

local function enter()
	for _, t in tweens do
		t:Cancel()
	end
	table.clear(tweens)
	-- mémorise l'état courant pour le restaurer à la sortie
	local snapshot: Saved = {}
	for o, props in target() do
		snapshot[o] = {}
		for k in props do
			snapshot[o][k] = (o :: any)[k]
		end
	end
	saved = snapshot
	useMonsterSky(true)
	Lighting:SetAttribute("MondeMonstres", true)
	bloom.Enabled = true
	sunRays.Enabled = true
	depth.Enabled = true
	for o, props in target() do
		play(o, props)
	end
end

local function leave()
	for _, t in tweens do
		t:Cancel()
	end
	table.clear(tweens)
	local snapshot = saved
	saved = nil
	if snapshot then
		for o, props in snapshot do
			if o == Lighting then
				-- l'heure, la luminosité et l'ambiance extérieure sont reprises chaque image par Ambience
				Lighting.Ambient = props.Ambient
				Lighting.FogColor = props.FogColor
				Lighting.ExposureCompensation = props.ExposureCompensation
				Lighting.EnvironmentDiffuseScale = props.EnvironmentDiffuseScale
				Lighting.EnvironmentSpecularScale = props.EnvironmentSpecularScale
			else
				play(o, props)
			end
		end
	end
	Lighting:SetAttribute("MondeMonstres", nil)
	useMonsterSky(false)
	task.delay(L.fadeSeconds, function()
		if not saved then
			bloom.Enabled = false
			sunRays.Enabled = false
			depth.Enabled = false
		end
	end)
end

-- Vérifie la position de la caméra deux fois par seconde.
while true do
	local camera = Workspace.CurrentCamera
	if camera then
		local inside = (camera.CFrame.Position - Config.origin).Magnitude < Config.zoneRadius
		if inside and not saved then
			enter()
		elseif not inside and saved then
			leave()
		end
	end
	task.wait(0.5)
end
