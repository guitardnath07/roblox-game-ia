--!strict
-- Tour des défis : tours affichées dans le menu « Tours » et règles d'entrée. Seule source de vérité,
-- lue par le serveur (validation) et par le client (bannières). Le combat se déroule sur place, devant la tour.
-- Une tour par monde : le prompt de chaque entrée ouvre le menu de SA tour (étage de reprise et record séparés).
-- Réglages du combat (personnages, ennemis, butins) : Config/TowerCombat.

export type Tower = {
	id: string,
	name: string, -- nom affiché sur la bannière et le bandeau
	difficulty: string,
	difficultyColor: Color3,
	banner: string?, -- rbxassetid:// de l'illustration (facultatif : sinon fond dégradé + vue 3D de la tour)
	colors: { top: Color3, bottom: Color3 }, -- dégradé de fond de la bannière
	entrance: Vector3, -- devant la porte, utilisée si le modèle n'a pas de Part « ChallengeEntrance »
	model: { string }, -- chemin depuis Workspace du modèle de la tour (entrée + vue 3D de la bannière)
}

local ChallengeTower = {}

ChallengeTower.towers = table.freeze({
	{
		id = "defis",
		name = "Tour des défis",
		difficulty = "Facile",
		difficultyColor = Color3.fromHex("#5BFF4A"),
		banner = nil, -- ASSET À AJOUTER : illustration large (environ 16:5) de la Tour des défis
		colors = { top = Color3.fromHex("#6FC13A"), bottom = Color3.fromHex("#14260C") },
		entrance = Vector3.new(0, 3.5, -14), -- côté -Z
		model = { "Map", "Tower" },
	},
	{
		id = "monstres",
		name = "Tour des monstres",
		difficulty = "Facile", -- mêmes ennemis que la Tour des défis (Config/TowerCombat)
		difficultyColor = Color3.fromHex("#5BFF4A"),
		banner = nil, -- ASSET À AJOUTER : illustration large (environ 16:5) de la Tour des monstres
		colors = { top = Color3.fromHex("#B04CFF"), bottom = Color3.fromHex("#2A0F3A") },
		-- porte de la cathédrale (îlot du fond, Config/MondeMonstres.islets), façade tournée vers la place
		entrance = Vector3.new(2951, 227.6, -278),
		model = { "MondeMonstres", "Batiments", "Ilot1_cathedrale", "Cathedrale" },
	},
} :: { Tower })

ChallengeTower.promptDistance = 10 -- distance d'activation du ProximityPrompt
ChallengeTower.maxStartDistance = 24 -- distance max à l'entrée pour « Jouer » et « Combat »
ChallengeTower.menuSessionSeconds = 300 -- le menu ouvert à la tour reste valable ce temps-là
ChallengeTower.requestInterval = 0.5 -- secondes minimum entre deux demandes d'un même joueur

function ChallengeTower.get(id: any): Tower?
	for _, tower in ChallengeTower.towers do
		if tower.id == id then
			return tower
		end
	end
	return nil
end

-- Modèle de la tour dans la map (nil s'il n'est pas dans la place, ou pas encore chargé côté client).
function ChallengeTower.model(tower: Tower): Instance?
	local node: Instance? = workspace
	for _, name in tower.model do
		node = node and node:FindFirstChild(name)
	end
	return node
end

return table.freeze(ChallengeTower)
