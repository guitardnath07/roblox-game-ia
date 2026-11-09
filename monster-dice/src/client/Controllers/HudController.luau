--!strict
-- Branche le HUD principal. Interface seulement pour l'instant :
-- - argent, bonus d'amis et badges sont lus dans les attributs du joueur (Config/Hud.attributes) ;
--   les futurs systèmes serveur n'auront qu'à les remplir ;
-- - « Put Back » apparaît quand le personnage tient un objet (Tool) et le range dans l'inventaire ;
-- - « Hub » ramène au point de départ du monde en cours ; « Settings » ouvre le choix du monde ;
-- - « Monstres » / « Héros » téléportent directement dans ce monde (même demande serveur que Settings) ;
-- - Ultra Luck / Jackpot Roll ouvrent l'achat Robux si leur productId est renseigné ;
-- - les autres boutons ouvrent une fenêtre « Bientôt disponible » (EMPLACEMENT PROVISOIRE).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudConfig = require(ReplicatedStorage.Shared.Config.Hud)
local Mondes = require(ReplicatedStorage.Shared.Config.Mondes)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Format = require(ReplicatedStorage.Shared.Format)

local UI = script.Parent.Parent.UI
local S = require(UI.Tour.Style)
local Hud = require(UI.Hud.Hud)
local Parametres = require(UI.Hud.Parametres)

local HudController = {}

local player = Players.LocalPlayer
local attrs = HudConfig.attributes
local refs: Hud.Refs
local windowRoot: Frame
local closeWindow: (() -> ())? = nil

local toastToken = 0
local function toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	refs.toast.Text = text
	refs.toast.TextColor3 = color or Color3.new(1, 1, 1)
	refs.toast.TextTransparency = 0
	local stroke = refs.toast:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	task.delay(2.2, function()
		if token == toastToken then
			S.tween(refs.toast, 0.3, { TextTransparency = 1 })
			if stroke then
				S.tween(stroke, 0.3, { Transparency = 1 }) -- sinon le contour noir reste seul à l'écran
			end
		end
	end)
end

-- Fenêtre provisoire tant que le menu correspondant n'existe pas.
local function openWindow(title: string, color: Color3, dark: Color3)
	if closeWindow then
		closeWindow()
	end
	local panel = S.panel(windowRoot, Vector2.new(520, 280), Vector2.new(240, 140))
	local close = S.titleBar(panel, title, { close = true, color = color, dark = dark })
	S.text(panel, "Bientôt disponible", 34, { Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 44), strokeThickness = 3 })
	S.text(panel, "Ce menu arrive avec le prochain système.", 20, {
		TextColor3 = Color3.fromHex("#B9BCC6"),
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 30),
	})
	S.popIn(panel)
	local function destroy()
		panel:Destroy()
		closeWindow = nil
	end
	closeWindow = destroy
	if close then
		close.Activated:Connect(destroy)
	end
end

local function buy(key: string)
	local product = HudConfig.products[key]
	if product and product.productId then
		MarketplaceService:PromptProductPurchase(player, product.productId)
	else
		toast(`{product and product.name or key} : bientôt disponible`)
	end
end

-- Argent, bonus d'amis, badges : relus à chaque changement d'attribut.
-- Argent : le compteur défile jusqu'à la nouvelle valeur, un « +$… » s'envole à chaque gain.
local shownMoney = 0
local targetMoney = 0
local moneyTween: Tween? = nil
local moneyValue = Instance.new("NumberValue")
moneyValue.Changed:Connect(function(v)
	shownMoney = v
	refs.money.Text = "$" .. Format.precise(v)
end)

local function refresh()
	local money = tonumber(player:GetAttribute(attrs.money)) or 0
	if money ~= targetMoney then
		if money > targetMoney then
			Hud.floatText(refs.money, "+$" .. Format.precise(money - targetMoney), Color3.fromHex("#8CFF6A"))
		end
		targetMoney = money
		if moneyTween then
			moneyTween:Cancel()
		end
		moneyValue.Value = shownMoney
		moneyTween = S.tween(moneyValue, 0.6, { Value = money })
		Hud.bump(refs.money, 0.1)
	end
	local friend = tonumber(player:GetAttribute(attrs.friendBoost)) or 0
	refs.friend.Text = `Friend Boost +{math.floor(friend * 100 + 0.5)}%`
	local ready = tonumber(player:GetAttribute(attrs.upgradesReady)) or 0
	refs.upgradesBadge.Visible = ready > 0
	refs.upgradesBadgeText.Text = tostring(ready)
	refs.shopBadge.Visible = player:GetAttribute(attrs.shopAlert) == true
end

-- « Put Back » visible seulement quand le personnage tient un Tool.
local function watchCharacter(character: Model)
	local function update()
		refs.putBack.Visible = character:FindFirstChildOfClass("Tool") ~= nil
	end
	character.ChildAdded:Connect(update)
	character.ChildRemoved:Connect(update)
	update()
end

local spinning = false
local function spinDice()
	if spinning then
		return
	end
	spinning = true
	local dice = refs.dice
	S.tween(dice, 0.45, { Rotation = dice.Rotation + 360 }, Enum.EasingStyle.Back).Completed:Wait()
	dice.Rotation = -8
	spinning = false
end

-- Demande au serveur de changer de monde ; renvoie le message d'erreur à afficher (nil si réussi).
local function chooseWorld(id: string): string?
	local ok, response = pcall(Remotes.ChooseWorld.InvokeServer, Remotes.ChooseWorld, id)
	if ok and type(response) == "table" and response.ok then
		local monde = Mondes.get(id)
		toast(`Bienvenue dans le {monde and monde.name or "nouveau monde"} !`, Color3.fromHex("#FFE45C"))
		return nil
	end
	return if ok and type(response) == "table" and response.message then response.message else "Le serveur ne répond pas. Réessaie."
end

function HudController:Start()
	refs = Hud.build()
	local _, root = S.root("HudFenetres", 8)
	windowRoot = root
	local b = refs.buttons

	-- Hub : retour au point de départ du monde en cours.
	b.hub.Activated:Connect(function()
		local character = player.Character
		local spawn = Mondes.spawn(player:GetAttribute(Mondes.attribute) or Mondes.default)
		if character and spawn then
			character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
		end
	end)
	-- Settings : choix du monde, la téléportation est faite par le serveur.
	b.settings.Activated:Connect(function()
		if closeWindow then
			closeWindow()
		end
		local destroy = Parametres.open(windowRoot, player:GetAttribute(Mondes.attribute) or Mondes.default, {
			onChoose = function(id, setMessage)
				local message = chooseWorld(id)
				if not message then
					closeWindow = nil
					return true
				end
				setMessage(message)
				return false
			end,
			onClose = function()
				closeWindow = nil
			end,
		})
		closeWindow = destroy
	end)
	for button, id in { [b.mondeMonstres] = "monstres", [b.mondeHeros] = "heros" } do
		button.Activated:Connect(function()
			local message = chooseWorld(id)
			if message then
				toast(message, Color3.fromHex("#FF6B6B"))
			end
		end)
	end
	b.home.Activated:Connect(function()
		toast("Ta base arrive bientôt")
	end)
	b.putBack.Activated:Connect(function()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end)
	b.roll.Activated:Connect(function()
		task.spawn(spinDice)
		toast("Le tirage n'est pas encore branché")
	end)
	b.ultraLuck.Activated:Connect(function()
		buy("ultraLuck")
	end)
	b.jackpotRoll.Activated:Connect(function()
		buy("jackpotRoll")
	end)
	local windows = {
		{ b.shopTop, "Shop", S.VERT, S.VERT_FONCE },
		{ b.shop, "Shop", S.VERT, S.VERT_FONCE },
		{ b.rebirth, "Rebirth", S.ROUGE, S.ROUGE_FONCE },
		{ b.index, "Index", S.CYAN, S.CYAN_FONCE },
		{ b.upgrades, "Upgrades", S.VERT, S.VERT_FONCE },
		{ b.daily, "Daily Rewards", S.CYAN, S.CYAN_FONCE },
	}
	for _, w in windows do
		local button, title, color, dark = w[1] :: GuiButton, w[2] :: string, w[3] :: Color3, w[4] :: Color3
		button.Activated:Connect(function()
			openWindow(title, color, dark)
		end)
	end

	player.AttributeChanged:Connect(refresh)
	refresh()

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return HudController
