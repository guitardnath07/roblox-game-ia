--!strict
-- Affichage du combat (le décor 3D reste visible derrière) : « Étage N » en haut, carte alliée à gauche, carte
-- ennemie à droite, barres de vie, dégâts rouges animés, frappe (la carte avance et grossit), « Cacher »,
-- « Quitter », « Automatique ». Ne calcule rien : il rejoue les messages TowerState envoyés par le serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerCombat = require(ReplicatedStorage.Shared.Config.TowerCombat)
local Format = require(ReplicatedStorage.Shared.Format)
local S = require(script.Parent.Style)
local Apercu = require(script.Parent.Apercu)

local Combat = {}

export type Callbacks = { onQuit: () -> (), onAuto: (boolean) -> () }
export type View = { handle: (msg: { [string]: any }) -> (), destroy: () -> () }

local CARTE = Vector2.new(228, 312)
local CENTRE_ALLIE, CENTRE_ENNEMI = Vector2.new(318, 278), Vector2.new(682, 278)

type Side = {
	holder: Frame,
	card: Frame,
	scale: UIScale,
	fill: Frame,
	hpText: TextLabel,
	damageText: TextLabel,
	stroke: UIStroke?,
	maxHp: number,
	home: UDim2,
}

local function side(parent: Frame, centre: Vector2): Side
	local holder = S.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(CARTE.X, CARTE.Y + 52),
		Position = UDim2.fromOffset(centre.X, centre.Y),
		Parent = parent,
	})
	local scale = S.new("UIScale", { Parent = holder })
	local card = S.new("Frame", {
		BackgroundColor3 = S.CARTE,
		BackgroundTransparency = 0.08,
		Size = UDim2.fromOffset(CARTE.X, CARTE.Y),
		Parent = holder,
	})
	S.corner(card, 10)
	local damageText = S.text(card, "", 30, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(78, CARTE.Y - 50),
		Size = UDim2.new(1, -84, 0, 40),
		ZIndex = 4,
		strokeThickness = 3,
	})
	S.swordIcon(card, 36, Vector2.new(34, CARTE.Y - 48), 4)

	-- Barre de vie verte sous la carte, PV restants au centre.
	local bar = S.new("Frame", {
		BackgroundColor3 = Color3.fromHex("#1C1C1F"),
		Size = UDim2.fromOffset(CARTE.X + 24, 36),
		Position = UDim2.fromOffset(-12, CARTE.Y + 12),
		Parent = holder,
	})
	S.corner(bar, 7)
	S.stroke(bar, S.NOIR, 3)
	local fill = S.new("Frame", { BackgroundColor3 = S.BLANC, Size = UDim2.fromScale(1, 1), Parent = bar })
	S.corner(fill, 7)
	S.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#8DF56A")),
			ColorSequenceKeypoint.new(0.55, Color3.fromHex("#3CC424")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#2A9A18")),
		}),
		Parent = fill,
	})
	local hpText = S.text(bar, "", 26, { ZIndex = 3, strokeThickness = 2.5 })
	return {
		holder = holder,
		card = card,
		scale = scale,
		fill = fill,
		hpText = hpText,
		damageText = damageText,
		maxHp = 1,
		home = holder.Position,
	}
end

-- Habille la carte avec un combattant (aperçu 3D, contour de rareté, dégâts, PV).
local function show(s: Side, fighter: { [string]: any }, silhouette: boolean)
	for _, d in s.card:GetChildren() do
		if d.Name == "Vue" or d:IsA("UIStroke") then
			d:Destroy()
		end
	end
	S.rarityStroke(s.card, fighter.rarity, 3)
	local vue = S.new("Frame", {
		Name = "Vue",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 8),
		Size = UDim2.new(1, -12, 1, -62),
		ZIndex = 2,
		Parent = s.card,
	})
	local c = TowerCombat.character(fighter.id)
	Apercu.create(vue, c and c.modele, silhouette)
	s.damageText.Text = Format.big(fighter.damage)
	s.maxHp = math.max(fighter.maxHp, 1)
	s.fill.Size = UDim2.fromScale(math.clamp(fighter.hp / s.maxHp, 0, 1), 1)
	s.hpText.Text = Format.big(fighter.hp)
end

local function setHp(s: Side, hp: number)
	S.tween(s.fill, 0.25, { Size = UDim2.fromScale(math.clamp(hp / s.maxHp, 0, 1), 1) })
	s.hpText.Text = Format.big(hp)
end

-- Frappe : la carte avance vers l'adversaire en grossissant, puis revient.
local function strike(attacker: Side, direction: number)
	attacker.holder.ZIndex = 5
	S.tween(attacker.scale, 0.12, { Scale = 1.12 })
	S.tween(attacker.holder, 0.12, { Position = attacker.home + UDim2.fromOffset(direction * 110, -8) }).Completed:Wait()
	S.tween(attacker.scale, 0.2, { Scale = 1 })
	S.tween(attacker.holder, 0.2, { Position = attacker.home }, Enum.EasingStyle.Back)
	task.delay(0.2, function()
		attacker.holder.ZIndex = 1
	end)
end

-- Grand nombre rouge « -253qd » qui jaillit sur la carte touchée.
local function damageNumber(parent: Frame, target: Side, amount: number)
	local label = S.text(parent, "-" .. Format.big(amount), 58, {
		TextColor3 = Color3.fromHex("#FF3B3B"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = target.home + UDim2.fromOffset(0, -40),
		Size = UDim2.fromOffset(320, 70),
		ZIndex = 10,
		strokeThickness = 4,
	})
	local scale = S.new("UIScale", { Scale = 0.4, Parent = label })
	S.tween(scale, 0.18, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.delay(0.18, function()
		S.tween(scale, 0.12, { Scale = 1 })
	end)
	S.tween(label, 0.9, { Position = target.home + UDim2.fromOffset(0, -95) })
	task.delay(0.55, function()
		S.tween(label, 0.35, { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			S.tween(stroke, 0.35, { Transparency = 1 })
		end
	end)
	task.delay(0.95, function()
		label:Destroy()
	end)
end

function Combat.open(root: Frame, callbacks: Callbacks): View
	local layer = S.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	local floor = S.text(layer, "Étage 1", 60, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(500, 8),
		Size = UDim2.fromOffset(600, 70),
		strokeThickness = 4,
	})
	local floorScale = S.new("UIScale", { Parent = floor })
	local toast = S.text(layer, "", 22, {
		TextColor3 = Color3.fromHex("#FFE45C"),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(500, 74),
		Size = UDim2.fromOffset(700, 30),
	})

	local arena = S.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = layer })
	local ally, enemy = side(arena, CENTRE_ALLIE), side(arena, CENTRE_ENNEMI)

	-- « Cacher » : masque les cartes pour voir le décor.
	local hide = S.new("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(500, 452),
		Size = UDim2.fromOffset(110, 60),
		Parent = layer,
	})
	S.magnifierIcon(hide, 32, Vector2.new(39, 0), 2)
	local hideLabel = S.text(hide, "Cacher", 20, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 26), ZIndex = 2 })
	local quit = S.button(layer, "Quitter", S.ROUGE, S.ROUGE_FONCE, Vector2.new(196, 56), Vector2.new(296, 500 - 8), 30)
	local auto, paintAuto = S.button(layer, "Automatique", S.VERT, S.VERT_FONCE, Vector2.new(196, 56), Vector2.new(508, 500 - 8), 25)

	local autoOn = true
	local function refreshAuto()
		if autoOn then
			paintAuto(S.VERT, S.VERT_FONCE)
		else
			paintAuto(S.GRIS, S.GRIS_FONCE)
		end
	end
	auto.Activated:Connect(function()
		autoOn = not autoOn
		refreshAuto()
		callbacks.onAuto(autoOn)
	end)
	quit.Activated:Connect(callbacks.onQuit)
	hide.Activated:Connect(function()
		arena.Visible = not arena.Visible
		hideLabel.Text = if arena.Visible then "Cacher" else "Afficher"
	end)

	local allies: { { [string]: any } } = {}
	local current = 1

	local function setFloor(n: number)
		floor.Text = `Étage {n}`
		floorScale.Scale = 1.25
		S.tween(floorScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	local function handle(msg: { [string]: any })
		local kind = msg.kind
		if kind == "start" then
			allies, current = msg.allies, msg.current
			autoOn = msg.auto
			refreshAuto()
			setFloor(msg.floor)
			show(ally, allies[current], false)
			show(enemy, msg.enemy, true)
		elseif kind == "hit" then
			local attacker, target = if msg.by == "ally" then ally else enemy, if msg.by == "ally" then enemy else ally
			task.spawn(strike, attacker, if msg.by == "ally" then 1 else -1)
			task.delay(0.12, function()
				damageNumber(arena, target, msg.amount)
				setHp(ally, msg.allyHp)
				setHp(enemy, msg.enemyHp)
			end)
		elseif kind == "ally" then
			current = msg.current
			local a = allies[current]
			if a then
				show(ally, a, false)
			end
		elseif kind == "cleared" then
			local noms = {}
			for _, drop in msg.drops do
				local item = TowerCombat.lootItem(drop.id)
				if item then
					table.insert(noms, if drop.amount > 1 then `{item.name} x{drop.amount}` else item.name)
				end
			end
			toast.Text = if #noms > 0 then "Butin : " .. table.concat(noms, ", ") else ""
		elseif kind == "floor" then
			setFloor(msg.floor)
			show(enemy, msg.enemy, true)
		elseif kind == "stop" and msg.reason == "defeat" then
			toast.TextColor3 = Color3.fromHex("#FF4A4A")
			toast.Text = `Défaite à l'étage {msg.floor} — record : étage {msg.best}`
		end
	end

	local function destroy()
		layer:Destroy()
	end
	return { handle = handle, destroy = destroy }
end

return Combat
