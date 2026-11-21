local M = {}

local protect = require("loccy.protect")

local function prompt_and_add(opts)
	local fzf = require("fzf-lua")
	local current_line = vim.api.nvim_get_current_line()
	local owner_win = vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_get_current_buf()
	local full_path = vim.api.nvim_buf_get_name(bufnr)
	local cursor_lnum = vim.fn.line(".")
	local cursor_col = vim.fn.col(".")

	local choices = {
		"\27[35m1.\27[0m Copy text from current line",
		"\27[35m2.\27[0m Enter message manually",
	}

	fzf.fzf_exec(choices, {
		prompt = "Choose message source> ",
		fzf_opts = {
			["--no-multi"] = "",
			["--select-1"] = "",
			["--exit-0"] = "",
			["--header-lines"] = "0",
		},
		actions = {
			["default"] = function(selected)
				local msg = ""
				if selected[1]:find("^1%.") then
					msg = current_line:match("^%s*(.*)$")
				elseif selected[1]:find("^2%.") then
					msg = vim.fn.input("Enter message: ")
				end

				if msg == "" then
					msg = vim.fn.input("Message is empty. Please enter a string: ")
					if msg == "" then msg = "empty" end
				end

				local timestamp = os.date("%H:%M:%S")
				local index_num = opts.next_index()
				local index_str = string.format("%02d", index_num)

				local red = "\27[31m"
				local green = "\27[32m"
				local purple = "\27[35m"
				local reset = "\27[0m"

				local colored_msg = green .. index_str .. reset
					.. " - " .. red .. msg .. reset
					.. " " .. purple .. timestamp .. reset

				opts.insert(owner_win, {
					filename = full_path,
					lnum = cursor_lnum,
					col = cursor_col,
					text = colored_msg,
				}, full_path)
			end,
		},
		winopts = { height = 0.1, width = 0.2 },
	})
end

function M.setup()
	-- Add a message to the quickfix list with timestamp
	vim.api.nvim_create_user_command("AddToQuickfix", function()
		prompt_and_add({
			next_index = function()
				if not _G.qflist_index then _G.qflist_index = 0 end
				_G.qflist_index = _G.qflist_index + 1
				return _G.qflist_index
			end,
			insert = function(_, item, full_path)
				local qflist = vim.fn.getqflist()
				table.insert(qflist, 1, item)
				vim.fn.setqflist(qflist, "r")
				protect.track_qf(1, full_path)
			end,
		})
	end, { desc = "Add a message to the quickfix list" })

	-- Add a message to the location list with timestamp
	vim.api.nvim_create_user_command("AddToLoclist", function()
		prompt_and_add({
			next_index = function()
				if not _G.loclist_index then _G.loclist_index = 0 end
				_G.loclist_index = _G.loclist_index + 1
				return _G.loclist_index
			end,
			insert = function(owner_win, item, full_path)
				local loclist = vim.fn.getloclist(owner_win)
				table.insert(loclist, 1, item)
				vim.fn.setloclist(owner_win, loclist, "r")
				protect.track_loclist(1, full_path)
			end,
		})
	end, { desc = "Add a message to the location list" })

	-- Open location list with ANSI codes stripped
	vim.api.nvim_create_user_command("LOpenClean", function()
		local loclist = vim.fn.getloclist(0, { items = 0 }).items
		if not loclist or #loclist == 0 then
			print("Location list is empty")
			return
		end

		local clean_loclist = {}
		for _, item in ipairs(loclist) do
			local clean_item = vim.deepcopy(item)
			if clean_item.text then
				clean_item.text = clean_item.text:gsub("\27%[[%d;]+m", "")
			end
			table.insert(clean_loclist, clean_item)
		end

		local orig_loclist = vim.fn.getloclist(0)
		vim.fn.setloclist(0, clean_loclist, "r")

		local owner_win = vim.api.nvim_get_current_win()
		vim.cmd("lopen")

		vim.api.nvim_create_autocmd("BufWinLeave", {
			pattern = "<buffer>",
			callback = function()
				vim.schedule(function()
					pcall(function()
						if owner_win and vim.api.nvim_win_is_valid(owner_win) then
							vim.fn.setloclist(owner_win, orig_loclist, "r")
						end
					end)
				end)
			end,
			once = true,
		})
	end, { desc = "Open location list with ANSI codes stripped" })

	-- <C-x> in native location list window to delete item
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "qf",
		callback = function()
			local title = vim.fn.getloclist(0, { title = 0 }).title or ""
			if title:find("Location List") or title:find("Restored") then
				vim.keymap.set("n", "<C-x>", function()
					local curline = vim.fn.line(".")
					local loclist = vim.fn.getloclist(0)
					if #loclist == 0 then return end
					table.remove(loclist, curline)
					protect.remove_loclist(curline)
					vim.fn.setloclist(0, loclist, "r")
				end, { buffer = true, desc = "Delete loclist item" })
			end
		end,
	})
end

return M
