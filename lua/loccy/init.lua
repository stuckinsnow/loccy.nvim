local protect = require("loccy.protect")
local persist = require("loccy.persist")
local commands = require("loccy.commands")
local fzf = require("loccy.fzf")

local M = {}

function M.setup(opts)
	opts = opts or {}
	protect.setup()
	commands.setup()
	if opts.persist ~= false then
		persist.setup(opts)
	end
end

M.track_loclist = protect.track_loclist
M.remove_loclist = protect.remove_loclist
M.track_qf = protect.track_qf
M.remove_qf = protect.remove_qf
M.fzf_delete_qf = fzf.delete_qf
M.fzf_delete_loclist = fzf.delete_loclist

return M
