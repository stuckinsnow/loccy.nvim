local M = {}

local protect -- set in setup()
local loaded_repos = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function get_repo_info()
	local cwd = vim.fn.getcwd()
	local git_dir = vim.fn.finddir(".git", cwd .. ";")
	if git_dir == "" then return nil, nil end
	local root = vim.fn.fnamemodify(git_dir, ":h")
	local name = vim.fn.fnamemodify(root, ":t")
	return root, name
end

local function get_file_path(repo_root, repo_name, share_dir)
	local safe = repo_name:gsub("[^%w%-_.]", "_")
	local hash = string.sub(vim.fn.sha256(repo_root), 1, 8)
	return share_dir .. "/" .. safe .. "_" .. hash .. ".json"
end

-- ---------------------------------------------------------------------------
-- Load
-- ---------------------------------------------------------------------------

local function load_loclist(share_dir)
	local repo_root, repo_name = get_repo_info()
	if not repo_root or loaded_repos[repo_root] then return end

	local path = get_file_path(repo_root, repo_name, share_dir)
	local f = io.open(path, "r")
	if not f then return end

	local content = f:read("*a")
	f:close()

	local ok, saved = pcall(vim.fn.json_decode, content)
	if not ok or not saved or #saved == 0 then return end

	local items = {}
	protect.loclist_filenames = {}

	local max_index = 0
	for i, item in ipairs(saved) do
		items[i] = {
			filename = item.filename or "",
			lnum = item.lnum or 1,
			col = item.col or 1,
			text = item.text or "",
			type = item.type or "",
		}
		protect.loclist_filenames[i] = items[i].filename

		-- Extract index from text (format: "01 - message timestamp")
		local clean = (item.text or ""):gsub("\27%[[%d;]+m", "")
		local idx = tonumber(clean:match("^(%d+)%s*%-"))
		if idx and idx > max_index then max_index = idx end
	end

	_G.loclist_index = max_index

	local winnr = vim.api.nvim_get_current_win()
	if winnr and vim.api.nvim_win_is_valid(winnr) then
		local success = pcall(vim.fn.setloclist, winnr, {}, "r", {
			items = items,
			title = "Restored Location List",
		})
		if success then loaded_repos[repo_root] = true end
	end
end

-- ---------------------------------------------------------------------------
-- Save (only on VimLeave and loclist window close — minimal disk writes)
-- ---------------------------------------------------------------------------

local function save_loclist(share_dir)
	if #protect.loclist_filenames == 0 then return end

	local repo_root, repo_name = get_repo_info()
	if not repo_root then return end

	local path = get_file_path(repo_root, repo_name, share_dir)

	-- Find loclist items from any window
	local items = {}
	for _, winnr in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(winnr) then
			local ok, result = pcall(vim.fn.getloclist, winnr)
			if ok and result and #result > 0 then
				for idx, item in ipairs(result) do
					table.insert(items, {
						filename = protect.loclist_filenames[idx] or "",
						lnum = item.lnum or 1,
						col = item.col or 1,
						text = item.text or "",
						type = item.type or "",
					})
				end
				break
			end
		end
	end

	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")

	if #items > 0 then
		local f = io.open(path, "w")
		if f then
			f:write(vim.fn.json_encode(items))
			f:close()
		end
	elseif vim.fn.filereadable(path) == 1 then
		os.remove(path)
	end
end

-- ---------------------------------------------------------------------------
-- Clear command
-- ---------------------------------------------------------------------------

local function clear_loclist(share_dir)
	vim.fn.setloclist(0, {}, "r")
	protect.loclist_filenames = {}
	_G.loclist_index = 0

	local repo_root, repo_name = get_repo_info()
	if not repo_root then return end

	local path = get_file_path(repo_root, repo_name, share_dir)
	if vim.fn.filereadable(path) == 1 then
		os.remove(path)
	end
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

function M.setup(opts)
	protect = require("loccy.protect")
	local share_dir = opts.save_dir or (vim.fn.stdpath("data") .. "/loclist")

	vim.api.nvim_create_autocmd("BufWinEnter", {
		once = true,
		callback = function() vim.defer_fn(function() load_loclist(share_dir) end, 10) end,
	})

	vim.api.nvim_create_autocmd("DirChanged", {
		callback = function() vim.defer_fn(function() load_loclist(share_dir) end, 10) end,
	})

	-- Save only on exit and when loclist window closes
	vim.api.nvim_create_autocmd("VimLeave", {
		callback = function() save_loclist(share_dir) end,
	})

	vim.api.nvim_create_autocmd("BufWinLeave", {
		callback = function()
			if vim.bo.buftype == "quickfix" then
				vim.defer_fn(function() save_loclist(share_dir) end, 100)
			end
		end,
	})

	vim.api.nvim_create_user_command("ClearLoclist", function()
		clear_loclist(share_dir)
	end, { desc = "Clear location list and delete persistence file" })
end

return M
