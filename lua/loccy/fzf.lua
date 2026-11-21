local protect = require("loccy.protect")

local M = {}

local function strip_ansi(s)
	return (s or ""):gsub("\27%[[%d;]+m", "")
end

local function parse_selection(sel)
	local clean = strip_ansi(sel)
	local bufnr = tonumber(clean:match("^%[(%d+)%]"))
	local lnum, text = clean:match(":(%d+):%d+:%s*(.*)$")
	if not lnum then
		lnum, text = clean:match(":(%d+):%s*(.*)$")
	end
	return bufnr, tonumber(lnum), text
end

local function remove_selected(items, selected, on_remove)
	if not items or #items == 0 or not selected or #selected == 0 then
		return false
	end

	local to_remove = {}
	for _, sel in ipairs(selected) do
		local bufnr, lnum, text = parse_selection(sel)
		for i, item in ipairs(items) do
			if not to_remove[i] then
				local item_text = strip_ansi((item.text or ""):gsub("\r?\n", " "))
				if (not bufnr or item.bufnr == bufnr)
					and (not lnum or item.lnum == lnum)
					and (not text or item_text == text)
				then
					to_remove[i] = true
					break
				end
			end
		end
	end

	local indices = {}
	for i in pairs(to_remove) do
		table.insert(indices, i)
	end
	if #indices == 0 then
		return false
	end

	table.sort(indices, function(a, b) return a > b end)
	for _, i in ipairs(indices) do
		table.remove(items, i)
		if on_remove then on_remove(i) end
	end
	return true
end

--- Delete selected item(s) from the quickfix list (for fzf-lua action with `reload = true`).
--- @param selected string[]
function M.delete_qf(selected)
	local items = vim.fn.getqflist()
	if remove_selected(items, selected, protect.remove_qf) then
		vim.fn.setqflist({}, "r", { items = items })
	end
end

--- Delete selected item(s) from the location list (for fzf-lua action with `reload = true`).
--- @param selected string[]
function M.delete_loclist(selected)
	local ok, fzf_utils = pcall(require, "fzf-lua.utils")
	local winid = (ok and fzf_utils.CTX and fzf_utils.CTX().winid) or vim.fn.win_getid(vim.fn.winnr("#"))
	if not winid or winid == 0 or not vim.api.nvim_win_is_valid(winid) then
		winid = 0
	end

	local items = vim.fn.getloclist(winid)
	if remove_selected(items, selected, protect.remove_loclist) then
		vim.fn.setloclist(winid, {}, "r", { items = items })
	end
end

return M
