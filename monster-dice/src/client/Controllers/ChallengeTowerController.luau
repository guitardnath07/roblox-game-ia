--!strict
-- Tour des défis côté client : enchaîne les écrans Menu « Tours » -> « Ton équipe » + « Butins » -> Combat.
-- Toutes les décisions passent par le serveur (Remotes) ; ici on affiche et on transmet les clics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChallengeTower = require(ReplicatedStorage.Shared.Config.ChallengeTower)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local UI = script.Parent.Parent.UI.Tour
local S = require(UI.Style)
local Menu = require(UI.Menu)
local Equipe = require(UI.Equipe)
local Combat = require(UI.Combat)

local ChallengeTowerController = {}

local root: Frame
local closeWindow: (() -> ())? = nil -- menu ou équipe ouvert
local combat: Combat.View? = nil
local team: { string } = {}
local tower = ChallengeTower.towers[1]

local function closeCurrent()
	if closeWindow then
		closeWindow()
		closeWindow = nil
	end
end

local function failure(ok: boolean, response: any): string?
	if ok and type(response) == "table" and response.ok then
		return nil
	end
	return if ok and type(response) == "table" and type(response.message) == "string"
		then response.message
		else "Le serveur ne répond pas. Réessaie."
end

local openTeam: () -> ()

local function openMenu(shown: ChallengeTower.Tower)
	closeCurrent()
	closeWindow = Menu.open(root, shown, {
		onPlay = function(chosen, setMessage)
			local ok, response = pcall(Remotes.ChallengeTowerPlay.InvokeServer, Remotes.ChallengeTowerPlay, chosen.id)
			local message = failure(ok, response)
			if message then
				setMessage(message)
				return
			end
			tower = chosen
			team = response.team
			openTeam()
		end,
		onClose = function()
			closeWindow = nil
			Remotes.ChallengeTowerClosed:FireServer()
		end,
	})
end

function openTeam()
	closeCurrent()
	closeWindow = Equipe.open(root, tower, team, {
		onClose = function()
			closeWindow = nil
			Remotes.ChallengeTowerClosed:FireServer()
		end,
		onEquipBest = function()
			local ok, ids = pcall(Remotes.TowerEquipBest.InvokeServer, Remotes.TowerEquipBest)
			if ok and type(ids) == "table" then
				team = ids
				return ids
			end
			return nil
		end,
		onFight = function(setMessage)
			local ok, response = pcall(Remotes.TowerFight.InvokeServer, Remotes.TowerFight)
			local message = failure(ok, response)
			if message then
				setMessage(message)
				return
			end
			closeCurrent() -- l'écran de combat s'ouvre au message « start »
		end,
	})
end

local function onState(msg: any)
	if type(msg) ~= "table" then
		return
	end
	if msg.kind == "start" then
		closeCurrent()
		if combat then
			combat.destroy()
		end
		combat = Combat.open(root, {
			onQuit = function()
				Remotes.TowerQuit:FireServer()
			end,
			onAuto = function(on)
				Remotes.TowerSetAuto:FireServer(on)
			end,
		})
	end
	local view = combat
	if not view then
		return
	end
	if msg.kind == "stop" then
		combat = nil
		if msg.reason == "defeat" then
			view.handle(msg) -- affiche « Défaite » un instant
			task.delay(1.8, view.destroy)
		else
			view.destroy()
		end
		if msg.reason == "pause" then
			openTeam() -- auto désactivé : retour à l'équipe, « Combat » reprend à l'étage suivant
		end
		return
	end
	view.handle(msg)
end

function ChallengeTowerController:Start()
	local _, r = S.root("TourDesDefis", 10)
	root = r
	Remotes.ChallengeTowerOpen.OnClientEvent:Connect(function(towerId)
		local shown = ChallengeTower.get(towerId)
		if shown and not combat and not closeWindow then
			openMenu(shown)
		end
	end)
	Remotes.TowerState.OnClientEvent:Connect(onState)
end

return ChallengeTowerController
