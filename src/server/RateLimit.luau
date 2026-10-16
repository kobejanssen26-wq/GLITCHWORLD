-- Token-bucket rate limiter for client-triggered remotes (per player, per key).
local RateLimit = {}

local buckets: { [Player]: { [string]: { tokens: number, t: number } } } = {}

-- allow(player, "buy", 4, 8): up to `burst` calls at once, refilling `perSecond` tokens per second.
function RateLimit.allow(player: Player, key: string, perSecond: number, burst: number?): boolean
	local now = os.clock()
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local b = pb[key]
	local cap = burst or perSecond
	if not b then
		b = { tokens = cap, t = now }
		pb[key] = b
	end
	b.tokens = math.min(cap, b.tokens + (now - b.t) * perSecond)
	b.t = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function RateLimit.forget(player: Player)
	buckets[player] = nil
end

return RateLimit
