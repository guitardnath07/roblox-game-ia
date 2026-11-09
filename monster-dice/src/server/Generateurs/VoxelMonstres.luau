--!strict
-- Bibliothèque de décors « en cubes » du monde des monstres, dans le style de la map des héros : chaque modèle est
-- fait de petits cubes colorés dont l'ombrage est peint dans la couleur (ServerStorage.VoxelGen), puis fusionné
-- en une seule pièce. Lancer à la main dans Studio (Edit) :
--   require(game.ServerScriptService.Server.Generateurs.VoxelMonstres).build()
-- Résultat : ServerStorage.VoxelLibMonstres (Arbres, Plantes, Rochers, Decors), relançable sans doublons.

local ServerStorage = game:GetService("ServerStorage")

local G = require(ServerStorage:WaitForChild("VoxelGen")) :: any

local VoxelMonstres = {}

local C = Color3.fromHex
local BARK = { C("#4A3448"), C("#563C52"), C("#3E2A3C") }

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	local n = Instance.new("Folder")
	n.Name = name
	n.Parent = parent
	return n
end

-- Arbre mort : tronc tordu, branches nues en escalier, quelques touffes de feuilles violettes.
local function deadTree(parent: Instance, name: string, seed: number, h: number, leaves: boolean)
	local g = G.new(seed)
	G.trunk(g, h, 2, { bark = BARK, bend = 1.5 })
	local rng = g.rng
	for _ = 1, 6 do
		local y = math.floor(h * rng:NextNumber(0.45, 1))
		local a = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(3, 6)
		local from = Vector3.new(0.5, y, 0.5)
		local to = from + Vector3.new(math.cos(a) * len, rng:NextNumber(1.5, 4), math.sin(a) * len)
		G.branch(g, from, to, BARK[2])
		local a2 = a + rng:NextNumber(-1, 1)
		local tip = to + Vector3.new(math.cos(a2) * 2.5, rng:NextNumber(1, 3), math.sin(a2) * 2.5)
		G.branch(g, to, tip, BARK[1])
		if leaves and rng:NextNumber() < 0.6 then
			G.blob(g, tip.X, tip.Y + 0.5, tip.Z, 1.8, 1.4, 1.8, 0.35, seed + y, { C("#8A58D0"), C("#7446B8"), C("#6338A0") }, { hole = 0.2, bump = 0.12 })
		end
	end
	return G.build(g, 0.6, name, parent, { trunk = 1.4, trunkH = h * 0.6 * 0.6 })
end

-- Arbre hanté : tronc courbé, grand feuillage violet à fruits lumineux, lianes qui pendent.
local function hauntedTree(parent: Instance, name: string, seed: number, h: number)
	local g = G.new(seed)
	G.trunk(g, h, 2, { bark = BARK, bend = 2 })
	local cy = h + 2
	local pal = { C("#8452CC"), C("#7042B6"), C("#5E369E"), C("#9A66DE") }
	G.blob(g, 0.5, cy, 0.5, 6, 4, 6, 0.3, seed, pal, { hole = 0.08, bump = 0.09, dots = { C("#FFD24A"), C("#4FF0D8") }, dotRate = 0.025 })
	local rng = g.rng
	for _ = 1, 16 do -- lianes
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = math.floor(0.5 + math.cos(a) * 5.5 + 0.5), math.floor(0.5 + math.sin(a) * 5.5 + 0.5)
		for k = 1, rng:NextInteger(2, 6) do
			G.set(g, x, cy - 2 - k, z, G.mul(pal[3], 0.95 - k * 0.06))
		end
	end
	return G.build(g, 0.6, name, parent, { trunk = 1.4, trunkH = h * 0.6 })
end

-- Champignon géant : pied crème, chapeau bombé à pois, lamelles claires dessous.
local function mushroom(parent: Instance, name: string, seed: number, h: number, r: number, cap: { Color3 }, dots: { Color3 })
	local g = G.new(seed)
	G.blob(g, 0, 0, 0, r, r * 0.55, r, 0.12, seed, cap, { flat = true, hole = 0, bump = 0.04, dots = dots, dotRate = 0.14 })
	for x = -r + 1, r - 1 do
		for z = -r + 1, r - 1 do
			if x * x + z * z <= (r - 1) * (r - 1) and not G.has(g, x, -1, z) then
				G.set(g, x, -1, z, G.mul(C("#F2D6C4"), if (x + z) % 2 == 0 then 0.92 else 0.78)) -- lamelles
			end
		end
	end
	for y = -h, -2 do -- pied (2×2) avec un anneau
		for x = 0, 1 do
			for z = 0, 1 do
				G.set(g, x, y, z, G.mul(C("#F2E8DA"), 0.8 + 0.2 * (y + h) / h))
			end
		end
		if y == -3 then
			for x = -1, 2 do
				for z = -1, 2 do
					if not G.has(g, x, y, z) then
						G.set(g, x, y, z, C("#E6DCC8"))
					end
				end
			end
		end
	end
	return G.build(g, 0.5, name, parent, { trunk = 1, trunkH = h * 0.5 })
end

-- Citrouille côtelée (et version lanterne au visage lumineux).
local function pumpkin(parent: Instance, name: string, seed: number, lantern: boolean)
	local g = G.new(seed)
	G.blob(g, 0, 2, 0, 3.4, 2.6, 3.4, 0.05, seed, { C("#F08A24"), C("#E8801E"), C("#F49A34") }, { hole = 0, bump = 0 })
	for _, cell in g.cells do
		local a = math.atan2(cell[3], cell[1])
		if math.abs(math.sin(a * 4)) < 0.22 then
			cell[4] = G.mul(cell[4], 0.78) -- côtes
		end
		if lantern and cell[3] < -2 and cell[2] >= 2 and cell[2] <= 3 and math.abs(cell[1]) >= 1 and math.abs(cell[1]) <= 2 then
			cell[4] = C("#FFE070") -- yeux
		elseif lantern and cell[3] < -2 and cell[2] == 1 and math.abs(cell[1]) <= 2 then
			cell[4] = C("#FFE070") -- bouche
		end
	end
	G.set(g, 0, 5, 0, C("#5E7A2E"))
	G.set(g, 0, 6, 0, C("#4E6A26"))
	G.set(g, 1, 6, 0, C("#4E6A26"))
	G.set(g, 2, 5, 1, C("#5E9A34"))
	G.set(g, 2, 5, 0, C("#4E8A2E"))
	return G.build(g, 0.4, name, parent, {})
end

-- Buisson (vert ou violet) à baies.
local function bush(parent: Instance, name: string, seed: number, pal: { Color3 }, berries: { Color3 })
	local g = G.new(seed)
	G.blob(g, 0, 1, 0, 3.5, 2.6, 3.5, 0.3, seed, pal, { flat = true, hole = 0.08, bump = 0.1, dots = berries, dotRate = 0.05 })
	return G.build(g, 0.5, name, parent, {})
end

-- Herbe hantée : brins de 2 à 5 cubes, pointes plus claires.
local function grass(parent: Instance, name: string, seed: number, pal: { Color3 })
	local g = G.new(seed)
	local rng = g.rng
	for _ = 1, 22 do
		local x, z = rng:NextInteger(-3, 3), rng:NextInteger(-3, 3)
		local h = rng:NextInteger(2, 5)
		local c = pal[rng:NextInteger(1, #pal)]
		for y = 0, h - 1 do
			G.set(g, x, y, z, G.mul(c, 0.75 + 0.45 * y / h))
		end
	end
	return G.build(g, 0.35, name, parent, {})
end

-- Amas de cristaux : colonnes qui penchent vers l'extérieur, pointe blanche.
local function crystals(parent: Instance, name: string, seed: number, pal: { Color3 })
	local g = G.new(seed)
	local rng = g.rng
	G.blob(g, 0, 0, 0, 3, 1.4, 3, 0.25, seed, { C("#5C5478"), C("#4A4266") }, { flat = true, hole = 0, bump = 0 })
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2
		local x, z = (if k == 1 then 0 else math.cos(a) * 1.6), (if k == 1 then 0 else math.sin(a) * 1.6)
		local h = if k == 1 then 10 else rng:NextInteger(4, 8)
		local c = pal[rng:NextInteger(1, #pal)]
		for y = 1, h do
			local lean = (y / h) * (if k == 1 then 0 else 1.6)
			local px, pz = math.floor(x + math.cos(a) * lean + 0.5), math.floor(z + math.sin(a) * lean + 0.5)
			local col = if y == h then C("#F4ECFF") else G.mul(c, 0.7 + 0.5 * y / h)
			G.set(g, px, y, pz, col)
			if y < h - 1 then
				G.set(g, px + 1, y, pz, G.mul(col, 0.85))
				G.set(g, px, y, pz + 1, G.mul(col, 0.92))
			end
		end
	end
	return G.build(g, 0.45, name, parent, { collide = true })
end

-- Rocher lavande, un peu de mousse sur le dessus.
local function rock(parent: Instance, name: string, seed: number, rx: number, ry: number)
	local g = G.new(seed)
	G.blob(g, 0, 0, 0, rx, ry, rx * 0.85, 0.28, seed, { C("#7E74A0"), C("#6E6490"), C("#8E84B0") }, { flat = true, hole = 0, bump = 0.05, dots = { C("#72C24C") }, dotRate = 0.06 })
	return G.build(g, 0.6, name, parent, { collide = true })
end

-- Pierre tombale : stèle arrondie, croix en creux, mousse au pied.
local function tomb(parent: Instance, name: string, seed: number, cross: boolean)
	local g = G.new(seed)
	local stone = { C("#A69EC0"), C("#9890B2"), C("#B0A8CA") }
	for x = -3, 3 do
		for y = 0, 9 do
			for z = 0, 1 do
				local corner = y >= 8 and math.abs(x) == 3 or y == 9 and math.abs(x) == 2
				if not corner then
					local c = G.mul(stone[g.rng:NextInteger(1, 3)], 0.8 + 0.25 * (if z == 0 then 1 else 0.6))
					if z == 0 and cross and ((x == 0 and y >= 3 and y <= 7) or (y == 6 and math.abs(x) <= 1)) then
						c = C("#5C5478") -- croix gravée
					end
					G.set(g, x, y, z, c)
				end
			end
		end
	end
	for x = -4, 4 do
		for z = -1, 2 do
			if g.rng:NextNumber() < 0.55 then
				G.set(g, x, -1, z, G.mul(C("#72C24C"), g.rng:NextNumber(0.75, 1.05))) -- mousse au pied
			end
		end
	end
	return G.build(g, 0.35, name, parent, { collide = true })
end

function VoxelMonstres.build(): Folder
	local lib = folder(ServerStorage, "VoxelLibMonstres")
	local trees = folder(lib, "Arbres")
	local plants = folder(lib, "Plantes")
	local rocks = folder(lib, "Rochers")
	local decor = folder(lib, "Decors")
	deadTree(trees, "ArbreMort1", 11, 12, false)
	deadTree(trees, "ArbreMort2", 12, 16, true)
	deadTree(trees, "ArbreMort3", 13, 10, true)
	hauntedTree(trees, "ArbreHante1", 14, 12)
	hauntedTree(trees, "ArbreHante2", 15, 15)
	mushroom(trees, "ChampignonGeant1", 16, 9, 6, { C("#D8468E"), C("#C23A7E"), C("#E05A9E") }, { C("#FFF4E0") })
	mushroom(trees, "ChampignonGeant2", 17, 7, 5, { C("#8A4FD8"), C("#7842C4"), C("#9A62E6") }, { C("#4FF0D8") })
	mushroom(plants, "Champignon1", 18, 4, 3, { C("#D8468E"), C("#C23A7E") }, { C("#FFF4E0") })
	mushroom(plants, "Champignon2", 19, 3, 2, { C("#F07A3A"), C("#E06A2E") }, { C("#FFF4E0") })
	mushroom(plants, "Champignon3", 20, 5, 3, { C("#8A4FD8"), C("#7842C4") }, { C("#4FF0D8") })
	pumpkin(plants, "Citrouille1", 21, false)
	pumpkin(plants, "Citrouille2", 22, false)
	pumpkin(plants, "CitrouilleLanterne", 23, true)
	bush(plants, "Buisson1", 24, { C("#5AAE44"), C("#4A9A3A"), C("#68BE50") }, { C("#E0345A") })
	bush(plants, "Buisson2", 25, { C("#7A4EB0"), C("#6A42A0"), C("#8A5EC0") }, { C("#4FF0D8") })
	bush(plants, "Buisson3", 26, { C("#4E9A3A"), C("#3E8A30") }, { C("#FFD24A") })
	grass(plants, "Herbe1", 27, { C("#6CBA48"), C("#5AA83C") })
	grass(plants, "Herbe2", 28, { C("#8A58D0"), C("#2FB8A6") })
	crystals(decor, "Cristaux1", 29, { C("#9A5CF0"), C("#B07CFF") })
	crystals(decor, "Cristaux2", 30, { C("#2FB8A6"), C("#4FE0CC") })
	tomb(decor, "Tombe1", 31, true)
	tomb(decor, "Tombe2", 32, false)
	rock(rocks, "Rocher1", 33, 4, 3)
	rock(rocks, "Rocher2", 34, 6, 3.5)
	rock(rocks, "Rocher3", 35, 3, 2.5)
	return lib
end

return VoxelMonstres
