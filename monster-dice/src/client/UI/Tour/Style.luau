--!strict
-- Style des fenêtres de la Tour des défis : panneaux sombres arrondis à contour gris, bandeaux verts, textes
-- blancs épais à contour sombre, boutons en relief à dégradé, croix rouge, cartes à contour de rareté.
-- Les icônes (cœur, épée, lecture, tour, potions, gemmes…) sont dessinées avec des Frames : aucune image externe.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerCombat = require(ReplicatedStorage.Shared.Config.TowerCombat)

local S = {}

S.VERT, S.VERT_FONCE = Color3.fromHex("#5BD83A"), Color3.fromHex("#2C8A1A")
S.CYAN, S.CYAN_FONCE = Color3.fromHex("#3CC9FF"), Color3.fromHex("#1676B8")
S.ROUGE, S.ROUGE_FONCE = Color3.fromHex("#EE3430"), Color3.fromHex("#9A1714")
S.GRIS, S.GRIS_FONCE = Color3.fromHex("#9C9CA3"), Color3.fromHex("#55555C")
S.PANNEAU = Color3.fromHex("#232327")
S.CONTOUR = Color3.fromHex("#4B4B52")
S.CARTE = Color3.fromHex("#131316")
S.NOIR = Color3.fromHex("#0B0B0D")
S.BLANC = Color3.new(1, 1, 1)
S.TITRE = Enum.Font.GothamBlack
S.BOUTON = Enum.Font.FredokaOne

function S.new(class: string, props: { [string]: any }, children: { Instance }?): any
	local o = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(o :: any)[k] = v
	end
	for _, c in children or {} do
		c.Parent = o
	end
	o.Parent = parent
	return o
end

function S.corner(o: Instance, radius: number?): UICorner
	return S.new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = o })
end

function S.stroke(o: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	return S.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = o,
	})
end

-- Texte blanc épais à contour sombre (le style de tous les titres et chiffres des références).
function S.text(parent: Instance, text: string, size: number, props: { [string]: any }?): TextLabel
	local p = props or {}
	local label = S.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = p.Font or S.TITRE,
		TextSize = size,
		TextColor3 = p.TextColor3 or S.BLANC,
		TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		ZIndex = p.ZIndex or 1,
		Parent = parent,
	})
	S.new("UIStroke", {
		Color = S.NOIR,
		Thickness = p.strokeThickness or math.max(1.5, size / 14),
		Parent = label,
	})
	return label
end

-- Panneau sombre arrondi à contour gris.
function S.panel(parent: Instance, size: Vector2, position: Vector2): Frame
	local f = S.new("Frame", {
		BackgroundColor3 = S.PANNEAU,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(position.X, position.Y),
		Parent = parent,
	})
	S.corner(f, 12)
	S.stroke(f, S.CONTOUR, 4)
	return f
end

-- Fine ligne de séparation.
function S.line(parent: Instance, y: number, inset: number)
	S.new("Frame", {
		BackgroundColor3 = S.CONTOUR,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -inset * 2, 0, 2),
		Position = UDim2.fromOffset(inset, y),
		Parent = parent,
	})
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	S.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(top, bottom),
		Parent = parent,
	})
end

local function lighter(c: Color3, t: number): Color3
	return c:Lerp(S.BLANC, t)
end

-- Bouton en relief : ombre décalée dessous, dégradé clair en haut, contour sombre, texte blanc contouré.
-- Renvoie le bouton cliquable et une fonction pour changer sa couleur.
function S.button(
	parent: Instance,
	text: string,
	color: Color3,
	dark: Color3,
	size: Vector2,
	position: Vector2,
	textSize: number?
): (TextButton, (Color3, Color3) -> ())
	local holder = S.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(position.X, position.Y),
		Parent = parent,
	})
	local shadow = S.new("Frame", {
		BackgroundColor3 = dark,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 5),
		Parent = holder,
	})
	S.corner(shadow, 9)
	local button = S.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = S.BLANC,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Parent = holder,
	})
	S.corner(button, 9)
	local stroke = S.stroke(button, dark, 2.5)
	local grad = S.new("UIGradient", { Rotation = 90, Parent = button })
	local function paint(c: Color3, d: Color3)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, lighter(c, 0.35)),
			ColorSequenceKeypoint.new(0.5, c),
			ColorSequenceKeypoint.new(1, c:Lerp(d, 0.35)),
		})
		shadow.BackgroundColor3 = d
		stroke.Color = d
	end
	paint(color, dark)
	if text ~= "" then
		local label = S.text(button, text, textSize or 26, { Font = S.BOUTON })
		label.Name = "Label"
	end
	-- Appui : le bouton descend sur son ombre.
	button.MouseButton1Down:Connect(function()
		button.Position = UDim2.fromOffset(0, 3)
	end)
	for _, signal in { button.MouseButton1Up, button.MouseLeave } do
		signal:Connect(function()
			button.Position = UDim2.new()
		end)
	end
	return button, paint
end

-- Croix de fermeture rouge (carré à droite du bandeau).
function S.closeButton(parent: Instance, size: number, position: Vector2): TextButton
	local b = S.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = S.BLANC,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromOffset(position.X, position.Y),
		Text = "",
		ZIndex = 3,
		Parent = parent,
	})
	S.corner(b, 8)
	S.stroke(b, S.ROUGE_FONCE, 3)
	gradient(b, lighter(S.ROUGE, 0.2), S.ROUGE:Lerp(S.ROUGE_FONCE, 0.3))
	S.text(b, "X", size * 0.72, { ZIndex = 4, strokeThickness = 3 })
	return b
end

-- Bandeau de titre en haut d'un panneau (vert par défaut, gris clair pour le menu « Tours »).
function S.titleBar(panel: Frame, text: string, opts: { icon: boolean?, close: boolean?, color: Color3?, dark: Color3? }): TextButton?
	local color, dark = opts.color or S.VERT, opts.dark or S.VERT_FONCE
	local bar = S.new("Frame", {
		BackgroundColor3 = S.BLANC,
		Size = UDim2.new(1, 0, 0, 58),
		ZIndex = 2,
		Parent = panel,
	})
	S.corner(bar, 12)
	S.stroke(bar, dark, 3)
	gradient(bar, lighter(color, 0.25), color)
	local x = 18
	if opts.icon then
		S.towerIcon(bar, 40, Vector2.new(14, 9))
		x = 66
	end
	S.text(bar, text, 32, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -x - 70, 1, 0),
		ZIndex = 3,
		strokeThickness = 3,
	})
	if opts.close then
		return S.closeButton(bar, 58, Vector2.new(panel.Size.X.Offset - 58, 0))
	end
	return nil
end

-- Contour de carte selon la rareté (arc-en-ciel animé pour « mythique »).
local rainbows: { UIGradient } = {}
function S.rarityStroke(o: Instance, rarityId: string, thickness: number?): UIStroke
	local rarity = TowerCombat.rarities[rarityId] or TowerCombat.rarities.commun
	local stroke = S.stroke(o, rarity.color, thickness or 3)
	if rarity.rainbow then
		stroke.Color = S.BLANC
		local g = S.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#FF4A4A")),
				ColorSequenceKeypoint.new(0.2, Color3.fromHex("#FFD23F")),
				ColorSequenceKeypoint.new(0.4, Color3.fromHex("#4CFF6A")),
				ColorSequenceKeypoint.new(0.6, Color3.fromHex("#3FC8FF")),
				ColorSequenceKeypoint.new(0.8, Color3.fromHex("#C04BFF")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#FF4A4A")),
			}),
			Parent = stroke,
		})
		table.insert(rainbows, g)
	end
	return stroke
end
RunService.RenderStepped:Connect(function()
	local r = (os.clock() * 90) % 360
	for i = #rainbows, 1, -1 do
		local g = rainbows[i]
		if g.Parent then
			g.Rotation = r
		else
			table.remove(rainbows, i)
		end
	end
end)

-- Icônes dessinées ---------------------------------------------------------------------------------------

local function icon(parent: Instance, size: number, position: Vector2, z: number?): Frame
	return S.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromOffset(position.X, position.Y),
		ZIndex = z or 2,
		Parent = parent,
	})
end

-- Pièce d'icône en coordonnées relatives (centre cx, cy ; taille w, h en fraction de l'icône).
local function piece(f: Frame, cx: number, cy: number, w: number, h: number, color: Color3, rot: number?, round: number?): Frame
	local p = S.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, cy),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = rot or 0,
		ZIndex = f.ZIndex,
		Parent = f,
	})
	if round then
		S.new("UICorner", { CornerRadius = UDim.new(round, 0), Parent = p })
	end
	return p
end

function S.heartIcon(parent: Instance, size: number, position: Vector2, z: number?): Frame
	local f = icon(parent, size, position, z)
	local red = Color3.fromHex("#FF3048")
	piece(f, 0.32, 0.36, 0.5, 0.5, red, 0, 0.5)
	piece(f, 0.68, 0.36, 0.5, 0.5, red, 0, 0.5)
	local tip = piece(f, 0.5, 0.56, 0.52, 0.52, red, 45, 0.12)
	gradient(tip, lighter(red, 0.1), red:Lerp(S.NOIR, 0.15))
	piece(f, 0.3, 0.3, 0.16, 0.16, lighter(red, 0.6), 0, 0.5)
	return f
end

-- Épée inclinée (lame bleue, garde dorée, poignée brune) : chaque pièce tourne autour de son centre,
-- les centres sont posés sur l'axe diagonal.
function S.swordIcon(parent: Instance, size: number, position: Vector2, z: number?): Frame
	local f = icon(parent, size, position, z)
	local function along(t: number): (number, number) -- t = 0 en bas à gauche, 1 en haut à droite
		return 0.18 + t * 0.64, 0.82 - t * 0.64
	end
	local bx, by = along(0.62)
	local blade = piece(f, bx, by, 0.2, 0.62, Color3.fromHex("#7FD8FF"), 45, 0.3)
	gradient(blade, Color3.fromHex("#E6F8FF"), Color3.fromHex("#2E8BE0"))
	local gx, gy = along(0.28)
	piece(f, gx, gy, 0.42, 0.12, Color3.fromHex("#FFB52E"), 45, 0.4)
	local hx, hy = along(0.12)
	piece(f, hx, hy, 0.12, 0.26, Color3.fromHex("#8A4B22"), 45, 0.4)
	return f
end

-- Triangle « lecture » en pixel-art (barres horizontales de largeur décroissante).
function S.playIcon(parent: Instance, size: number, position: Vector2, z: number?): Frame
	local f = icon(parent, size, position, z)
	local n = 9
	for i = 0, n - 1 do
		local d = math.abs(i - (n - 1) / 2) / ((n - 1) / 2) -- 0 au centre, 1 aux pointes
		local w = 0.8 * (1 - d) + 0.06
		S.new("Frame", {
			BackgroundColor3 = S.BLANC,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.15, 0.1 + i * 0.8 / n),
			Size = UDim2.fromScale(w, 0.8 / n + 0.01),
			ZIndex = f.ZIndex,
			Parent = f,
		})
	end
	return f
end

function S.towerIcon(parent: Instance, size: number, position: Vector2, z: number?): Frame
	local f = icon(parent, size, position, z or 3)
	local stone, shade = Color3.fromHex("#E9EEF2"), Color3.fromHex("#9AA7B2")
	local body = piece(f, 0.5, 0.62, 0.7, 0.62, stone)
	gradient(body, stone, shade)
	for _, x in { 0.22, 0.5, 0.78 } do
		piece(f, x, 0.24, 0.16, 0.18, stone)
	end
	piece(f, 0.5, 0.78, 0.22, 0.3, Color3.fromHex("#4E5964"), 0, 0.5)
	return f
end

function S.magnifierIcon(parent: Instance, size: number, position: Vector2, z: number?): Frame
	local f = icon(parent, size, position, z)
	local ring = piece(f, 0.45, 0.42, 0.64, 0.64, Color3.fromHex("#9FE7FF"), 0, 0.5)
	S.stroke(ring, Color3.fromHex("#E8322E"), size / 9)
	piece(f, 0.36, 0.33, 0.18, 0.18, S.BLANC, 0, 0.5)
	piece(f, 0.78, 0.8, 0.14, 0.34, Color3.fromHex("#5A5A60"), -45, 0.4)
	return f
end

-- Icône d'un butin selon sa forme ; `image` (rbxassetid) la remplace si renseignée dans la config.
function S.lootIcon(parent: Instance, item: TowerCombat.Loot, size: number, position: Vector2, z: number?): GuiObject
	if item.image then
		return S.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = item.image,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(position.X, position.Y),
			ZIndex = z or 2,
			Parent = parent,
		})
	end
	local f = icon(parent, size, position, z)
	local c = item.color
	if item.icon == "potion" then
		piece(f, 0.5, 0.2, 0.26, 0.14, Color3.fromHex("#E9E1D2"), 0, 0.3) -- col
		piece(f, 0.5, 0.11, 0.2, 0.1, Color3.fromHex("#9C6A3A"), 0, 0.3) -- bouchon
		piece(f, 0.32, 0.2, 0.14, 0.12, Color3.fromHex("#F2C94C"), -30, 0.4) -- petites ailes
		piece(f, 0.68, 0.2, 0.14, 0.12, Color3.fromHex("#F2C94C"), 30, 0.4)
		local body = piece(f, 0.5, 0.6, 0.74, 0.66, c, 0, 0.5)
		gradient(body, lighter(c, 0.35), c:Lerp(S.NOIR, 0.35))
		S.stroke(body, c:Lerp(S.NOIR, 0.5), 2)
		piece(f, 0.36, 0.48, 0.14, 0.2, S.BLANC, 20, 0.5).BackgroundTransparency = 0.35
	elseif item.icon == "gemme" or item.icon == "prisme" then
		local gem = piece(f, 0.5, 0.52, 0.56, 0.56, c, 45, 0.12)
		if item.icon == "prisme" then
			S.new("UIGradient", {
				Rotation = 45,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHex("#FF5AA8")),
					ColorSequenceKeypoint.new(0.35, Color3.fromHex("#B44BFF")),
					ColorSequenceKeypoint.new(0.65, Color3.fromHex("#3FC8FF")),
					ColorSequenceKeypoint.new(1, Color3.fromHex("#7DFF6A")),
				}),
				Parent = gem,
			})
		else
			gradient(gem, lighter(c, 0.45), c:Lerp(S.NOIR, 0.3))
		end
		S.stroke(gem, c:Lerp(S.NOIR, 0.5), 2)
		piece(f, 0.42, 0.42, 0.16, 0.16, S.BLANC, 45, 0.2).BackgroundTransparency = 0.3
	elseif item.icon == "tenue" then
		piece(f, 0.24, 0.32, 0.22, 0.4, c, 30, 0.2)
		piece(f, 0.76, 0.32, 0.22, 0.4, c, -30, 0.2)
		local body = piece(f, 0.5, 0.56, 0.5, 0.7, c, 0, 0.15)
		gradient(body, c, c:Lerp(S.NOIR, 0.25))
		piece(f, 0.5, 0.24, 0.2, 0.08, Color3.fromHex("#BDBDBD"), 0, 0.5)
	else -- anneau
		local ring = piece(f, 0.5, 0.5, 0.72, 0.5, S.NOIR, 0, 0.5)
		ring.BackgroundTransparency = 0.2
		S.stroke(ring, c, size / 12)
	end
	return f
end

-- Écran racine : une seule disposition logique de 1000 × 560 mise à l'échelle de l'écran (ordinateur,
-- tablette, téléphone) en conservant les proportions.
S.LOGIQUE = Vector2.new(1000, 560)
function S.root(name: string, displayOrder: number): (ScreenGui, Frame)
	local gui = S.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = displayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local root = S.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(S.LOGIQUE.X, S.LOGIQUE.Y),
		Parent = gui,
	})
	local scale = S.new("UIScale", { Parent = root })
	local function fit()
		local a = gui.AbsoluteSize
		scale.Scale = math.clamp(math.min(a.X / S.LOGIQUE.X, a.Y / S.LOGIQUE.Y), 0.4, 2)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return gui, root
end

function S.tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Apparition des fenêtres : petit rebond.
function S.popIn(frame: GuiObject)
	local s = frame:FindFirstChildOfClass("UIScale") or S.new("UIScale", { Parent = frame })
	s.Scale = 0.85
	S.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

return S
