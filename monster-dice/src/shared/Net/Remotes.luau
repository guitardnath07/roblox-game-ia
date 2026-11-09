--!strict
-- Tous les remotes du jeu, déclarés ici et nulle part ailleurs.
-- Le serveur les crée dans ReplicatedStorage.Remotes ; le client les attend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder: Instance
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local function remote(className: string, name: string): Instance
	if RunService:IsServer() then
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = folder
		return instance
	end
	return folder:WaitForChild(name)
end

local function event(name: string): RemoteEvent
	return remote("RemoteEvent", name) :: RemoteEvent
end

local function func(name: string): RemoteFunction
	return remote("RemoteFunction", name) :: RemoteFunction
end

return table.freeze({
	-- Tour des défis. serveur -> client : (towerId: string) ouvre le menu de cette tour (le joueur a utilisé son entrée).
	ChallengeTowerOpen = event("ChallengeTowerOpen"),
	-- client -> serveur, renvoie { ok: boolean, message: string?, team: { string }? } : (arenaId: string) choisit
	-- la tour (bouton « Jouer »). Le serveur vérifie la session, la distance et le personnage, puis renvoie l'équipe.
	ChallengeTowerPlay = func("ChallengeTowerPlay"),
	-- client -> serveur : les fenêtres ont été fermées sans partir (la session d'ouverture est annulée).
	ChallengeTowerClosed = event("ChallengeTowerClosed"),
	-- client -> serveur, renvoie { string } (ids de l'équipe) : « Équiper les meilleurs ».
	TowerEquipBest = func("TowerEquipBest"),
	-- client -> serveur, renvoie { ok: boolean, message: string? } : « Combat » (téléporte et lance le combat).
	TowerFight = func("TowerFight"),
	-- client -> serveur : « Quitter » pendant le combat.
	TowerQuit = event("TowerQuit"),
	-- client -> serveur : (auto: boolean) enchaîner les étages automatiquement.
	TowerSetAuto = event("TowerSetAuto"),
	-- serveur -> client : (state: table) déroulé du combat (voir TowerCombatService, champ `kind`).
	TowerState = event("TowerState"),

	-- Mondes. client -> serveur, renvoie { ok: boolean, message: string? } : (mondeId: string) choisir son monde
	-- dans les paramètres ; le serveur vérifie, retient le choix (attribut Player.Monde) et téléporte le joueur.
	ChooseWorld = func("ChooseWorld"),
})
