--!strict
-- HUD principal, d'après la capture de référence (écran 1280 × 720) :
-- haut centre Hub / Home / Shop, gauche Shop / Rebirth / Index (+ à côté Monde 1 Monstres / Monde 2 Héros),
-- bas centre Settings / Roll / Upgrades
-- (+ « Put Back » au-dessus), bas gauche argent + Friend Boost, droite Ultra Luck / Jackpot Roll,
-- haut droite Daily Rewards.
-- Style : boutons en relief (socle sombre décalé, biseau clair, reflet, éclat qui balaie la surface),
-- textes à gros contour noir avec ombre portée, halos et rayons tournants derrière les offres, petites
-- animations au repos (dé qui oscille, flèche qui flotte, badges qui pulsent) et réaction au survol / clic.
-- Chaque groupe est accroché à son bord d'écran et mis à l'échelle (UIScale) : la composition de la
-- référence est conservée sur ordinateur et rétrécit sans chevauchement sur tablette et téléphone.
-- Ne fait qu'afficher : le comportement est branché par HudController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HudConfig = require(ReplicatedStorage.Shared.Config.Hud)
local Mondes = require(ReplicatedStorage.Shared.Config.Mondes)
local S = require(script.Parent.Parent.Tour.Style)

local Hud = {}

local FONT = Enum.Font.FredokaOne
local NOIR = Color3.new(0, 0, 0)
local BLANC = Color3.new(1, 1, 1)

export type Refs = {
	gui: ScreenGui,
	buttons: { [string]: GuiButton },
	putBack: Frame,
	dice: Frame,
	money: TextLabel,
	friend: TextLabel,
	upgradesBadge: Frame,
	upgradesBadgeText: TextLabel,
	shopBadge: Frame,
	toast: TextLabel,
}

-- Animations au repos : une seule boucle pour tout le HUD.
local animations: { (t: number) -> () } = {}
local function animate(fn: (t: number) -> ())
	table.insert(animations, fn)
end
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, fn in animations do
		fn(t)
	end
end)

local function darker(c: Color3, k: number): Color3
	return c:Lerp(NOIR, k)
end
local function lighter(c: Color3, k: number): Color3
	return c:Lerp(BLANC, k)
end

local function frame(parent: Instance, props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or BLANC
	props.BorderSizePixel = 0
	props.Parent = parent
	return S.new("Frame", props)
end

local function gradient(parent: Instance, colors: { Color3 }, rotation: number?): UIGradient
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), c))
	end
	return S.new("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(keys), Parent = parent })
end

local function fade(parent: Instance, points: { { number } }, rotation: number?): UIGradient
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return S.new("UIGradient", { Rotation = rotation or 90, Transparency = NumberSequence.new(keys), Parent = parent })
end

-- Texte blanc (ou coloré) à gros contour noir + ombre portée noire décalée vers le bas.
local function label(parent: Instance, text: string, size: number, props: { [string]: any }?): TextLabel
	local p = props or {}
	local z = p.ZIndex or 2
	local thickness = p.strokeThickness or math.max(2, size / 10)
	local base = {
		Font = p.Font or FONT,
		TextXAlignment = p.TextXAlignment,
		Size = p.Size,
		AnchorPoint = p.AnchorPoint,
		strokeThickness = thickness,
	}
	if p.shadow ~= false then
		local sp = table.clone(base)
		sp.TextColor3 = NOIR
		sp.ZIndex = z - 1
		local pos = p.Position or UDim2.new()
		sp.Position = pos + UDim2.fromOffset(0, math.max(2, size / 12))
		local shadow = S.text(parent, text, size, sp)
		shadow.Name = "Ombre"
		shadow.TextTransparency = 0.25
		local st = shadow:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = 0.25
		end
	end
	base.TextColor3 = p.TextColor3
	base.Position = p.Position
	base.ZIndex = z
	local l = S.text(parent, text, size, base)
	-- l'ombre suit le texte (badge, argent…)
	local shadow = parent:FindFirstChild("Ombre")
	if shadow and shadow:IsA("TextLabel") and shadow.Text == text then
		shadow.Name = "OmbreDe" .. l.Name
		l:GetPropertyChangedSignal("Text"):Connect(function()
			shadow.Text = l.Text
		end)
		l:GetPropertyChangedSignal("TextTransparency"):Connect(function()
			shadow.TextTransparency = math.max(l.TextTransparency, 0.25)
			local st = shadow:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = shadow.TextTransparency
			end
		end)
	end
	return l
end

-- Icône : image si renseignée dans Config/Hud, sinon emoji (emplacement provisoire).
local function icon(parent: Instance, ic: HudConfig.Icon, size: number, pos: UDim2, z: number?): GuiObject
	local props: { [string]: any } = {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z or 2,
		Parent = parent,
	}
	if ic.image then
		props.Image = ic.image
		props.ScaleType = Enum.ScaleType.Fit
		return S.new("ImageLabel", props)
	end
	props.Text = ic.emoji
	props.TextSize = size * 0.9
	props.Font = Enum.Font.GothamBold
	props.TextColor3 = BLANC
	return S.new("TextLabel", props)
end

-- Halo doux : disques concentriques de plus en plus transparents.
local function glow(parent: Instance, color: Color3, size: number, pos: UDim2, z: number?): Frame
	local holder = frame(parent, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z or 1,
	})
	for i, k in { 1, 0.75, 0.5 } do
		local d = frame(holder, {
			BackgroundColor3 = color,
			BackgroundTransparency = 0.93 - i * 0.08,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(k, k),
			ZIndex = z or 1,
		})
		S.corner(d, size)
	end
	return holder
end

-- Éclat blanc qui balaie la surface toutes les quelques secondes.
local function shine(surface: GuiObject, radius: number, period: number, z: number)
	local band = frame(surface, { BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = z })
	S.corner(band, radius)
	local g = fade(band, { { 0, 1 }, { 0.42, 1 }, { 0.5, 0.15 }, { 0.58, 1 }, { 1, 1 } }, 25)
	local phase = math.random() * period
	animate(function(t)
		local k = ((t + phase) % period) / 0.9 -- l'éclat traverse en 0,9 s puis attend
		g.Offset = Vector2.new(if k < 1 then -1 + 2 * k else 1, 0)
	end)
end

-- Couche d'effets au-dessus de tout le HUD (coordonnées écran absolues).
local overlay: Frame? = nil
local currentScale = 1

-- Explosion au clic : anneau qui s'élargit + étoiles projetées en cercle.
function Hud.burst(target: GuiObject, color: Color3?)
	local layer = overlay
	if not layer then
		return
	end
	local centre = target.AbsolutePosition + target.AbsoluteSize / 2
	local s = currentScale
	local ring = frame(layer, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(centre.X, centre.Y),
		Size = UDim2.fromOffset(20 * s, 20 * s),
		ZIndex = 50,
	})
	S.corner(ring, 999)
	local stroke = S.stroke(ring, color or BLANC, 5 * s)
	S.tween(ring, 0.45, { Size = UDim2.fromOffset(150 * s, 150 * s) })
	S.tween(stroke, 0.45, { Transparency = 1, Thickness = 1 })
	local stars: { GuiObject } = {}
	for i = 1, 9 do
		local angle = (i / 9) * math.pi * 2 + math.random() * 0.4
		local dist = (55 + math.random() * 45) * s
		local star = icon(layer, HudConfig.icons.star, (14 + math.random() * 12) * s, UDim2.fromOffset(centre.X, centre.Y), 51)
		table.insert(stars, star)
		S.tween(star, 0.55, {
			Position = UDim2.fromOffset(centre.X + math.cos(angle) * dist, centre.Y + math.sin(angle) * dist),
			Rotation = math.random(-180, 180),
		}, Enum.EasingStyle.Quart)
		task.delay(0.25, function()
			local prop = if star:IsA("ImageLabel") then "ImageTransparency" else "TextTransparency"
			S.tween(star, 0.3, { [prop] = 1, Size = UDim2.fromOffset(4, 4) })
		end)
	end
	task.delay(0.6, function()
		ring:Destroy()
		for _, star in stars do
			star:Destroy()
		end
	end)
end

-- Texte qui s'envole (gain d'argent…).
function Hud.floatText(target: GuiObject, text: string, color: Color3)
	local layer = overlay
	if not layer then
		return
	end
	local s = currentScale
	-- part de la fin du texte visé (à droite du montant)
	local width = if target:IsA("TextLabel") then target.TextBounds.X else target.AbsoluteSize.X
	local p = target.AbsolutePosition + Vector2.new(width, 0)
	local l = label(layer, text, 34 * s, {
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(p.X + 12 * s, p.Y + 6 * s),
		Size = UDim2.fromOffset(400, 40 * s),
		ZIndex = 52,
		strokeThickness = 3 * s,
		shadow = false,
	})
	S.tween(l, 1.1, { Position = l.Position - UDim2.fromOffset(0, 70 * s) }, Enum.EasingStyle.Quad)
	task.delay(0.6, function()
		S.tween(l, 0.5, { TextTransparency = 1 })
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			S.tween(st, 0.5, { Transparency = 1 })
		end
	end)
	task.delay(1.2, function()
		l:Destroy()
	end)
end

-- Étincelles qui apparaissent et disparaissent au hasard autour d'un élément.
local function twinkles(parent: GuiObject, count: number, size: number)
	for i = 1, count do
		local star = icon(parent, HudConfig.icons.star, size, UDim2.fromScale(0.5, 0.5), 9)
		local scale = S.new("UIScale", { Parent = star })
		local period = 1.4 + math.random() * 1.2
		local phase = math.random() * period
		local cycle = -1
		animate(function(t)
			local n = math.floor((t + phase) / period)
			if n ~= cycle then
				cycle = n
				star.Position = UDim2.fromScale(0.05 + math.random() * 0.9, 0.05 + math.random() * 0.7)
			end
			local k = ((t + phase) % period) / period
			scale.Scale = math.max(0, math.sin(k * math.pi)) ^ 2
			star.Rotation = k * 90
		end)
	end
end

-- Survol : grossit légèrement ; appui : s'enfonce.
local function interactive(button: GuiButton, target: GuiObject)
	local scale = target:FindFirstChildOfClass("UIScale") or S.new("UIScale", { Parent = target })
	local hover = false
	button.MouseEnter:Connect(function()
		hover = true
		S.tween(scale, 0.15, { Scale = 1.07 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		hover = false
		S.tween(scale, 0.15, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		S.tween(scale, 0.08, { Scale = 0.93 })
	end)
	button.MouseButton1Up:Connect(function()
		S.tween(scale, 0.25, { Scale = if hover then 1.07 else 1 }, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		Hud.burst(target)
	end)
end

-- Petit rebond (changement d'argent, badge…).
function Hud.bump(o: GuiObject, amount: number?)
	local scale = o:FindFirstChildOfClass("UIScale") or S.new("UIScale", { Parent = o })
	scale.Scale = 1 + (amount or 0.12)
	S.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Bloc en relief : socle sombre décalé dessous, face en dégradé, biseau clair, reflet du haut.
-- Renvoie le bouton (face) et le conteneur (pour l'échelle au survol).
local function bevel(parent: Instance, pos: UDim2, size: Vector2, color: Color3, radius: number, depth: number?): (TextButton, Frame)
	local d = depth or 6
	local holder = frame(parent, { BackgroundTransparency = 1, Position = pos, Size = UDim2.fromOffset(size.X, size.Y) })
	local base = frame(holder, { BackgroundColor3 = darker(color, 0.55), Position = UDim2.fromOffset(0, d), Size = UDim2.fromScale(1, 1) })
	S.corner(base, radius)
	S.stroke(base, NOIR, 3.5)
	local face = S.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = BLANC,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 2,
		Parent = holder,
	})
	S.corner(face, radius)
	S.stroke(face, NOIR, 3.5)
	gradient(face, { lighter(color, 0.38), color, darker(color, 0.22) })
	-- biseau : liseré clair intérieur
	local rim = frame(face, { BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 3 })
	S.corner(rim, radius - 3)
	S.stroke(rim, lighter(color, 0.6), 1.6, 0.35)
	-- reflet sur la moitié haute
	local gloss = frame(face, { Position = UDim2.fromOffset(5, 4), Size = UDim2.new(1, -10, 0.42, 0), ZIndex = 3 })
	S.corner(gloss, radius - 4)
	fade(gloss, { { 0, 0.45 }, { 1, 0.92 } })
	-- ombre interne en bas
	local shade = frame(face, { BackgroundColor3 = NOIR, Position = UDim2.new(0, 0, 0.62, 0), Size = UDim2.new(1, 0, 0.38, 0), ZIndex = 3 })
	S.corner(shade, radius)
	fade(shade, { { 0, 1 }, { 1, 0.72 } })
	shine(face, radius, 4 + math.random() * 2, 4)
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, d * 0.6)
	end)
	for _, signal in { face.MouseButton1Up, face.MouseLeave } do
		signal:Connect(function()
			face.Position = UDim2.new()
		end)
	end
	interactive(face, holder)
	return face, holder
end

-- Pastille rouge pulsante (badge de notification).
local function badge(parent: Instance, text: string, size: number, pos: UDim2): (Frame, TextLabel)
	local b = frame(parent, {
		BackgroundColor3 = BLANC,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 8,
	})
	S.corner(b, size)
	S.stroke(b, BLANC, 2.5)
	gradient(b, { Color3.fromHex("#FF6A5E"), Color3.fromHex("#E3121B") })
	local t = label(b, text, size * 0.66, { ZIndex = 10, strokeThickness = 1.8, shadow = false })
	local scale = S.new("UIScale", { Parent = b })
	local phase = math.random() * 2
	animate(function(time)
		local k = ((time + phase) % 2.2) / 0.35
		scale.Scale = if k < 1 then 1 + 0.18 * math.sin(k * math.pi) else 1
	end)
	return b, t
end

-- Bouton « pilule » du haut : relief, icône dans une pastille, texte avec ombre.
local function pill(parent: Instance, text: string, ic: HudConfig.Icon, color: Color3, pos: Vector2, size: Vector2): TextButton
	local face = bevel(parent, UDim2.fromOffset(pos.X, pos.Y), size, color, 14)
	-- icône qui déborde du bouton et se dandine
	local art = icon(face, ic, size.Y * 1.05, UDim2.fromOffset(size.Y * 0.6, size.Y / 2 - 3), 6)
	local phase = math.random() * 4
	animate(function(t)
		art.Rotation = math.sin((t + phase) * 2) * 7
	end)
	label(face, text, size.Y * 0.6, {
		Position = UDim2.fromOffset(size.Y * 1.1, -1),
		Size = UDim2.new(1, -size.Y * 1.2, 1, 0),
		ZIndex = 7,
		strokeThickness = 3.2,
	})
	return face
end

-- Tuile carrée de gauche : relief, grande icône qui flotte, nom qui déborde en bas.
local function tile(parent: Instance, text: string, ic: HudConfig.Icon, color: Color3, accent: Color3, y: number): TextButton
	local face = bevel(parent, UDim2.fromOffset(2, y), Vector2.new(86, 86), color, 14)
	-- dégradé diagonal bicolore façon référence
	local tint = frame(face, { BackgroundColor3 = accent, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	S.corner(tint, 14)
	fade(tint, { { 0, 1 }, { 0.5, 0.6 }, { 1, 0.2 } }, 45)
	glow(face, lighter(color, 0.5), 80, UDim2.fromOffset(43, 36), 4)
	local art = icon(face, ic, 66, UDim2.fromOffset(43, 35), 6)
	local phase = math.random() * 3
	animate(function(t)
		art.Position = UDim2.fromOffset(43, 35 + math.sin((t + phase) * 2.2) * 2.5)
		art.Rotation = math.sin((t + phase) * 1.6) * 4
	end)
	label(face, text, 24, { Position = UDim2.fromOffset(-12, 56), Size = UDim2.new(1, 24, 0, 30), ZIndex = 8, strokeThickness = 3.2 })
	return face
end

-- Gros dé blanc en relief (face 5 + tranche sombre décalée = effet cube).
local function drawDice(parent: Instance, size: number, pos: UDim2): Frame
	local holder = frame(parent, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 3,
	})
	local side = frame(holder, { BackgroundColor3 = Color3.fromHex("#7D8DB8"), Position = UDim2.fromOffset(5, 8), Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	S.corner(side, size * 0.2)
	S.stroke(side, NOIR, 3.5)
	local d = frame(holder, { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	S.corner(d, size * 0.2)
	S.stroke(d, NOIR, 3.5)
	gradient(d, { BLANC, Color3.fromHex("#E4E9F7"), Color3.fromHex("#B8C3E2") }, 50)
	local gloss = frame(d, { Position = UDim2.fromScale(0.08, 0.06), Size = UDim2.fromScale(0.84, 0.36), ZIndex = 5 })
	S.corner(gloss, size * 0.15)
	fade(gloss, { { 0, 0.3 }, { 1, 1 } })
	local pip = size * 0.18
	for _, p in { { 0.26, 0.26 }, { 0.74, 0.26 }, { 0.5, 0.5 }, { 0.26, 0.74 }, { 0.74, 0.74 } } do
		local dot = frame(d, {
			BackgroundColor3 = Color3.fromHex("#1E2B55"),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(p[1], p[2]),
			Size = UDim2.fromOffset(pip, pip),
			ZIndex = 6,
		})
		S.corner(dot, pip)
		gradient(dot, { Color3.fromHex("#0E1530"), Color3.fromHex("#3B4F8F") })
		local spark = frame(dot, { Position = UDim2.fromScale(0.2, 0.15), Size = UDim2.fromScale(0.32, 0.32), BackgroundTransparency = 0.4, ZIndex = 7 })
		S.corner(spark, pip)
	end
	holder.Rotation = -8
	return holder
end

-- Grosse flèche verte « Upgrades » en relief : pointe en barres + tige, copie noire dessous pour le contour,
-- copie vert foncé décalée pour l'épaisseur.
local function drawArrow(parent: Instance, size: number, pos: UDim2): Frame
	local f = frame(parent, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
	})
	local function shape(color: Color3, grow: number, dy: number, z: number, grad: { Color3 }?)
		local rows = 14
		local parts = {}
		for i = 0, rows - 1 do
			local w = (i + 1) / rows * 0.98 + grow * 2
			table.insert(parts, frame(f, {
				BackgroundColor3 = color,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.02 - grow + dy + i * 0.5 / rows),
				Size = UDim2.fromScale(w, 0.5 / rows + 0.006),
				ZIndex = z,
			}))
		end
		table.insert(parts, frame(f, {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.5 + dy),
			Size = UDim2.fromScale(0.44 + grow * 2, 0.46 + grow),
			ZIndex = z,
		}))
		if grad then
			for _, p in parts do
				gradient(p, grad, 0)
			end
		end
	end
	shape(NOIR, 0.045, 0.06, 2)
	shape(Color3.fromHex("#1C7A1F"), 0, 0.06, 3)
	shape(NOIR, 0.045, 0, 3)
	shape(BLANC, 0, 0, 4, { Color3.fromHex("#2FB52E"), Color3.fromHex("#6BEA55"), Color3.fromHex("#2FB52E") })
	local streak = frame(f, { BackgroundColor3 = Color3.fromHex("#C9FFBE"), Position = UDim2.fromScale(0.33, 0.52), Size = UDim2.fromScale(0.07, 0.38), ZIndex = 5 })
	streak.BackgroundTransparency = 0.25
	S.corner(streak, 4)
	return f
end

-- Pastille de prix Robux : losange vert à contour sombre (EMPLACEMENT PROVISOIRE, voir icons.robux.image).
local function robuxIcon(parent: Instance, size: number, pos: UDim2, z: number)
	local ic = HudConfig.icons.robux
	if ic.image then
		icon(parent, ic, size, pos, z)
		return
	end
	local c = frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		Rotation = 45,
		ZIndex = z,
	})
	S.corner(c, size * 0.3)
	S.stroke(c, NOIR, 2.5)
	gradient(c, { Color3.fromHex("#9BFF8A"), Color3.fromHex("#2DC22F") }, 0)
	local inner = frame(c, {
		BackgroundColor3 = Color3.fromHex("#156D1B"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.42),
		ZIndex = z + 1,
	})
	S.corner(inner, size * 0.12)
end

-- Bouton du bas : halo, grosse icône sans cadre et nom dessous.
local function bottomItem(parent: Instance, text: string, x: number, haloColor: Color3): (TextButton, Frame)
	local b = S.new("TextButton", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 56),
		Size = UDim2.fromOffset(124, 124),
		Text = "",
		Parent = parent,
	})
	local inner = frame(b, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	glow(inner, haloColor, 120, UDim2.fromOffset(62, 46), 1)
	local art = frame(inner, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 92), ZIndex = 2 })
	label(inner, text, 28, { Position = UDim2.fromOffset(-20, 88), Size = UDim2.new(1, 40, 0, 34), ZIndex = 9, strokeThickness = 3.2 })
	interactive(b, inner)
	return b, art
end

-- Rayons lumineux qui tournent lentement derrière une offre.
local function rays(parent: Instance, color: Color3, size: number, pos: UDim2, speed: number)
	local r = frame(parent, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 1,
	})
	for i = 0, 5 do
		local ray = frame(r, {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, size * 0.16, 1, 0),
			Rotation = i * 30,
			ZIndex = 1,
		})
		fade(ray, { { 0, 1 }, { 0.25, 0.5 }, { 0.5, 0.2 }, { 0.75, 0.5 }, { 1, 1 } })
	end
	animate(function(t)
		r.Rotation = (t * speed) % 360
	end)
end

-- Offre de droite : rayons, pastille ronde brillante qui respire, nom, prix dans une capsule.
local function offer(parent: Instance, name: string, ic: HudConfig.Icon, color: Color3, robux: number, y: number): TextButton
	local b = S.new("TextButton", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(130, 156),
		Text = "",
		Parent = parent,
	})
	local inner = frame(b, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	rays(inner, lighter(color, 0.55), 160, UDim2.fromOffset(65, 46), 25)
	glow(inner, color, 130, UDim2.fromOffset(65, 46), 1)
	local blobHolder = frame(inner, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(65, 46),
		Size = UDim2.fromOffset(92, 92),
		ZIndex = 2,
	})
	local depth = frame(blobHolder, { BackgroundColor3 = darker(color, 0.55), Position = UDim2.fromOffset(0, 5), Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	S.corner(depth, 46)
	S.stroke(depth, NOIR, 3.5)
	local blob = frame(blobHolder, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	S.corner(blob, 46)
	S.stroke(blob, NOIR, 3.5)
	gradient(blob, { lighter(color, 0.45), color, darker(color, 0.3) }, 60)
	local ring = frame(blob, { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 4 })
	S.corner(ring, 46)
	S.stroke(ring, lighter(color, 0.7), 1.8, 0.3)
	local gloss = frame(blob, { Position = UDim2.fromScale(0.18, 0.08), Size = UDim2.fromScale(0.5, 0.3), ZIndex = 4 })
	S.corner(gloss, 46)
	fade(gloss, { { 0, 0.35 }, { 1, 1 } })
	icon(blob, ic, 66, UDim2.fromScale(0.5, 0.52), 5)
	twinkles(blobHolder, 4, 20)
	local scale = S.new("UIScale", { Parent = blobHolder })
	local phase = math.random() * 3
	animate(function(t)
		scale.Scale = 1 + 0.045 * math.sin((t + phase) * 2.6)
	end)
	label(inner, name, 23, { Position = UDim2.fromOffset(-16, 88), Size = UDim2.new(1, 32, 0, 28), ZIndex = 7, strokeThickness = 2.8 })
	-- capsule de prix
	local price = frame(inner, {
		BackgroundColor3 = Color3.fromHex("#0F1A12"),
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(65, 120),
		Size = UDim2.fromOffset(92, 30),
		ZIndex = 6,
	})
	S.corner(price, 15)
	S.stroke(price, Color3.fromHex("#2DC22F"), 2, 0.2)
	robuxIcon(price, 24, UDim2.fromOffset(17, 15), 8)
	local priceText = label(price, tostring(robux), 24, {
		TextColor3 = Color3.fromHex("#6BFF5A"),
		Position = UDim2.fromOffset(32, -1),
		Size = UDim2.new(1, -38, 1, 0),
		ZIndex = 9,
		strokeThickness = 2.4,
		shadow = false,
	})
	priceText.TextXAlignment = Enum.TextXAlignment.Left
	interactive(b, inner)
	return b
end

function Hud.build(): Refs
	local gui: ScreenGui = S.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	-- Groupe accroché à un bord ; `place` donne sa position selon l'échelle et l'appareil.
	type Group = { frame: Frame, scale: UIScale, place: (s: number, touch: boolean) -> (Vector2, UDim2) }
	local groups: { Group } = {}
	local function group(size: Vector2, place: (s: number, touch: boolean) -> (Vector2, UDim2)): Frame
		local f = frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(size.X, size.Y) })
		table.insert(groups, { frame = f, scale = S.new("UIScale", { Parent = f }), place = place })
		return f
	end
	local buttons: { [string]: GuiButton } = {}
	local icons = HudConfig.icons
	overlay = frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 })

	-- Haut centre : Hub, Home, Shop.
	local top = group(Vector2.new(540, 70), function()
		return Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12)
	end)
	buttons.hub = pill(top, "Hub", icons.hub, Color3.fromHex("#FFC21F"), Vector2.new(0, 6), Vector2.new(164, 52))
	buttons.home = pill(top, "Home", icons.home, Color3.fromHex("#3DB8F5"), Vector2.new(176, 0), Vector2.new(184, 58))
	buttons.shopTop = pill(top, "Shop", icons.shopTop, Color3.fromHex("#45CC3A"), Vector2.new(372, 6), Vector2.new(164, 52))
	local shopBadge = badge(top, "!", 28, UDim2.fromOffset(530, 8))

	-- Gauche : Shop, Rebirth, Index.
	local left = group(Vector2.new(92, 292), function()
		return Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, -4)
	end)
	buttons.shop = tile(left, "Shop", icons.shop, Color3.fromHex("#FF4F7B"), Color3.fromHex("#3E7BFF"), 0)
	buttons.rebirth = tile(left, "Rebirth", icons.rebirth, Color3.fromHex("#F23B3B"), Color3.fromHex("#8E0F22"), 100)
	buttons.index = tile(left, "Index", icons.index, Color3.fromHex("#3FA9FF"), Color3.fromHex("#1F3FC2"), 200)

	-- Gauche, deuxième colonne : téléportation, Monde 1 = monstres, Monde 2 = héros (couleurs de Config/Mondes).
	local worlds = group(Vector2.new(92, 192), function(s)
		return Vector2.new(0, 0.5), UDim2.new(0, 12 + 100 * s, 0.5, -54 * s)
	end)
	local monstres, heros = assert(Mondes.get("monstres")), assert(Mondes.get("heros"))
	buttons.mondeMonstres = tile(worlds, "Monstres", icons.mondeMonstres, monstres.color, monstres.dark, 0)
	buttons.mondeHeros = tile(worlds, "Héros", icons.mondeHeros, heros.color, heros.dark, 100)

	-- Bas centre : « Put Back » au-dessus du dé, puis Settings, Roll, Upgrades.
	local bottom = group(Vector2.new(390, 184), function()
		return Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8)
	end)
	local putBack = frame(bottom, { BackgroundTransparency = 1, Position = UDim2.fromOffset(106, 0), Size = UDim2.fromOffset(178, 50), Visible = false })
	local putBackButton = bevel(putBack, UDim2.new(), Vector2.new(178, 44), Color3.fromHex("#F02B2B"), 12, 5)
	label(putBackButton, "Put Back", 28, { ZIndex = 7, strokeThickness = 3 })
	buttons.putBack = putBackButton
	putBack:GetPropertyChangedSignal("Visible"):Connect(function()
		if putBack.Visible then
			Hud.bump(putBack, 0.25)
		end
	end)

	local settings, settingsArt = bottomItem(bottom, "Settings", 0, Color3.fromHex("#B8C3E2"))
	local gear = icon(settingsArt, icons.settings, 84, UDim2.fromScale(0.5, 0.5), 3)
	buttons.settings = settings
	local roll, rollArt = bottomItem(bottom, "Roll", 133, Color3.fromHex("#FFFFFF"))
	local dice = drawDice(rollArt, 84, UDim2.fromScale(0.5, 0.48))
	twinkles(rollArt, 3, 16)
	buttons.roll = roll
	local up, upArt = bottomItem(bottom, "Upgrades", 266, Color3.fromHex("#4CFF4A"))
	local arrow: GuiObject = if icons.upgrades.image
		then icon(upArt, icons.upgrades, 92, UDim2.fromScale(0.5, 0.5), 3)
		else drawArrow(upArt, 84, UDim2.fromScale(0.5, 0.5))
	local upBadge, upBadgeText = badge(upArt, "0", 30, UDim2.fromOffset(104, 12))
	buttons.upgrades = up
	animate(function(t)
		gear.Rotation = (t * 20) % 360 -- engrenage qui tourne lentement
		arrow.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 2.4) * 4)
		rollArt.Rotation = math.sin(t * 1.8) * 5
	end)

	-- Bas gauche : argent et bonus d'amis.
	local wallet = group(Vector2.new(380, 104), function(s, touch)
		if touch then -- le joystick tactile occupe le bas gauche : l'argent passe sous les boutons du haut
			return Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 14 + 82 * s)
		end
		return Vector2.new(0, 1), UDim2.new(0, 16, 1, -10)
	end)
	local money = label(wallet, "$0", 56, {
		TextColor3 = BLANC,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 62),
		ZIndex = 3,
		strokeThickness = 4.2,
	})
	gradient(money, { Color3.fromHex("#B6FF8C"), Color3.fromHex("#4DF04A"), Color3.fromHex("#1FB52A") })
	icon(wallet, icons.friends, 34, UDim2.fromOffset(20, 81), 4)
	local friend = label(wallet, "Friend Boost +0%", 27, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(42, 64),
		Size = UDim2.new(1, 0, 0, 34),
		ZIndex = 3,
		strokeThickness = 3,
	})

	-- Droite : Ultra Luck, Jackpot Roll.
	local offers = group(Vector2.new(130, 340), function()
		return Vector2.new(1, 0.5), UDim2.new(1, -16, 0.5, -20)
	end)
	buttons.ultraLuck = offer(offers, HudConfig.products.ultraLuck.name, icons.ultraLuck, Color3.fromHex("#B444F5"), HudConfig.products.ultraLuck.robux, 0)
	local op = label(buttons.ultraLuck, "Op!", 32, {
		TextColor3 = BLANC,
		Position = UDim2.fromOffset(76, -14),
		Size = UDim2.fromOffset(64, 36),
		ZIndex = 10,
		strokeThickness = 3.2,
	})
	gradient(op, { Color3.fromHex("#FF7A6E"), Color3.fromHex("#FF1F2E") })
	op.Rotation = 14
	buttons.jackpotRoll = offer(offers, HudConfig.products.jackpotRoll.name, icons.jackpot, Color3.fromHex("#3F9BFF"), HudConfig.products.jackpotRoll.robux, 184)
	local x999 = label(buttons.jackpotRoll, "999x luck", 25, {
		Position = UDim2.fromOffset(8, -14),
		Size = UDim2.fromOffset(134, 30),
		ZIndex = 10,
		strokeThickness = 2.8,
		shadow = false,
	})
	x999.Rotation = 14
	local rainbow = gradient(x999, {
		Color3.fromHex("#FF4A4A"),
		Color3.fromHex("#FFD23F"),
		Color3.fromHex("#4CFF6A"),
		Color3.fromHex("#3FA2FF"),
		Color3.fromHex("#C04BFF"),
		Color3.fromHex("#FF4A4A"),
	}, 0)
	animate(function(t)
		rainbow.Offset = Vector2.new(math.sin(t * 1.4) * 0.35, 0)
		op.Rotation = 14 + math.sin(t * 3) * 4
	end)

	-- Haut droite : petit bouton Daily Rewards (pilule sombre, liseré doré, pastille rouge).
	local daily = group(Vector2.new(138, 32), function()
		return Vector2.new(1, 0), UDim2.new(1, -10, 0, 10)
	end)
	local dailyInner = frame(daily, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local dailyButton = S.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = BLANC,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Parent = dailyInner,
	})
	S.corner(dailyButton, 16)
	S.stroke(dailyButton, Color3.fromHex("#FFC83A"), 1.6, 0.25)
	gradient(dailyButton, { Color3.fromHex("#2C3550"), Color3.fromHex("#141A29") })
	icon(dailyButton, icons.daily, 26, UDim2.fromOffset(17, 15), 2)
	label(dailyButton, "Daily Rewards", 14, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -36, 1, 0),
		ZIndex = 3,
		strokeThickness = 1.4,
		shadow = false,
	})
	local dot = frame(dailyButton, { BackgroundColor3 = Color3.fromHex("#FF2B2B"), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 3), Size = UDim2.fromOffset(10, 10), ZIndex = 4 })
	S.corner(dot, 5)
	interactive(dailyButton, dailyInner)
	buttons.daily = dailyButton

	-- Notification courte au centre de l'écran.
	local toast = label(gui, "", 30, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 40),
		ZIndex = 20,
		strokeThickness = 3,
		shadow = false,
	})

	local function layout()
		local a = gui.AbsoluteSize
		local s = math.clamp(math.min(a.X / HudConfig.design.X, a.Y / HudConfig.design.Y), 0.45, 1.5)
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		for _, g in groups do
			g.scale.Scale = s
			local anchor, pos = g.place(s, touch)
			g.frame.AnchorPoint = anchor
			g.frame.Position = pos
		end
		toast.TextSize = 30 * s
		currentScale = s
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()

	return {
		gui = gui,
		buttons = buttons,
		putBack = putBack,
		dice = dice,
		money = money,
		friend = friend,
		upgradesBadge = upBadge,
		upgradesBadgeText = upBadgeText,
		shopBadge = shopBadge,
		toast = toast,
	}
end

return Hud
