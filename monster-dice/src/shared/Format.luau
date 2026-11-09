--!strict
-- Abréviation des grands nombres (k, m, b, t, qd, qn…) : « 7.7qd », « 65t », « 1.2t », « 48m ».
-- Une décimale sous 10, entier au-dessus, comme dans les fenêtres de la Tour des défis.

local SUFFIXES = { "", "k", "m", "b", "t", "qd", "qn", "sx", "sp", "oc", "no", "dc" }

local Format = {}

function Format.big(n: number): string
	local signe = if n < 0 then "-" else ""
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	-- 1e-6 : les divisions successives donnent parfois 252.99999 au lieu de 253
	local texte = if n < 10 then string.format("%.1f", n) else tostring(math.floor(n + 1e-6))
	return signe .. texte:gsub("%.0$", "") .. SUFFIXES[i]
end

-- Version précise pour l'argent du joueur : deux décimales, zéros inutiles retirés (« 17.42k », « 510 », « 1.5m »).
function Format.precise(n: number): string
	local signe = if n < 0 then "-" else ""
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local texte = string.format("%.2f", math.floor(n * 100 + 1e-6) / 100):gsub("0+$", ""):gsub("%.$", "")
	return signe .. texte .. SUFFIXES[i]
end

-- Pourcentage de drop : « 2% », « 1.5% », « 0.25% », « 0.02% ».
function Format.percent(chance: number): string
	local texte = string.format("%.2f", chance * 100):gsub("0+$", ""):gsub("%.$", "")
	return texte .. "%"
end

assert(Format.big(7.7e15) == "7.7qd" and Format.big(1e15) == "1qd" and Format.big(65e12) == "65t")
assert(Format.big(48e6) == "48m" and Format.big(1.2e12) == "1.2t" and Format.big(-253e15) == "-253qd")
assert(Format.big(999) == "999" and Format.big(0) == "0")
assert(Format.precise(17420) == "17.42k" and Format.precise(510) == "510" and Format.precise(1.5e6) == "1.5m")
assert(Format.percent(0.02) == "2%" and Format.percent(0.015) == "1.5%" and Format.percent(0.0002) == "0.02%")

return table.freeze(Format)
