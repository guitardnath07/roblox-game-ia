--!strict
-- Préparation : fenêtre « Ton équipe » (4 cartes, « Équiper les meilleurs », « Combat ») et panneau « Butins »
-- (récompenses par palier d'étage, défilant). Toutes les valeurs viennent de Config/TowerCombat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChallengeTower = require(ReplicatedStorage.Shared.Config.ChallengeTower)
local TowerCombat = require(ReplicatedStorage.Shared.Config.TowerCombat)
local Format = require(ReplicatedStorage.Shared.Format)
local S = require(script.Parent.Style)
local Apercu = require(script.Parent.Apercu)

local Equipe = {}

export type Callbacks = {
	onClose: () -> (),
	onEquipBest: () -> { string }?,
	onFight: (setMessage: (string?) -> ()) -> (),
}

local CARTE = Vector2.new(128, 184)

-- Carte de personnage : PV (cœur) en haut, aperçu 3D au centre, dégâts (épée) en bas.
function Equipe.card(parent: Instance, c: TowerCombat.Character, position: Vector2): Frame
	local card = S.new("Frame", {
		BackgroundColor3 = S.CARTE,
		Size = UDim2.fromOffset(CARTE.X, CARTE.Y),
		Position = UDim2.fromOffset(position.X, position.Y),
		Parent = parent,
	})
	S.corner(card, 8)
	S.rarityStroke(card, c.rarity, 3)
	-- Léger halo de rareté au fond de la carte.
	local glow = S.new("Frame", {
		BackgroundColor3 = (TowerCombat.rarities[c.rarity] or TowerCombat.rarities.commun).color,
		BackgroundTransparency = 0.82,
		Size = UDim2.fromScale(1, 1),
		Parent = card,
	})
	S.corner(glow, 8)
	S.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = glow,
	})
	local vue = S.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 34),
		Size = UDim2.new(1, -8, 1, -70),
		ZIndex = 2,
		Parent = card,
	})
	Apercu.create(vue, c.modele, false)
	S.heartIcon(card, 24, Vector2.new(14, 8), 3)
	S.text(card, Format.big(c.hp), 22, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(44, 6),
		Size = UDim2.new(1, -48, 0, 28),
		ZIndex = 3,
	})
	S.swordIcon(card, 26, Vector2.new(12, CARTE.Y - 33), 3)
	S.text(card, Format.big(c.damage), 22, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(44, CARTE.Y - 34),
		Size = UDim2.new(1, -48, 0, 28),
		ZIndex = 3,
	})
	return card
end

local function lootCell(parent: Instance, item: TowerCombat.Loot, order: number)
	local cell = S.new("Frame", { BackgroundColor3 = Color3.fromHex("#1B1B21"), LayoutOrder = order, Parent = parent })
	S.corner(cell, 8)
	S.rarityStroke(cell, item.rarity, 3)
	S.lootIcon(cell, item, 74, Vector2.new(15, 6), 2)
	S.text(cell, Format.percent(item.chance), 17, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(7, 76),
		Size = UDim2.new(1, -10, 0, 22),
		ZIndex = 3,
	})
	if item.amount and item.amount > 1 then
		S.text(cell, "x" .. item.amount, 17, {
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(0, 76),
			Size = UDim2.new(1, -7, 0, 22),
			ZIndex = 3,
		})
	end
end

local function butins(root: Frame): Frame
	local panel = S.panel(root, Vector2.new(262, 420), Vector2.new(694, 70))
	S.titleBar(panel, "Butins", {})
	local list = S.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 66),
		Size = UDim2.new(1, -12, 1, -74),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = S.CONTOUR,
		Parent = panel,
	})
	S.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	S.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = list })
	for i, tier in TowerCombat.loot do
		local header = S.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 44),
			LayoutOrder = i * 2 - 1,
			Parent = list,
		})
		S.text(header, `Étage {tier.minFloor}+`, 26, { Size = UDim2.new(1, 0, 0, 36) })
		S.line(header, 40, 22)
		local grid = S.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i * 2,
			Parent = list,
		})
		S.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(104, 104),
			CellPadding = UDim2.fromOffset(12, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		})
		S.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = grid })
		for j, item in tier.items do
			lootCell(grid, item, j)
		end
	end
	return panel
end

function Equipe.open(root: Frame, tower: ChallengeTower.Tower, team: { string }, callbacks: Callbacks): () -> ()
	local panel = S.panel(root, Vector2.new(620, 420), Vector2.new(58, 70))
	local close = S.titleBar(panel, tower.name, { icon = true, close = true })
	S.text(panel, "Ton équipe", 36, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 46), strokeThickness = 3 })
	S.line(panel, 116, 40)

	local cartes = S.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, CARTE.Y), Position = UDim2.fromOffset(0, 128), Parent = panel })
	local function drawTeam(ids: { string })
		cartes:ClearAllChildren()
		local n = TowerCombat.teamSize
		local gap = 14
		local x0 = (620 - (n * CARTE.X + (n - 1) * gap)) / 2
		for i = 1, n do
			local c = TowerCombat.character(ids[i])
			local pos = Vector2.new(x0 + (i - 1) * (CARTE.X + gap), 0)
			if c then
				Equipe.card(cartes, c, pos)
			else -- emplacement vide
				local vide = S.new("Frame", { BackgroundColor3 = S.CARTE, BackgroundTransparency = 0.4, Size = UDim2.fromOffset(CARTE.X, CARTE.Y), Position = UDim2.fromOffset(pos.X, pos.Y), Parent = cartes })
				S.corner(vide, 8)
				S.stroke(vide, S.CONTOUR, 2, 0.3)
			end
		end
	end
	drawTeam(team)

	S.line(panel, 326, 40)
	local message = S.text(panel, "", 16, { TextColor3 = Color3.fromHex("#FF6B6B"), Position = UDim2.fromOffset(0, 396), Size = UDim2.new(1, 0, 0, 20) })
	local equip = S.button(panel, "Équiper les meilleurs", S.VERT, S.VERT_FONCE, Vector2.new(236, 54), Vector2.new(84, 338), 23)
	local fight = S.button(panel, "", S.CYAN, S.CYAN_FONCE, Vector2.new(214, 54), Vector2.new(334, 338))
	S.swordIcon(fight, 38, Vector2.new(18, 8), 2)
	S.text(fight, "Combat", 32, { Font = S.BOUTON, Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -64, 1, 0), ZIndex = 2 })

	local side = butins(root)
	S.popIn(panel)
	S.popIn(side)

	local closed = false
	local function destroy()
		if not closed then
			closed = true
			panel:Destroy()
			side:Destroy()
		end
	end
	if close then
		close.Activated:Connect(function()
			destroy()
			callbacks.onClose()
		end)
	end
	equip.Activated:Connect(function()
		local ids = callbacks.onEquipBest()
		if ids and not closed then
			drawTeam(ids)
		end
	end)
	local busy = false
	fight.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		message.Text = ""
		callbacks.onFight(function(text: string?)
			message.Text = text or ""
		end)
		busy = false
	end)
	return destroy
end

return Equipe
