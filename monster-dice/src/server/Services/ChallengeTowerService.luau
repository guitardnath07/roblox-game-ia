--!strict
-- Tours des défis (une par monde, Config/ChallengeTower) : entrée devant la porte de chaque tour, préparation
-- de l'équipe, combat par étages SUR PLACE.
--
-- Le menu ne s'ouvre que par le ProximityPrompt de la tour, déclenché CÔTÉ SERVEUR : le serveur note l'heure
-- d'ouverture (« session ») et la tour de ce prompt, et les exige pour « Jouer » et « Combat ». Le client n'envoie que des intentions
-- (id de tour, « équiper les meilleurs », « combat », « quitter », « auto ») : équipe, PV, dégâts, étages et
-- butins sont calculés ici (règles : Data/TowerCombatRules, réglages : Config/TowerCombat).
--
-- Messages TowerState envoyés au client (champ `kind`) :
--   start   { floor, allies: { Fighter }, current, enemy: Fighter, auto }
--   hit     { by: "ally" | "enemy", amount, allyHp, enemyHp }
--   ally    { current }                      -- l'allié actuel est tombé, le suivant entre
--   cleared { floor, drops: { Drop } }       -- étage gagné, butins accordés
--   floor   { floor, enemy: Fighter }        -- étage suivant (mode automatique)
--   stop    { reason: "pause" | "defeat" | "quit", floor, best }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ChallengeTower = require(Shared.Config.ChallengeTower)
local TowerCombat = require(Shared.Config.TowerCombat)
local Remotes = require(Shared.Net.Remotes)

local Rules = require(script.Parent.Parent.Data.TowerCombatRules)
local RateLimit = require(script.Parent.Parent.Data.RateLimit)

type Response = { ok: boolean, message: string?, team: { string }?, nextFloor: number? }
type Combat = {
	tower: string,
	floor: number,
	allies: { Rules.Fighter },
	current: number,
	enemy: Rules.Fighter,
	running: boolean,
}
type State = {
	session: number?, -- os.clock() d'ouverture du menu à la tour
	tower: string?, -- id de la dernière tour ouverte ; l'étage de reprise lui appartient
	team: { string },
	auto: boolean,
	nextFloor: number, -- reprise après une pause (auto désactivé)
	combat: Combat?,
}

local states: { [Player]: State } = {}
local limiter = RateLimit.new()
local entrances: { [string]: BasePart } = {}
local rng = Random.new()

local ChallengeTowerService = {}

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = { team = table.clone(TowerCombat.defaultTeam), auto = true, nextFloor = 1 }
		states[player] = s
	end
	return s
end

local function send(player: Player, message: { [string]: any })
	if player.Parent then
		Remotes.TowerState:FireClient(player, message)
	end
end

-- Faits sur le personnage : distance à l'entrée (nil sans personnage) et vivant.
local function facts(player: Player): (number?, boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local tower = stateOf(player).tower
	local entrance = tower and entrances[tower]
	local alive = humanoid ~= nil and humanoid.Health > 0
	local distance = if root and root:IsA("BasePart") and entrance
		then (root.Position - entrance.Position).Magnitude
		else nil
	return distance, alive
end

local function canEnter(player: Player): (boolean, string?)
	local distance, alive = facts(player)
	return Rules.canEnter(stateOf(player).session, os.clock(), distance, alive)
end

-- shortcut: butins rangés dans Player.TourButins (IntValue par objet), perdus à la déconnexion ;
-- à brancher sur la sauvegarde (DataStore / ProfileStore) quand le jeu en aura une.
local function grant(player: Player, drops: { Rules.Drop })
	local folder = player:FindFirstChild("TourButins")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TourButins"
		folder.Parent = player
	end
	assert(folder, "dossier de butins")
	for _, drop in drops do
		local value = folder:FindFirstChild(drop.id)
		if not (value and value:IsA("IntValue")) then
			value = Instance.new("IntValue")
			value.Name = drop.id
			value.Parent = folder
		end
		assert(value and value:IsA("IntValue"))
		value.Value += drop.amount
	end
end

local function stop(player: Player, reason: string)
	local s = stateOf(player)
	local c = s.combat
	if not c then
		return
	end
	c.running = false
	s.combat = nil
	if reason == "pause" then
		s.nextFloor = c.floor + 1
		s.session = os.clock() -- la fenêtre d'équipe se rouvre : « Combat » reste autorisé
	else
		s.nextFloor = 1
	end
	send(player, { kind = "stop", reason = reason, floor = c.floor, best = player:GetAttribute(`TourMeilleurEtage_{c.tower}`) or 0 })
end

local function runCombat(player: Player, c: Combat)
	local s = stateOf(player)
	send(player, { kind = "start", floor = c.floor, allies = c.allies, current = c.current, enemy = c.enemy, auto = s.auto })
	while true do
		task.wait(TowerCombat.tickSeconds)
		if not c.running then
			return
		end
		-- L'allié frappe.
		local ally = c.allies[c.current]
		c.enemy.hp = math.max(0, c.enemy.hp - ally.damage)
		send(player, { kind = "hit", by = "ally", amount = ally.damage, allyHp = ally.hp, enemyHp = c.enemy.hp })
		if c.enemy.hp <= 0 then
			local drops = Rules.rollLoot(c.floor, rng)
			grant(player, drops)
			local bestKey = `TourMeilleurEtage_{c.tower}`
			if c.floor > (player:GetAttribute(bestKey) or 0) then
				player:SetAttribute(bestKey, c.floor)
			end
			send(player, { kind = "cleared", floor = c.floor, drops = drops })
			if not s.auto then
				stop(player, "pause")
				return
			end
			task.wait(TowerCombat.betweenFloorsSeconds)
			if not c.running then
				return
			end
			c.floor += 1
			c.enemy = Rules.enemyFor(c.floor)
			send(player, { kind = "floor", floor = c.floor, enemy = c.enemy })
		else
			-- L'ennemi riposte.
			task.wait(TowerCombat.tickSeconds)
			if not c.running then
				return
			end
			ally.hp = math.max(0, ally.hp - c.enemy.damage)
			send(player, { kind = "hit", by = "enemy", amount = c.enemy.damage, allyHp = ally.hp, enemyHp = c.enemy.hp })
			if ally.hp <= 0 then
				c.current += 1
				if c.current > #c.allies then
					stop(player, "defeat")
					return
				end
				send(player, { kind = "ally", current = c.current })
			end
		end
	end
end

local function onPlay(player: Player, towerId: any): Response
	if not limiter:allow(player, ChallengeTower.requestInterval) then
		return { ok = false, message = Rules.messages.tooFast }
	end
	if not ChallengeTower.get(towerId) then
		return { ok = false, message = Rules.messages.unknownTower }
	end
	local ok, message = canEnter(player)
	if not ok then
		return { ok = false, message = message }
	end
	local s = stateOf(player)
	if towerId ~= s.tower then
		return { ok = false, message = Rules.messages.unknownTower }
	end
	return { ok = true, team = s.team, nextFloor = s.nextFloor }
end

local function onEquipBest(player: Player): { string }
	local s = stateOf(player)
	if s.session and not s.combat then
		s.team = Rules.bestTeam(TowerCombat.roster)
	end
	return s.team
end

local function onFight(player: Player): Response
	if not limiter:allow(player, ChallengeTower.requestInterval) then
		return { ok = false, message = Rules.messages.tooFast }
	end
	local s = stateOf(player)
	if s.combat then
		return { ok = false, message = Rules.messages.busy }
	end
	local ok, message = canEnter(player)
	if not ok then
		return { ok = false, message = message }
	end
	if not Rules.validTeam(s.team) then
		return { ok = false, message = Rules.messages.badTeam }
	end
	s.session = nil -- une ouverture = un départ
	local c: Combat = {
		tower = s.tower :: string, -- canEnter a trouvé l'entrée de cette tour
		floor = s.nextFloor,
		allies = Rules.fighters(s.team),
		current = 1,
		enemy = Rules.enemyFor(s.nextFloor),
		running = true,
	}
	s.combat = c
	task.spawn(runCombat, player, c)
	return { ok = true }
end

-- Entrée : Part « ChallengeEntrance » placée dans le modèle de la tour, sinon une Part invisible devant la porte.
local function ensureEntrance(tower: ChallengeTower.Tower): BasePart
	local model = ChallengeTower.model(tower)
	local existing = model and model:FindFirstChild("ChallengeEntrance", true)
	local anchor: BasePart
	if existing and existing:IsA("BasePart") then
		anchor = existing
	else
		local p = Instance.new("Part")
		p.Name = "ChallengeEntrance"
		p.Anchored, p.CanCollide, p.CanTouch, p.Transparency = true, false, false, 1
		p.Size = Vector3.new(6, 6, 2)
		p.Position = tower.entrance
		p.Parent = model or Workspace
		anchor = p
	end
	local prompt = anchor:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "ChallengeTowerPrompt"
	prompt.ActionText = "Entrer"
	prompt.ObjectText = tower.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = ChallengeTower.promptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		local s = stateOf(player)
		if s.combat then
			return
		end
		if s.tower ~= tower.id then
			s.nextFloor = 1 -- une pause dans l'autre tour ne se reprend pas ici
		end
		s.tower = tower.id
		s.session = os.clock()
		Remotes.ChallengeTowerOpen:FireClient(player, tower.id)
	end)
	return anchor
end

function ChallengeTowerService:Init()
	Remotes.ChallengeTowerPlay.OnServerInvoke = onPlay
	Remotes.TowerEquipBest.OnServerInvoke = onEquipBest
	Remotes.TowerFight.OnServerInvoke = onFight
	Remotes.ChallengeTowerClosed.OnServerEvent:Connect(function(player)
		stateOf(player).session = nil
	end)
	Remotes.TowerQuit.OnServerEvent:Connect(function(player)
		stop(player, "quit")
	end)
	Remotes.TowerSetAuto.OnServerEvent:Connect(function(player, auto)
		if type(auto) == "boolean" then
			stateOf(player).auto = auto
		end
	end)
	local function track(player: Player)
		player.CharacterRemoving:Connect(function()
			stop(player, "quit") -- mort ou réapparition : le combat s'arrête
		end)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local s = states[player]
		if s and s.combat then
			s.combat.running = false
		end
		states[player] = nil
		limiter:forget(player)
	end)
end

function ChallengeTowerService:Start()
	for _, tower in ChallengeTower.towers do
		entrances[tower.id] = ensureEntrance(tower)
	end
	-- Les anciennes arènes ne servent plus (combat sur place).
	local old = Workspace:FindFirstChild("ChallengeArenas")
	if old then
		old:Destroy()
	end
end

return ChallengeTowerService
