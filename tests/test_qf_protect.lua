-- Run: nvim --headless -u NONE -l test_qf.lua
-- Test: rapid sequential wipes (simulating fzf-lua closing preview + buffer)

package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"
local protect = require("loccy.protect")
protect.setup()

vim.fn.mkdir("/tmp/loccy_test", "p")
vim.fn.writefile({"line1"}, "/tmp/loccy_test/a.txt")
vim.fn.writefile({"line2"}, "/tmp/loccy_test/b.txt")

vim.cmd("edit /tmp/loccy_test/a.txt")
vim.cmd("edit /tmp/loccy_test/b.txt")

vim.fn.setqflist({}, "r")
vim.fn.setqflist({
  { filename = "/tmp/loccy_test/a.txt", lnum = 1, text = "AI - a", bufnr = 0 },
  { filename = "/tmp/loccy_test/b.txt", lnum = 1, text = "AI - b", bufnr = 0 },
}, "a")

print("before:")
for i, item in ipairs(vim.fn.getqflist()) do
  print("  [" .. i .. "] bufnr=" .. item.bufnr .. " name=" .. vim.api.nvim_buf_get_name(item.bufnr))
end

-- Wipe BOTH buffers rapidly (no vim.wait between them)
local bnr_a = vim.fn.bufnr("/tmp/loccy_test/a.txt")
local bnr_b = vim.fn.bufnr("/tmp/loccy_test/b.txt")
vim.cmd("bwipeout! " .. bnr_a)
vim.cmd("bwipeout! " .. bnr_b)

-- Now let scheduled callbacks run
vim.wait(200, function() return false end)

print("\nafter rapid double wipe:")
local after = vim.fn.getqflist()
print("qflist count=" .. #after)
for i, item in ipairs(after) do
  local valid = item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr)
  local name = valid and vim.api.nvim_buf_get_name(item.bufnr) or "LOST(bufnr=" .. item.bufnr .. ")"
  print("  [" .. i .. "] bufnr=" .. item.bufnr .. " name=" .. name)
end

print("\nprotect.qflist_filenames:")
for i, f in ipairs(protect.qflist_filenames) do
  print("  [" .. i .. "] " .. (f == "" and "EMPTY" or f))
end

vim.fn.delete("/tmp/loccy_test", "rf")
print("\nDone.")
vim.cmd("qa!")
