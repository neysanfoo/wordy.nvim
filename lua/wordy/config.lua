local C = {
	colors = {
		border  = nil,
		typed   = nil,
		correct = nil,
		present = nil,
		absent  = nil,
		title   = nil,
		error   = nil,
	},
}

function C.merge(user)
	user = user or {}
	local merged = vim.tbl_deep_extend("force", {}, C, user)
	for k, v in pairs(merged) do C[k] = v end
	return C
end

return C
