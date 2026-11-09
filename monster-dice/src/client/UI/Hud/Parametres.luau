--!strict
-- Fenêtre « Settings » : choix du monde (héros ou monstres). Une carte par monde de Config/Mondes ; la carte du
-- monde actuel affiche « Actuel », les autres « Y aller ». Le choix est envoyé au serveur par `onChoose`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mondes = require(ReplicatedStorage.Shared.Config.Mondes)
local S = require(script.Parent.Parent.Tour.Style)

local Parametres = {}

export type Callbacks = {
	onChoose: (id: string, setMessage: (string?) -> ()) -> boolean, -- true si le changement a réussi
	onClose: () -> (),
}

local NOIR = Color3.new(0, 0, 0)

local CARD = Vector2.new(236, 196)

local function card(parent: Instance, monde: Mondes.Monde, x: number, current: boolean): TextButton
	local b = S.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(x, 112),
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		Text = "",
		Parent = parent,
	})
	S.corner(b, 14)
	S.stroke(b, if current then Color3.fromHex("#FFE45C") else NOIR, if current then 4 else 3)
	S.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(monde.color:Lerp(Color3.new(1, 1, 1), 0.2), monde.dark), Parent = b })
	if monde.image then
		S.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = monde.image,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(72, 72),
			ZIndex = 2,
			Parent = b,
		})
	else
		S.new("TextLabel", {
			BackgroundTransparency = 1,
			Text = monde.icon,
			TextSize = 60,
			Font = Enum.Font.GothamBold,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(72, 72),
			ZIndex = 2,
			Parent = b,
		})
	end
	S.text(b, monde.name, 23, { Font = S.BOUTON, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 30), ZIndex = 2, strokeThickness = 2.5 })
	S.text(b, monde.description, 15, {
		TextColor3 = Color3.fromHex("#F1F1F4"),
		Position = UDim2.fromOffset(8, 114),
		Size = UDim2.new(1, -16, 0, 22),
		ZIndex = 2,
		strokeThickness = 1.5,
	})
	-- pastille d'état en bas de la carte
	local pill = S.new("Frame", {
		BackgroundColor3 = if current then Color3.fromHex("#FFC83A") else Color3.fromHex("#5BD83A"),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 146),
		Size = UDim2.fromOffset(150, 36),
		ZIndex = 2,
		Parent = b,
	})
	S.corner(pill, 18)
	S.stroke(pill, NOIR, 2.5)
	S.text(pill, if current then "Actuel" else "Y aller", 22, { Font = S.BOUTON, ZIndex = 3, strokeThickness = 2.2 })
	-- survol
	local scale = S.new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		S.tween(scale, 0.15, { Scale = 1.04 }, Enum.EasingStyle.Back)
	end)
	b.MouseLeave:Connect(function()
		S.tween(scale, 0.15, { Scale = 1 })
	end)
	return b
end

-- Ouvre la fenêtre ; renvoie sa fonction de fermeture.
function Parametres.open(root: Frame, currentId: string, callbacks: Callbacks): () -> ()
	local panel = S.panel(root, Vector2.new(560, 360), Vector2.new(220, 100))
	local close = S.titleBar(panel, "Settings", { close = true, color = S.GRIS, dark = S.GRIS_FONCE })
	S.text(panel, "Choisis ton monde", 28, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 36), strokeThickness = 3 })
	local message = S.text(panel, "", 16, { TextColor3 = Color3.fromHex("#FF6B6B"), Position = UDim2.fromOffset(0, 318), Size = UDim2.new(1, 0, 0, 24) })
	S.popIn(panel)

	local closed = false
	local function destroy()
		if not closed then
			closed = true
			panel:Destroy()
		end
	end
	local busy = false
	local gap = 20
	local x0 = (560 - (#Mondes.list * CARD.X + (#Mondes.list - 1) * gap)) / 2
	for i, monde in Mondes.list do
		local b = card(panel, monde, x0 + (i - 1) * (CARD.X + gap), monde.id == currentId)
		b.Activated:Connect(function()
			if busy or monde.id == currentId then
				return
			end
			busy = true
			message.Text = ""
			local ok = callbacks.onChoose(monde.id, function(text)
				message.Text = text or ""
			end)
			busy = false
			if ok then
				destroy()
			end
		end)
	end
	if close then
		close.Activated:Connect(function()
			destroy()
			callbacks.onClose()
		end)
	end
	return destroy
end

return Parametres
