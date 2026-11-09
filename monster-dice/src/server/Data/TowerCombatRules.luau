--!strict
-- Règles de la Tour des défis, sans dépendance au monde : entrée, ennemi d'un étage, meilleure équipe, butins.
-- Le service rassemble les faits puis s'en sert pour tous les calculs (rien n'est calculé côté client).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChallengeTower = require(ReplicatedStorage.Shared.Config.ChallengeTower)
local TowerCombat = require(ReplicatedStorage.Shared.Config.TowerCombat)

export type Fighter = { id: string, name: string, rarity: string, hp: number, maxHp: number, damage: number }
export type Drop = { id: string, amount: number }

local Rules = {}

Rules.messages = table.freeze({
	unknownTower = "Tour inconnue.",
	noSession = "Ouvre le menu depuis l'entrée de la tour.",
	notReady = "Ton personnage n'est pas prêt.",
	tooFar = "Rapproche-toi de l'entrée de la tour.",
	tooFast = "Patiente un instant avant de réessayer.",
	busy = "Un combat est déjà en cours.",
	badTeam = "Équipe invalide.",
})

-- Entrée : session ouverte au prompt de la tour, personnage vivant et assez proche.
function Rules.canEnter(sessionOpenedAt: number?, now: number, distance: number?, alive: boolean): (boolean, string?)
	local m = Rules.messages
	if not sessionOpenedAt or now - sessionOpenedAt > ChallengeTower.menuSessionSeconds then
		return false, m.noSession
	end
	if distance == nil or not alive then
		return false, m.notReady
	end
	if distance > ChallengeTower.maxStartDistance then
		return false, m.tooFar
	end
	return true, nil
end

function Rules.enemyFor(floor: number): Fighter
	local e = TowerCombat.enemy
	local scale = e.growth ^ (floor - 1)
	local rarity = "commun"
	for _, step in e.rarityEvery do
		if floor >= step[1] then
			rarity = step[2]
		end
	end
	local hp = math.floor(e.baseHp * scale)
	return {
		id = "ennemi",
		name = `Gardien {floor}`,
		rarity = rarity,
		hp = hp,
		maxHp = hp,
		damage = math.floor(e.baseDamage * scale),
	}
end

-- Puissance utilisée pour trier : PV + dégâts.
local function power(c: TowerCombat.Character): number
	return c.hp + c.damage
end

function Rules.bestTeam(roster: { TowerCombat.Character }): { string }
	local sorted = table.clone(roster)
	table.sort(sorted, function(a, b)
		return power(a) > power(b)
	end)
	local team = {}
	for i = 1, math.min(TowerCombat.teamSize, #sorted) do
		table.insert(team, sorted[i].id)
	end
	return team
end

-- Ids connus, sans doublon, entre 1 et teamSize.
function Rules.validTeam(team: { string }): boolean
	if #team < 1 or #team > TowerCombat.teamSize then
		return false
	end
	local seen = {}
	for _, id in team do
		if seen[id] or not TowerCombat.character(id) then
			return false
		end
		seen[id] = true
	end
	return true
end

function Rules.fighters(team: { string }): { Fighter }
	local list = {}
	for _, id in team do
		local c = TowerCombat.character(id)
		if c then
			table.insert(list, { id = c.id, name = c.name, rarity = c.rarity, hp = c.hp, maxHp = c.hp, damage = c.damage })
		end
	end
	return list
end

-- Tous les paliers atteints sont tirés indépendamment à chaque étage gagné.
function Rules.rollLoot(floor: number, rng: Random): { Drop }
	local drops = {}
	for _, tier in TowerCombat.loot do
		if floor >= tier.minFloor then
			for _, item in tier.items do
				if rng:NextNumber() < item.chance then
					table.insert(drops, { id = item.id, amount = item.amount or 1 })
				end
			end
		end
	end
	return drops
end

-- Auto-vérifications au chargement.
do
	local e1, e2 = Rules.enemyFor(1), Rules.enemyFor(2)
	assert(e1.hp == TowerCombat.enemy.baseHp and e2.hp > e1.hp and e1.rarity == "commun")
	assert(Rules.enemyFor(95).rarity == "legendaire")
	local best = Rules.bestTeam(TowerCombat.roster)
	assert(#best == TowerCombat.teamSize and best[1] == "p1" and not table.find(best, "p6"))
	assert(Rules.validTeam(best) and not Rules.validTeam({ "p1", "p1" }) and not Rules.validTeam({ "inconnu" }))
	assert(Rules.canEnter(10, 20, 5, true) and not Rules.canEnter(nil, 20, 5, true))
	assert(not Rules.canEnter(10, 20, ChallengeTower.maxStartDistance + 1, true))
end

return Rules
