--!strict
-- Choix du monde (héros ou monstres) : valide la demande du client, retient le choix dans l'attribut
-- Player.Monde et téléporte le joueur devant sa parcelle dans ce monde (point d'arrivée du monde s'il n'en a pas).
-- À chaque apparition, le joueur est remis devant sa parcelle (le SpawnLocation de Roblox reste celui des héros).
-- shortcut: le choix ne dure que la session ; à brancher sur les sauvegardes quand elles existeront.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mondes = require(ReplicatedStorage.Shared.Config.Mondes)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RateLimit = require(script.Parent.Parent.Data.RateLimit)

local WorldService = {}

local REQUEST_INTERVAL = 1 -- secondes minimum entre deux changements de monde

local limiter = RateLimit.new()

-- Devant la parcelle du joueur, côté place, tourné vers elle ; sinon le point d'arrivée du monde.
local function arrival(player: Player): CFrame?
	local id = player:GetAttribute(Mondes.attribute)
	local plot = Mondes.plot(id, player:GetAttribute(Mondes.plotAttribute) :: any)
	if plot then
		return plot * CFrame.new(0, 5, Mondes.plotSize / 2 + 8)
	end
	local spawn = Mondes.spawn(id)
	return spawn and spawn.CFrame + Vector3.new(0, 4, 0)
end

local function teleport(player: Player): boolean
	local target = arrival(player)
	local character = player.Character
	if not target or not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return false
	end
	character:PivotTo(target)
	return true
end

local function onChoose(player: Player, id: any): { ok: boolean, message: string? }
	if not limiter:allow(player, REQUEST_INTERVAL) then
		return { ok = false, message = "Attends un instant avant de changer de monde." }
	end
	local monde = Mondes.get(id)
	if not monde then
		return { ok = false, message = "Monde inconnu." }
	end
	if not Mondes.spawn(monde.id) then
		return { ok = false, message = "Ce monde n'est pas encore construit." }
	end
	player:SetAttribute(Mondes.attribute, monde.id)
	if not teleport(player) then
		return { ok = false, message = "Téléportation impossible pour l'instant, réessaie." }
	end
	return { ok = true }
end

local function track(player: Player)
	if player:GetAttribute(Mondes.attribute) == nil then
		player:SetAttribute(Mondes.attribute, Mondes.default)
	end
	player.CharacterAdded:Connect(function()
		task.defer(teleport, player) -- laisse Roblox placer le personnage, puis le ramène devant sa parcelle
	end)
	-- la parcelle arrive après la lecture de la sauvegarde, parfois une fois le personnage déjà là
	player:GetAttributeChangedSignal(Mondes.plotAttribute):Connect(function()
		teleport(player)
	end)
end

function WorldService:Init()
	Remotes.ChooseWorld.OnServerInvoke = onChoose
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return WorldService
