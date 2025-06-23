local C = {}

C.colors = {
	border = { fg = "#565758" },
	typed = { fg = "#ffffff" },
	correct = { bg = "#538d4e", fg = "#ffffff" },
	present = { bg = "#b59f3b", fg = "#ffffff" },
	absent = { fg = "#777777" },
}

function C.merge(user)
	return vim.tbl_deep_extend("force", C, user or {})
end

return C
