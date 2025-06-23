local M = {}

local cfg = require("wordy.config")
local wl = require("wordy.wordlist")

local GRID_ROWS = 6
local GRID_COLS = 5
local BOX_WIDTH = 10
local KEYBOARD_ROWS = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
local KEYBOARD_INDENTS = { -1, 1, 4 }
local DEFAULT_FLASH_DURATION = 1200

local answers = wl.answers
local allowed = wl.allowed

local state_file = vim.fn.stdpath("state") .. "/wordy_state.json"

local game_state = {
	buf = nil,
	win = nil,
	mode = "normal",
	cursor_pos = 1,
	current_guess = "",
	current_row = 1,
	grid_start_line = 0,
	guesses = {},
	center_offset = 0,
	finished = false,
	result = nil,
	message = nil,
	message_hl = nil,
	message_timer = nil,
}

local colors = vim.deepcopy(cfg.colors)
local TARGET = ""
local alpha_status = {}

local function initialize_game_target()
	math.randomseed(os.time())
	TARGET = answers[math.random(#answers)]
end

---@param word string
---@return boolean
local function is_valid_word(word)
	return allowed[word:upper()] ~= nil
end

local function setup_highlight_groups()
	local highlight_groups = {
		WordyBorder = colors.border,
		WordyTitle = { fg = "#ffffff", bold = true },
		WordyTyped = colors.typed,
		WordyCorrect = colors.correct,
		WordyPresent = colors.present,
		WordyAbsent = colors.absent,
		WordyError = { fg = "#ff4d4f", bold = true },
	}

	for group, opts in pairs(highlight_groups) do
		vim.api.nvim_set_hl(0, group, opts)
	end
end

local function save_game_state()
	local data = {
		target = TARGET,
		guesses = game_state.guesses,
		current_row = game_state.current_row,
		current_guess = game_state.current_guess,
		alpha_status = alpha_status,
		finished = game_state.finished,
		result = game_state.result,
	}

	local ok, json = pcall(vim.fn.json_encode, data)
	if ok then
		pcall(vim.fn.writefile, { json }, state_file)
	end
end

---@return table|nil
local function load_game_state()
	if vim.fn.filereadable(state_file) ~= 1 then
		return nil
	end

	local ok, text = pcall(vim.fn.readfile, state_file)
	if not ok or #text == 0 then
		return nil
	end

	local ok2, data = pcall(vim.fn.json_decode, table.concat(text, ""))
	if ok2 and type(data) == "table" then
		return data
	end

	return nil
end

local function clear_saved_state()
	if vim.fn.filereadable(state_file) == 1 then
		pcall(os.remove, state_file)
	end
end

---@param row number
---@return string
local function get_row_display_text(row)
	if row == game_state.current_row then
		local text = game_state.current_guess
		while #text < GRID_COLS do
			text = text .. " "
		end
		return text
	elseif row <= #game_state.guesses then
		return game_state.guesses[row].word
	else
		return string.rep(" ", GRID_COLS)
	end
end

---@param row number
---@param col number
---@return string|nil
local function get_cell_highlight(row, col)
	if row == game_state.current_row then
		if col <= #game_state.current_guess then
			return "WordyTyped"
		end
	elseif row <= #game_state.guesses then
		local guess_data = game_state.guesses[row]
		if guess_data.evaluation and guess_data.evaluation[col] then
			local eval = guess_data.evaluation[col]
			local highlight_map = {
				correct = "WordyCorrect",
				present = "WordyPresent",
				absent = "WordyAbsent",
			}
			return highlight_map[eval]
		end
	end
	return nil
end

---@return table lines, table highlights
local function create_grid()
	local lines = {}
	local highlights = {}

	for row = 1, GRID_ROWS do
		local display_text = get_row_display_text(row)

		local top_line = ""
		for col = 1, GRID_COLS do
			top_line = top_line .. "┌───┐"
			if col < GRID_COLS then
				top_line = top_line .. " "
			end
		end
		table.insert(lines, top_line)

		local middle_line = ""
		for col = 1, GRID_COLS do
			local char = display_text:sub(col, col)
			middle_line = middle_line .. "│ " .. char .. " │"
			if col < GRID_COLS then
				middle_line = middle_line .. " "
			end
		end
		table.insert(lines, middle_line)

		for col = 1, GRID_COLS do
			local hl_group = get_cell_highlight(row, col)
			if hl_group then
				table.insert(highlights, {
					line = #lines - 1,
					col_start = (col - 1) * BOX_WIDTH + 1,
					col_end = (col - 1) * BOX_WIDTH + 6,
					hl_group = hl_group,
				})
			end
		end

		local bottom_line = ""
		for col = 1, GRID_COLS do
			bottom_line = bottom_line .. "└───┘"
			if col < GRID_COLS then
				bottom_line = bottom_line .. " "
			end
		end
		table.insert(lines, bottom_line)
	end

	return lines, highlights
end

---@return table lines, table highlights
local function render_keyboard()
	local k_lines, k_hls = {}, {}

	for row_idx, row_chars in ipairs(KEYBOARD_ROWS) do
		local indent = KEYBOARD_INDENTS[row_idx]
		local line = string.rep(" ", indent)

		for i = 1, #row_chars do
			local char = row_chars:sub(i, i)
			local col = indent + (i - 1) * 2

			local status = alpha_status[char]
			if status then
				local hl_group_map = {
					correct = "WordyCorrect",
					present = "WordyPresent",
					absent = "WordyAbsent",
				}
				local hl_group = hl_group_map[status]
				if hl_group then
					table.insert(k_hls, { line = row_idx - 1, col = col, hl = hl_group })
				end
			end

			line = line .. char .. " "
		end
		table.insert(k_lines, line)
	end

	return k_lines, k_hls
end

---@return table lines, table highlights
local function create_display()
	local lines = {}
	local highlights = {}

	table.insert(lines, "")

	table.insert(lines, "╔═══════════════════════════╗")
	table.insert(lines, "║           WORDY           ║")
	table.insert(lines, "╚═══════════════════════════╝")

	-- Store where grid starts for cursor positioning
	game_state.grid_start_line = #lines

	local grid_lines, grid_highlights = create_grid()
	for _, line in ipairs(grid_lines) do
		table.insert(lines, line)
	end

	for _, hl in ipairs(grid_highlights) do
		hl.line = hl.line + game_state.grid_start_line
		table.insert(highlights, hl)
	end

	local kb_lines, kb_hls = render_keyboard()
	for _, line in ipairs(kb_lines) do
		table.insert(lines, line)
	end
	local kb_start = #lines - #kb_lines

	for _, h in ipairs(kb_hls) do
		table.insert(highlights, {
			line = kb_start + h.line,
			col_start = game_state.center_offset + h.col,
			col_end = game_state.center_offset + h.col + 1,
			hl_group = h.hl,
		})
	end

	table.insert(lines, "")

	local status_lines = {}
	if game_state.mode == "insert" then
		table.insert(status_lines, "-- INSERT -- | Esc: normal")
		table.insert(status_lines, "Enter: submit")
	else
		table.insert(status_lines, "-- NORMAL -- | i: insert")
		table.insert(status_lines, "q: quit | Enter: submit")
	end

	table.insert(status_lines, "")

	for _, line in ipairs(status_lines) do
		table.insert(lines, line)
	end

	return lines, highlights
end

---@return table lines, table highlights
local function create_end_display()
	local title = (game_state.result == "win") and "Correct!" or "Nice Try"
	local tries = #game_state.guesses
	local lines = {
		"",
		"╔═══════════════════════════╗",
		string.format("║  %-25s║", title),
		"╚═══════════════════════════╝",
		"",
		"Word : " .. TARGET:upper(),
		"Tries: " .. tries .. "/" .. GRID_ROWS,
		"",
		"[r] play again    [q] quit",
		"",
	}
	return lines, {}
end

---@param lines table
---@param window_width number
---@return table
local function center_content(lines, window_width)
	local centered_lines = {}

	for _, line in ipairs(lines) do
		local line_width = vim.fn.strdisplaywidth(line)
		local total_pad = math.max(0, window_width - line_width)
		local left_pad = math.floor(total_pad / 2)
		local right_pad = total_pad - left_pad

		local centered_line = string.rep(" ", left_pad) .. line .. string.rep(" ", right_pad)
		table.insert(centered_lines, centered_line)
	end

	return centered_lines
end

---@return number line, number col
local function calculate_cursor_position()
	local target_line = game_state.grid_start_line + (game_state.current_row - 1) * 3 + 2

	local in_box_offset = (game_state.cursor_pos <= #game_state.current_guess) and 6 or 3

	local target_col = game_state.center_offset + (game_state.cursor_pos - 1) * BOX_WIDTH + in_box_offset

	return target_line, target_col
end

local function set_cursor_position()
	if not game_state.buf or not vim.api.nvim_buf_is_valid(game_state.buf) then
		return
	end

	if not game_state.win or not vim.api.nvim_win_is_valid(game_state.win) then
		return
	end

	if game_state.mode ~= "insert" then
		return
	end

	local target_line, target_col = calculate_cursor_position()
	pcall(vim.api.nvim_win_set_cursor, game_state.win, { target_line, target_col })
end

local function update_display()
	if not game_state.buf or not vim.api.nvim_buf_is_valid(game_state.buf) then
		return
	end

	if not game_state.win or not vim.api.nvim_win_is_valid(game_state.win) then
		return
	end

	local win_width = vim.api.nvim_win_get_width(game_state.win)
	local content_width = 29
	game_state.center_offset = math.max(0, math.floor((win_width - content_width) / 2))

	local lines, highlights
	if game_state.finished then
		lines, highlights = create_end_display()
	else
		lines, highlights = create_display()
	end

	local banner_line
	if game_state.message then
		table.insert(lines, " " .. game_state.message .. " ")
		banner_line = #lines - 1
	end

	local centered_lines = center_content(lines, win_width)

	if banner_line then
		local centred = centered_lines[banner_line + 1]
		local start = centred:find(game_state.message, 1, true) - 2
		local finish = start + #game_state.message + 1
		table.insert(highlights, {
			line = banner_line,
			col_start = start,
			col_end = finish,
			hl_group = game_state.message_hl or "WordyError",
		})
	end

	vim.api.nvim_buf_clear_namespace(game_state.buf, -1, 0, -1)
	vim.api.nvim_set_option_value("modifiable", true, { buf = game_state.buf })
	vim.api.nvim_buf_set_lines(game_state.buf, 0, -1, false, centered_lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = game_state.buf })

	for i, line in ipairs(centered_lines) do
		if line:match("WORDY") then
			local start_col = line:find("WORDY") - 1
			vim.api.nvim_buf_add_highlight(game_state.buf, -1, "WordyTitle", i - 1, start_col, start_col + 6)
			break
		end
	end

	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(
			game_state.buf,
			-1,
			hl.hl_group,
			hl.line,
			hl.col_start + game_state.center_offset,
			hl.col_end + game_state.center_offset
		)
	end

	if game_state.mode == "insert" then
		vim.schedule(set_cursor_position)
	end

	save_game_state()
end

---@param msg string
---@param hl_group string
---@param duration number|nil
local function flash_message(msg, hl_group, duration)
	if game_state.message_timer then
		game_state.message_timer:stop()
		game_state.message_timer:close()
		game_state.message_timer = nil
	end

	game_state.message = msg
	game_state.message_hl = hl_group
	update_display()

	game_state.message_timer = vim.defer_fn(function()
		game_state.message, game_state.message_hl = nil, nil
		update_display()
		game_state.message_timer = nil
	end, duration or DEFAULT_FLASH_DURATION)
end

---@param guess string
---@return table
local function evaluate_guess(guess)
	local result = { "absent", "absent", "absent", "absent", "absent" }
	local target_bytes = { TARGET:byte(1, 5) }
	local used = { false, false, false, false, false }

	for i = 1, GRID_COLS do
		if guess:byte(i) == target_bytes[i] then
			result[i], used[i] = "correct", true
			alpha_status[guess:sub(i, i)] = "correct"
		end
	end

	for i = 1, GRID_COLS do
		if result[i] == "absent" then
			local guess_byte = guess:byte(i)
			for j = 1, GRID_COLS do
				if not used[j] and guess_byte == target_bytes[j] then
					result[i], used[j] = "present", true
					if alpha_status[guess:sub(i, i)] ~= "correct" then
						alpha_status[guess:sub(i, i)] = "present"
					end
					break
				end
			end
			if result[i] == "absent" and not alpha_status[guess:sub(i, i)] then
				alpha_status[guess:sub(i, i)] = "absent"
			end
		end
	end

	return result
end

local function submit_guess()
	if #game_state.current_guess ~= GRID_COLS then
		flash_message("Word must be 5 letters!", "WordyError")
		return
	end

	if not is_valid_word(game_state.current_guess) then
		flash_message("Not in dictionary!", "WordyError")
		return
	end

	local eval = evaluate_guess(game_state.current_guess)
	table.insert(game_state.guesses, {
		word = game_state.current_guess,
		evaluation = eval,
	})

	local all_correct = true
	for i = 1, GRID_COLS do
		if eval[i] ~= "correct" then
			all_correct = false
			break
		end
	end

	if all_correct then
		game_state.finished = true
		game_state.result = "win"
		clear_saved_state()
		enter_normal_mode()
		update_display()
		return
	end

	game_state.current_row = game_state.current_row + 1
	game_state.current_guess = ""
	game_state.cursor_pos = 1

	if game_state.current_row > GRID_ROWS then
		game_state.finished = true
		game_state.result = "lose"
		clear_saved_state()
		enter_normal_mode()
		update_display()
	else
		update_display()
	end
end

---@param letter string
local function add_letter(letter)
	if game_state.finished then
		return
	end

	if #game_state.current_guess >= GRID_COLS then
		flash_message("Word must be 5 letters!", "WordyError")
		return
	end

	local upper_letter = letter:upper()

	if game_state.cursor_pos > #game_state.current_guess then
		game_state.current_guess = game_state.current_guess .. upper_letter
	else
		local before = game_state.current_guess:sub(1, game_state.cursor_pos - 1)
		local after = game_state.current_guess:sub(game_state.cursor_pos + 1)
		game_state.current_guess = before .. upper_letter .. after
	end

	game_state.cursor_pos = math.min(GRID_COLS, game_state.cursor_pos + 1)
	update_display()
end

local function delete_letter()
	if #game_state.current_guess == 0 then
		return
	end

	if game_state.cursor_pos > #game_state.current_guess then
		game_state.current_guess = game_state.current_guess:sub(1, -2)
		game_state.cursor_pos = math.max(1, #game_state.current_guess + 1)
	elseif game_state.cursor_pos == #game_state.current_guess then
		game_state.current_guess = game_state.current_guess:sub(1, -2)
		game_state.cursor_pos = math.max(1, game_state.cursor_pos)
	elseif game_state.cursor_pos > 1 then
		local before = game_state.current_guess:sub(1, game_state.cursor_pos - 2)
		local after = game_state.current_guess:sub(game_state.cursor_pos)
		game_state.current_guess = before .. after
		game_state.cursor_pos = game_state.cursor_pos - 1
	else
		game_state.current_guess = game_state.current_guess:sub(2)
	end

	update_display()
end

local function delete_forward()
	if game_state.cursor_pos <= #game_state.current_guess then
		local before = game_state.current_guess:sub(1, game_state.cursor_pos - 1)
		local after = game_state.current_guess:sub(game_state.cursor_pos + 1)
		game_state.current_guess = before .. after
		update_display()
	end
end

local function move_cursor_left()
	if game_state.cursor_pos > 1 then
		game_state.cursor_pos = game_state.cursor_pos - 1
		update_display()
	end
end

local function move_cursor_right()
	local max_pos = math.min(GRID_COLS, #game_state.current_guess + 1)
	if game_state.cursor_pos < max_pos then
		game_state.cursor_pos = game_state.cursor_pos + 1
		update_display()
	end
end

function enter_insert_mode()
	if game_state.finished then
		return
	end
	game_state.mode = "insert"
	game_state.cursor_pos = math.max(1, math.min(GRID_COLS, #game_state.current_guess + 1))
	update_display()

	vim.schedule(function()
		if game_state.win and vim.api.nvim_win_is_valid(game_state.win) then
			vim.cmd("startinsert")
		end
	end)
end

function enter_normal_mode()
	game_state.mode = "normal"
	update_display()

	vim.schedule(function()
		if game_state.win and vim.api.nvim_win_is_valid(game_state.win) then
			vim.cmd("stopinsert")
		end
	end)
end

---@param key string
local function handle_insert_key(key)
	if key == "<Esc>" then
		enter_normal_mode()
	elseif key:match("^[a-zA-Z]$") then
		add_letter(key)
	elseif key == "<BS>" or key == "Backspace" then
		delete_letter()
	elseif key == "<Del>" or key == "Delete" then
		delete_forward()
	elseif key == "<Left>" then
		move_cursor_left()
	elseif key == "<Right>" then
		move_cursor_right()
	elseif key == "<CR>" or key == "<Enter>" then
		submit_guess()
	end
end

---@param key string
local function handle_normal_key(key)
	if key == "q" or key == "<Esc>" then
		save_game_state()
		if game_state.win and vim.api.nvim_win_is_valid(game_state.win) then
			vim.api.nvim_win_close(game_state.win, true)
		end
	elseif key == "i" then
		enter_insert_mode()
	elseif key == "<CR>" or key == "<Enter>" then
		submit_guess()
	end
end

---@param key string
local function handle_key(key)
	if game_state.finished then
		if key == "q" or key == "<Esc>" then
			save_game_state()
			if game_state.win and vim.api.nvim_win_is_valid(game_state.win) then
				vim.api.nvim_win_close(game_state.win, true)
			end
		elseif key == "r" then
			clear_saved_state()
			initialize_game_target()
			alpha_status = {}
			M.new_game()
		end
		return
	end

	if game_state.mode == "insert" then
		handle_insert_key(key)
	else
		handle_normal_key(key)
	end
end

---@return number width, number height
local function calculate_window_size()
	local content_width = 29
	local padding = 10
	local min_width = content_width + padding

	local content_height = (GRID_ROWS * 3) + 12
	local min_height = content_height

	local term_width = vim.o.columns
	local term_height = vim.o.lines

	local win_width = math.min(min_width, term_width - 4)
	local win_height = math.min(min_height, term_height - 4)

	win_width = math.max(win_width, 35)
	win_height = math.max(win_height, 25)

	return win_width, win_height
end

local function setup_key_mappings()
	local function map_key(mode, key, action)
		vim.api.nvim_buf_set_keymap(game_state.buf, mode, key, "", {
			callback = function()
				handle_key(action or key)
			end,
			noremap = true,
			silent = true,
		})
	end

	local normal_keys = { "q", "<Esc>", "i", "<CR>", "<Enter>", "r" }
	for _, key in ipairs(normal_keys) do
		map_key("n", key, key)
	end

	local insert_keys = { "<Esc>", "<BS>", "<Del>", "<Left>", "<Right>", "<CR>", "<Enter>" }
	for _, key in ipairs(insert_keys) do
		map_key("i", key, key)
	end

	for i = 65, 90 do -- A-Z
		local char = string.char(i)
		map_key("i", char, char)
		map_key("i", char:lower(), char)
	end
end

local function setup_autocmds()
	if not game_state.buf or not vim.api.nvim_buf_is_valid(game_state.buf) then
		return
	end

	local group = vim.api.nvim_create_augroup("WordyResize", { clear = true })

	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			if game_state.win and vim.api.nvim_win_is_valid(game_state.win) then
				update_display()
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		buffer = game_state.buf,
		callback = function()
			save_game_state()
			game_state.buf = nil
			game_state.win = nil
			vim.api.nvim_del_augroup_by_id(group)
		end,
	})
end

local function initialize_game_state()
	game_state.mode = "normal"
	game_state.cursor_pos = 1
	game_state.current_guess = ""
	game_state.current_row = 1
	game_state.grid_start_line = 0
	game_state.guesses = {}
	game_state.center_offset = 0
	game_state.finished = false
	game_state.result = nil
end

function M.new_game()
	if game_state.win and vim.api.nvim_win_is_valid(game_state.win) then
		vim.api.nvim_win_close(game_state.win, true)
	end

	initialize_game_state()

	local saved = load_game_state()
	if saved and not saved.finished then
		TARGET = saved.target or TARGET
		game_state.guesses = saved.guesses or {}
		game_state.current_row = saved.current_row or (#game_state.guesses + 1)
		game_state.current_guess = saved.current_guess or ""
		alpha_status = saved.alpha_status or {}
	else
		clear_saved_state()
		initialize_game_target()
		alpha_status = {}
	end

	setup_highlight_groups()

	game_state.buf = vim.api.nvim_create_buf(false, true)
	if not game_state.buf then
		vim.api.nvim_echo({ { "Error: Could not create buffer", "ErrorMsg" } }, false, {})
		return
	end

	local buffer_options = {
		bufhidden = "wipe",
		buftype = "nofile",
		swapfile = false,
		filetype = "wordy",
	}

	for option, value in pairs(buffer_options) do
		vim.api.nvim_set_option_value(option, value, { buf = game_state.buf })
	end

	local win_width, win_height = calculate_window_size()
	local window_config = {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = math.floor((vim.o.columns - win_width) / 2),
		row = math.floor((vim.o.lines - win_height) / 2),
		style = "minimal",
		border = "rounded",
		zindex = 50,
	}

	game_state.win = vim.api.nvim_open_win(game_state.buf, true, window_config)
	if not game_state.win then
		vim.api.nvim_echo({ { "Error: Could not create window", "ErrorMsg" } }, false, {})
		return
	end

	local window_options = {
		cursorline = false,
		number = false,
		relativenumber = false,
		wrap = false,
		spell = false,
		list = false,
		signcolumn = "no",
		foldcolumn = "0",
		colorcolumn = "",
		winfixwidth = true,
		winfixheight = true,
		sidescrolloff = 0,
		scrolloff = 0,
	}

	for option, value in pairs(window_options) do
		vim.api.nvim_set_option_value(option, value, { win = game_state.win })
	end

	setup_key_mappings()
	setup_autocmds()
	update_display()
end

---@param opts table|nil
function M.setup(opts)
	opts = opts or {}

	local merged = cfg.merge(opts)
	colors = merged.colors
end

initialize_game_target()

return M
