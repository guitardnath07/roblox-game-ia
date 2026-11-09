--!strict
-- Menu « Tours » : bannière de la tour dont l'entrée a été utilisée (illustration, nom, difficulté, bouton « Jouer »).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChallengeTower = require(ReplicatedStorage.Shared.Config.ChallengeTower)
local S = require(script.Parent.Style)

local Menu = {}

export type Callbacks = {
	onPlay: (tower: ChallengeTower.Tower, setMessage: (string?) -> ()) -> (),
	onClose: () -> (),
}

-- Illustration de secours : la vraie tour de la map vue en 3D, à droite de la bannière.
local function towerView(banner: Frame, config: ChallengeTower.Tower)
	local tower = ChallengeTower.model(config)
	if not tower then
		return
	end
	local vp = S.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.62, 0, 1.25, 0),
		Position = UDim2.fromScale(0.4, -0.12),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightDirection = Vector3.new(-1, -0.6, -0.4),
		ZIndex = 1,
		Parent = banner,
	})
	local world = S.new("WorldModel", { Parent = vp })
	local model = Instance.new("Model")
	for _, d in tower:GetChildren() do
		if d:IsA("BasePart") or d:IsA("Model") or d:IsA("Folder") then
			local ok, clone = pcall(d.Clone, d)
			if ok and clone then
				clone.Parent = model
			end
		end
	end
	model.Parent = world
	local cf, size = model:GetBoundingBox()
	local camera = S.new("Camera", { FieldOfView = 35, Parent = vp })
	local d = math.max(size.Y, size.X) / (2 * math.tan(math.rad(17.5))) * 0.95
	-- vue de trois quarts depuis le côté de la porte
	local front = ((config.entrance - cf.Position) * Vector3.new(1, 0, 1)).Unit
	local eye = cf.Position + front * (d * 0.85) + front:Cross(Vector3.yAxis) * (d * 0.55) + Vector3.new(0, size.Y * 0.1, 0)
	camera.CFrame = CFrame.lookAt(eye, cf.Position + Vector3.new(0, size.Y * 0.15, 0))
	vp.CurrentCamera = camera
end

local function banner(parent: Instance, tower: ChallengeTower.Tower, order: number, callbacks: Callbacks)
	local b = S.new("Frame", {
		BackgroundColor3 = S.BLANC,
		Size = UDim2.new(1, -16, 0, 156),
		LayoutOrder = order,
		ClipsDescendants = true,
		Parent = parent,
	})
	S.corner(b, 12)
	S.stroke(b, Color3.fromHex("#3A3A40"), 4)
	S.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(tower.colors.top, tower.colors.bottom), Parent = b })

	if tower.banner then
		S.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = tower.banner,
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(1, 1),
			Parent = b,
		})
	else
		towerView(b, tower)
	end
	-- Voile sombre à gauche pour la lisibilité du texte.
	local veil = S.new("Frame", { BackgroundColor3 = S.NOIR, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = b })
	S.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.55, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = veil,
	})

	S.text(b, tower.name, 40, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 46),
		ZIndex = 3,
		strokeThickness = 3,
	})
	S.text(b, tower.difficulty, 30, {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = tower.difficultyColor,
		Position = UDim2.fromOffset(22, 60),
		Size = UDim2.new(1, -40, 0, 34),
		ZIndex = 3,
		strokeThickness = 2.5,
	})
	local message = S.text(b, "", 18, {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromHex("#FF6B6B"),
		Position = UDim2.fromOffset(22, 108),
		Size = UDim2.new(1, -230, 0, 30),
		ZIndex = 3,
	})

	local play = S.button(b, "", S.VERT, S.VERT_FONCE, Vector2.new(176, 56), Vector2.zero)
	play.Parent.Position = UDim2.new(1, -196, 0, 86) -- calé à droite quelle que soit la largeur
	play.Parent.ZIndex = 4
	for _, d in play.Parent:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 4
		end
	end
	S.playIcon(play, 30, Vector2.new(18, 13), 5)
	S.text(play, "Jouer", 30, { Font = S.BOUTON, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -62, 1, 0), ZIndex = 5 })

	local busy = false
	play.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		message.Text = ""
		callbacks.onPlay(tower, function(text: string?)
			message.Text = text or ""
		end)
		busy = false
	end)
end

function Menu.open(root: Frame, tower: ChallengeTower.Tower, callbacks: Callbacks): () -> ()
	local panel = S.panel(root, Vector2.new(620, 440), Vector2.new(190, 60))
	local close = S.titleBar(panel, "Tours", {
		icon = true,
		close = true,
		color = Color3.fromHex("#C9CBD1"),
		dark = Color3.fromHex("#6E7078"),
	})
	local list = S.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 74),
		Size = UDim2.new(1, -24, 1, -88),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = S.CONTOUR,
		Parent = panel,
	})
	S.new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	S.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 2), Parent = list })
	banner(list, tower, 1, callbacks)
	S.popIn(panel)

	local closed = false
	local function destroy()
		if not closed then
			closed = true
			panel:Destroy()
		end
	end
	if close then
		close.Activated:Connect(function()
			destroy()
			callbacks.onClose()
		end)
	end
	return destroy
end

return Menu
