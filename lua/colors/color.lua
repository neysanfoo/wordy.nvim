local M = {}

local function hex2rgb(hex)
	hex = hex:gsub("#", "")
	return tonumber(hex:sub(1, 2), 16),
			tonumber(hex:sub(3, 4), 16),
			tonumber(hex:sub(5, 6), 16)
end

local function rgb2hex(r, g, b) return ("#%02x%02x%02x"):format(r, g, b) end

function M.mix(a, b, pct)
	pct = (pct or 50) / 100
	local r1, g1, b1 = hex2rgb(a)
	local r2, g2, b2 = hex2rgb(b)
	return rgb2hex(
		r1 * (1 - pct) + r2 * pct,
		g1 * (1 - pct) + g2 * pct,
		b1 * (1 - pct) + b2 * pct
	)
end

function M.change_hex_lightness(hex, percent)
	local r, g, b = hex2rgb(hex)
	r = math.min(255, math.max(0, r + r * percent / 100))
	g = math.min(255, math.max(0, g + g * percent / 100))
	b = math.min(255, math.max(0, b + b * percent / 100))
	return rgb2hex(r, g, b)
end

return M
