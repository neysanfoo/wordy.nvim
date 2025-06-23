vim.api.nvim_create_user_command("Wordy", function(args)
	require("wordy").new_game(args)
end, { desc = "Start a Wordy game" })
