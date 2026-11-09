--!strict
-- Mondes jouables, choisis dans les paramètres. Seule source de vérité, lue par le serveur (validation,
-- téléportation) et par le client (fenêtre Settings, bouton Hub).
-- Le monde choisi est l'attribut `Monde` du Player (réglé par le serveur uniquement).

local MondeMonstres = require(script.Parent.MondeMonstres)

export type Monde = {
	id: string,
	name: string,
	description: string,
	icon: string, -- emoji affiché sur la carte (EMPLACEMENT PROVISOIRE tant que `image` est vide)
	image: string?, -- rbxassetid:// d'une illustration, quand elle existe
	color: Color3,
	dark: Color3,
	spawn: { string }, -- chemin depuis Workspace du point d'arrivée (une BasePart)
	origin: Vector3, -- centre de la place (sol) : les parcelles l'entourent
}

local Mondes = {}

Mondes.attribute = "Monde"
Mondes.default = "heros"

Mondes.list = table.freeze({
	{
		id = "heros",
		name = "Monde des héros",
		description = "Le village et la Tour des défis",
		icon = "🛡️",
		color = Color3.fromHex("#3DB8F5"),
		dark = Color3.fromHex("#1B5C9C"),
		spawn = { "Map", "SpawnLocation" },
		origin = Vector3.zero,
	},
	{
		id = "monstres",
		name = "Monde des monstres",
		description = "L'île flottante gothique",
		icon = "👹",
		color = Color3.fromHex("#FF8A1F"),
		dark = Color3.fromHex("#7A2A10"),
		spawn = { "MondeMonstres", "SpawnMonstres" },
		origin = MondeMonstres.origin,
	},
} :: { Monde })

function Mondes.get(id: any): Monde?
	for _, m in Mondes.list do
		if m.id == id then
			return m
		end
	end
	return nil
end

-- Point d'arrivée du monde (nil si la map n'est pas dans la place).
function Mondes.spawn(id: any): BasePart?
	local m = Mondes.get(id)
	if not m then
		return nil
	end
	local node: Instance? = workspace
	for _, name in m.spawn do
		node = node and node:FindFirstChild(name)
	end
	return if node and node:IsA("BasePart") then node else nil
end

-- Parcelles : mêmes angles et rayons dans les deux mondes (enclos de la map des héros, dalles de l'île).
-- La parcelle k d'un joueur est la même dans chaque monde (attribut Player.Parcelle, réglé par le serveur).
Mondes.plotAttribute = "Parcelle"
Mondes.plotCount = MondeMonstres.plots.count
Mondes.plotSize = MondeMonstres.plots.size

-- Repère au sol du centre de la parcelle k (1..plotCount) : -Z vers l'extérieur, +Z vers la place.
function Mondes.plot(id: any, k: any): CFrame?
	local m = Mondes.get(id)
	if not m or type(k) ~= "number" then
		return nil
	end
	local P = MondeMonstres.plots
	local a = math.rad((k - 1) * P.angleStep)
	local d = Vector3.new(math.cos(a), 0, math.sin(a))
	local c = m.origin + d * (P.inner + P.outer) / 2
	return CFrame.lookAt(c, c + d)
end

return table.freeze(Mondes)
