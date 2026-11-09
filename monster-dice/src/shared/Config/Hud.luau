--!strict
-- HUD principal (boutons de navigation, dé, argent, offres). Interface seulement pour l'instant :
-- les systèmes (tirage, argent…) ne sont pas encore faits, le HUD lit donc des attributs du joueur
-- que ces systèmes rempliront plus tard (voir `attributes`) et affiche 0 en attendant.
--
-- Icônes : images gratuites du Creator Store choisies une par une (seules les images sont utilisées, aucun
-- modèle ni script). Si une image est retirée par Roblox, l'emoji `emoji` s'affiche à sa place.

export type Icon = { emoji: string, image: string? }
export type Product = { name: string, productId: number?, robux: number }

local Hud = {}

Hud.icons = table.freeze({
	hub = { emoji = "🏆", image = "rbxassetid://17240711173" }, -- trophée « 1 »
	home = { emoji = "🏠", image = "rbxassetid://15403180857" }, -- maison cartoon au toit rouge
	shopTop = { emoji = "💵", image = "rbxassetid://131625469621882" }, -- panier 3D
	shop = { emoji = "🎁", image = "rbxassetid://131625469621882" }, -- panier 3D
	rebirth = { emoji = "🔄", image = "rbxassetid://18367579959" },
	index = { emoji = "📘", image = "rbxassetid://80718456338435" }, -- livre vert 3D
	settings = { emoji = "⚙️", image = "rbxassetid://17368089841" }, -- engrenage
	upgrades = { emoji = "⬆️", image = "rbxassetid://77414404556243" }, -- double flèche verte
	ultraLuck = { emoji = "✨", image = "rbxassetid://112114985165665" }, -- trèfle doré étincelant
	jackpot = { emoji = "💎", image = "rbxassetid://17368064384" }, -- gemme
	robux = { emoji = "", image = "rbxassetid://15403000023" }, -- pastille de prix
	daily = { emoji = "📅", image = "rbxassetid://17368188494" }, -- calendrier
	friends = { emoji = "👥", image = "rbxassetid://17368071983" },
	star = { emoji = "⭐", image = "rbxassetid://17368097932" }, -- étincelles des effets
	-- téléportation vers les mondes : emoji des cartes de Config/Mondes (EMPLACEMENT PROVISOIRE, sans image)
	mondeMonstres = { emoji = "👹" },
	mondeHeros = { emoji = "🛡️" },
} :: { [string]: Icon })

-- Offres à droite. L'achat n'est branché que si `productId` (Developer Product) est renseigné ;
-- sinon le bouton affiche « Bientôt disponible ».
Hud.products = table.freeze({
	ultraLuck = { name = "Ultra Luck", productId = nil, robux = 400 },
	jackpotRoll = { name = "Jackpot Roll", productId = nil, robux = 64 },
} :: { [string]: Product })

-- Attributs du Player lus par le HUD (remplis par les futurs systèmes côté serveur).
Hud.attributes = table.freeze({
	money = "Argent", -- number
	friendBoost = "BonusAmis", -- number, 0.03 = +3 %
	upgradesReady = "AmeliorationsDispo", -- number, badge rouge sur « Upgrades »
	shopAlert = "AlerteShop", -- boolean, pastille « ! » sur « Shop »
})

-- Disposition de référence (écran 1280 × 720), mise à l'échelle sur les autres écrans.
Hud.design = Vector2.new(1280, 720)

return table.freeze(Hud)
