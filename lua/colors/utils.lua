local api = vim.api
local M   = {}

-- Tiny helper to fetch gui-colours as hex strings
function M.get_hl(name)
	local hl = api.nvim_get_hl(0, { name = name })
	local function to_hex(n) return n and ("#%06x"):format(n) or nil end
	return { fg = to_hex(hl.fg), bg = to_hex(hl.bg) }
end

return M
