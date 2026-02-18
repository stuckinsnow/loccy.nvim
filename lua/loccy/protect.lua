local M = {}

-- Source of truth for filenames (survives buffer wipes)
M.loclist_filenames = {}
M.qflist_filenames = {}

-- ---------------------------------------------------------------------------
-- Snapshot: capture filenames while bufnrs are still valid
-- ---------------------------------------------------------------------------

local function resolve_filename(item)
	if item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
		local name = vim.api.nvim_buf_get_name(item.bufnr)
		if name ~= "" then return name end
	end
	return ""
end

local function snapshot_qf()
	local ok, qf = pcall(vim.fn.getqflist)
	if not ok or not qf or #qf == 0 then return end
	M.qflist_filenames = {}
	for _, item in ipairs(qf) do
		table.insert(M.qflist_filenames, resolve_filename(item))
	end
end

local function snapshot_loclist()
	for _, winnr in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(winnr) then
			local ok, items = pcall(vim.fn.getloclist, winnr)
			if ok and items and #items > 0 then
				if #M.loclist_filenames == #items then return end
				M.loclist_filenames = {}
				for _, item in ipairs(items) do
					table.insert(M.loclist_filenames, resolve_filename(item))
				end
				return
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Rebuild: restore correct filenames after buffer wipes
-- ---------------------------------------------------------------------------

local function rebuild_list(filenames, getter, setter)
	if #filenames == 0 then return end
	local ok, result = getter()
	if not ok or not result or #result ~= #filenames then return end
	local rebuilt = {}
	for i, item in ipairs(result) do
		table.insert(rebuilt, {
			filename = filenames[i],
			lnum = item.lnum, col = item.col,
			text = item.text, type = item.type,
		})
	end
	setter(rebuilt)
end

local function rebuild_loclist()
	if #M.loclist_filenames == 0 then return end
	for _, winnr in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(winnr) then
			rebuild_list(
				M.loclist_filenames,
				function() return pcall(vim.fn.getloclist, winnr) end,
				function(items) vim.fn.setloclist(winnr, {}, "r", { items = items }) end
			)
			return
		end
	end
end

local function rebuild_qf()
	rebuild_list(
		M.qflist_filenames,
		function() return pcall(vim.fn.getqflist) end,
		function(items) vim.fn.setqflist({}, "r", { items = items }) end
	)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function M.track_loclist(index, filename)
	table.insert(M.loclist_filenames, index, filename)
end

function M.remove_loclist(index)
	table.remove(M.loclist_filenames, index)
end

function M.track_qf(index, filename)
	table.insert(M.qflist_filenames, index, filename)
end

function M.remove_qf(index)
	table.remove(M.qflist_filenames, index)
end

-- ---------------------------------------------------------------------------
-- Setup: only 2 autocmds, both fire rarely
-- ---------------------------------------------------------------------------

function M.setup()
	-- BufUnload fires right before a buffer is wiped — snapshot while bufnrs are valid
	vim.api.nvim_create_autocmd("BufUnload", {
		callback = function()
			snapshot_qf()
			snapshot_loclist()
		end,
	})

	-- BufDelete fires after wipe — rebuild with correct filenames
	vim.api.nvim_create_autocmd("BufDelete", {
		callback = function()
			vim.schedule(function()
				rebuild_loclist()
				rebuild_qf()
			end)
		end,
	})
end

return M
