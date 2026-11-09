--!strict
-- Limiteur de débit par clé (souvent un Player) : une action au plus toutes les `interval` secondes.
-- Les appels trop rapides sont refusés et ne repoussent pas la fenêtre (sinon le spam bloquerait le joueur).

export type RateLimit = {
	allow: (self: RateLimit, key: any, interval: number, now: number?) -> boolean,
	forget: (self: RateLimit, key: any) -> (),
}

local RateLimit = {}

function RateLimit.new(): RateLimit
	local last: { [any]: number } = {}
	local limiter = {}

	function limiter.allow(_self: RateLimit, key: any, interval: number, now: number?): boolean
		local t = now or os.clock()
		local previous = last[key]
		if previous and t - previous < interval then
			return false
		end
		last[key] = t
		return true
	end

	function limiter.forget(_self: RateLimit, key: any)
		last[key] = nil
	end

	return limiter :: RateLimit
end

return RateLimit
