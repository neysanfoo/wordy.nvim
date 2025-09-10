local cfg = require("wordy.config")
local core = require("wordy.core")
local M = {}

function M.setup(opts)
	cfg.merge(opts or {})
end

function M.new_game(opts)
	core.new_game(opts or {})
end

return M
