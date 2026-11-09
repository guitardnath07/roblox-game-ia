--!strict
-- Aperçu 3D d'un personnage dans une carte (ViewportFrame).
-- Modèle : ReplicatedStorage.Personnages.<modele> s'il existe ; sinon EMPLACEMENT PROVISOIRE = l'avatar du joueur
-- (alliés) ou sa silhouette sombre (ennemis). À remplacer en ajoutant les vrais modèles dans
-- ReplicatedStorage.Personnages et en renseignant `modele` dans Config/TowerCombat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Apercu = {}

local function source(modele: string?): Model?
	local dossier = ReplicatedStorage:FindFirstChild("Personnages")
	local m = modele and dossier and dossier:FindFirstChild(modele)
	if m and m:IsA("Model") then
		return m
	end
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	character.Archivable = true
	return character
end

local function preparer(model: Model, silhouette: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			if d.Name == "HumanoidRootPart" then
				d.Transparency = 1
			end
			if silhouette then
				d.Color = Color3.fromHex("#1A1A20")
				d.Material = Enum.Material.SmoothPlastic
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			end
		elseif silhouette and (d:IsA("Decal") or d:IsA("Texture") or d:IsA("Clothing") or d:IsA("ShirtGraphic")) then
			d:Destroy()
		elseif silhouette and d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- Remplit `parent` avec un ViewportFrame cadré sur le personnage (de face, en pied).
function Apercu.create(parent: GuiObject, modele: string?, silhouette: boolean): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.ZIndex = parent.ZIndex
	vp.Ambient = Color3.fromRGB(170, 170, 180)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-0.4, -0.6, -1)
	vp.Parent = parent

	local src = source(modele)
	if not src then
		return vp
	end
	local model = src:Clone()
	preparer(model, silhouette)
	local world = Instance.new("WorldModel")
	world.Parent = vp
	model:PivotTo(CFrame.new())
	model.Parent = world

	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local hauteur = math.max(size.Y, size.X * 0.75)
	local distance = (hauteur / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.08
	-- Le modèle regarde vers -Z après PivotTo(CFrame.new()) : la caméra se place devant lui.
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0, -distance), cf.Position)
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp
end

return Apercu
