--!strict
-- Tour des défis — combat : raretés, personnages, ennemis par étage, rythme et butins.
-- Seule source de vérité, lue par le serveur (calculs, tirages) et le client (affichage des cartes et des butins).
--
-- ⚠️ DONNÉES DE DÉMONSTRATION : le jeu n'a pas encore de collection de personnages. `roster` ci-dessous est
-- l'équipe de test (stats des images de référence) ; à remplacer par la vraie collection du joueur.
-- Modèles 3D : si ReplicatedStorage.Personnages.<modele> existe, il s'affiche dans la carte ; sinon l'avatar
-- du joueur sert d'emplacement provisoire (alliés) ou sa silhouette sombre (ennemis).

export type Rarity = { id: string, name: string, color: Color3, rainbow: boolean? }
export type Character = { id: string, name: string, rarity: string, hp: number, damage: number, modele: string? }
export type Loot = {
	id: string,
	name: string,
	icon: string, -- forme dessinée : "potion", "gemme", "prisme", "tenue", "anneau"
	color: Color3,
	rarity: string,
	chance: number, -- probabilité de drop par étage gagné (0.02 = 2 %)
	amount: number?, -- quantité donnée (affiche « x3 »)
	image: string?, -- rbxassetid:// facultatif : remplace la forme dessinée quand l'icône existe
}
export type LootTier = { minFloor: number, items: { Loot } }

local TowerCombat = {}

TowerCombat.rarities = table.freeze({
	commun = { id = "commun", name = "Commun", color = Color3.fromHex("#9AA0A6") },
	rare = { id = "rare", name = "Rare", color = Color3.fromHex("#2F8CFF") },
	epique = { id = "epique", name = "Épique", color = Color3.fromHex("#A43CFF") },
	legendaire = { id = "legendaire", name = "Légendaire", color = Color3.fromHex("#FFB020") },
	mythique = { id = "mythique", name = "Mythique", color = Color3.fromHex("#FF4FD8"), rainbow = true },
	celeste = { id = "celeste", name = "Céleste", color = Color3.fromHex("#33E1FF") },
} :: { [string]: Rarity })

TowerCombat.teamSize = 4

-- DÉMO : collection de test. Les 4 premiers = stats des images de référence ; les 2 derniers servent à vérifier
-- que « Équiper les meilleurs » trie bien.
TowerCombat.roster = table.freeze({
	{ id = "p1", name = "Personnage 1", rarity = "mythique", hp = 7.7e15, damage = 6.4e15 },
	{ id = "p2", name = "Personnage 2", rarity = "legendaire", hp = 1e15, damage = 1e15 },
	{ id = "p3", name = "Personnage 3", rarity = "epique", hp = 65e12, damage = 65e12 },
	{ id = "p4", name = "Personnage 4", rarity = "celeste", hp = 48e6, damage = 48e6 },
	{ id = "p5", name = "Personnage 5", rarity = "rare", hp = 3e6, damage = 2e6 },
	{ id = "p6", name = "Personnage 6", rarity = "commun", hp = 5e4, damage = 2e4 },
} :: { Character })
TowerCombat.defaultTeam = { "p1", "p2", "p3", "p4" } -- équipe de départ ; ordre d'affichage = ordre de passage au combat

-- Ennemis : PV et dégâts de base multipliés par `growth` à chaque étage.
TowerCombat.enemy = table.freeze({
	baseHp = 1000,
	baseDamage = 25,
	growth = 1.3,
	rarityEvery = { { 1, "commun" }, { 20, "rare" }, { 50, "epique" }, { 90, "legendaire" }, { 150, "mythique" } },
})

TowerCombat.tickSeconds = 0.7 -- délai entre deux coups
TowerCombat.betweenFloorsSeconds = 0.9 -- pause entre deux étages en mode automatique

-- Butins par palier : tous les paliers atteints sont tirés à chaque étage gagné.
TowerCombat.loot = table.freeze({
	{
		minFloor = 1,
		items = {
			{ id = "potion_chance", name = "Potion de chance", icon = "potion", color = Color3.fromHex("#8BE33B"), rarity = "rare", chance = 0.02 },
			{ id = "potion_force", name = "Potion de force", icon = "potion", color = Color3.fromHex("#FF3B3B"), rarity = "rare", chance = 0.02 },
			{ id = "potion_or", name = "Potion d'or", icon = "potion", color = Color3.fromHex("#FFC21F"), rarity = "rare", chance = 0.02 },
			{ id = "gemme", name = "Gemme", icon = "gemme", color = Color3.fromHex("#C04BFF"), rarity = "epique", chance = 0.03 },
		},
	},
	{
		minFloor = 20,
		items = {
			{ id = "grande_potion_chance", name = "Grande potion de chance", icon = "potion", color = Color3.fromHex("#5ED12A"), rarity = "epique", chance = 0.015 },
			{ id = "grande_potion_force", name = "Grande potion de force", icon = "potion", color = Color3.fromHex("#E8222B"), rarity = "epique", chance = 0.015 },
		},
	},
	{
		minFloor = 50,
		items = {
			{ id = "elixir_chance", name = "Élixir de chance", icon = "potion", color = Color3.fromHex("#B7E82E"), rarity = "legendaire", chance = 0.01 },
			{ id = "elixir_force", name = "Élixir de force", icon = "potion", color = Color3.fromHex("#FF4A3D"), rarity = "legendaire", chance = 0.01 },
			{ id = "elixir_or", name = "Élixir d'or", icon = "potion", color = Color3.fromHex("#FFB020"), rarity = "legendaire", chance = 0.01 },
			{ id = "gemmes_x3", name = "Gemmes", icon = "gemme", color = Color3.fromHex("#E04BFF"), rarity = "celeste", chance = 0.01, amount = 3 },
			{ id = "prisme", name = "Prisme", icon = "prisme", color = Color3.fromHex("#FF4FD8"), rarity = "mythique", chance = 0.02 },
			{ id = "tenue", name = "Tenue céleste", icon = "tenue", color = Color3.fromHex("#F2F2F2"), rarity = "legendaire", chance = 0.0025 },
		},
	},
	{
		minFloor = 90,
		items = {
			{ id = "anneau", name = "Anneau du vide", icon = "anneau", color = Color3.fromHex("#9FD8FF"), rarity = "rare", chance = 0.0002 },
		},
	},
} :: { LootTier })

function TowerCombat.character(id: any): Character?
	for _, c in TowerCombat.roster do
		if c.id == id then
			return c
		end
	end
	return nil
end

function TowerCombat.lootItem(id: any): Loot?
	for _, tier in TowerCombat.loot do
		for _, item in tier.items do
			if item.id == id then
				return item
			end
		end
	end
	return nil
end

return table.freeze(TowerCombat)
