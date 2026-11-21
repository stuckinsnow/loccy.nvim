# loccy.nvim

Neovim plugin for managing **quickfix** and **location** lists:

- **Per-repo persistence** — automatically saves and restores your quickfix list (and optionally location list) per git repository across Neovim restarts.
- **Buffer-wipe protection** — preserves file paths in quickfix/location lists when buffers are unloaded or wiped (e.g. closing `fzf-lua` previews or `:bwipeout`).
- **Quick bookmarks/notes** — add numbered, timestamped, ANSI-colored entries (`01 - message 12:34:56`, green index / red message / purple timestamp) from the current line or a custom message via `fzf-lua`.
- **`fzf-lua` delete actions** — delete single or multi-selected entries in-place with `ctrl-x` while keeping filename tracking in sync.

## Installation (lazy.nvim)

```lua
{
  "stuckinsnow/loccy.nvim",
  lazy = false,
  dependencies = { "ibhagwan/fzf-lua" }, -- optional, for :AddToQuickfix / :AddToLoclist
  config = function()
    require("loccy").setup({
      persist_qf = true,
      persist_loclist = false,
    })
  end,
}
```

## Configuration

Defaults:

```lua
require("loccy").setup({
  persist = true,                              -- master toggle for persistence
  persist_qf = true,                           -- persist quickfix list per git repo
  persist_loclist = false,                     -- persist location list per git repo
  qf_save_dir = vim.fn.stdpath("data") .. "/qflist",
  save_dir = vim.fn.stdpath("data") .. "/loclist",
})
```

Lists are saved on `VimLeave` and when closing a quickfix/loclist window (`BufWinLeave`), and restored on startup (`BufWinEnter`) or `:cd` (`DirChanged`).

## Commands

| Command | Description |
| --- | --- |
| `:AddToQuickfix` | Add current line or custom message (numbered, timestamped, ANSI-colored for `fzf-lua`) to the quickfix list |
| `:AddToLoclist` | Add current line or custom message (numbered, timestamped, ANSI-colored for `fzf-lua`) to the location list |
| `:ClearQuickfix` | Clear quickfix list and delete its persistence file (when `persist_qf = true`) |
| `:ClearLoclist` | Clear location list and delete its persistence file (when `persist_loclist = true`) |
| `:LOpenClean` | Open the native location list window with ANSI color codes stripped |

In the native location list window, `<C-x>` deletes the entry under the cursor.

## Recommended Keymaps

```lua
vim.keymap.set("n", "<leader>ll", ":AddToQuickfix<CR>", { silent = true, desc = "Add to Quickfix List" })
vim.keymap.set("n", "<leader>lL", ":AddToLoclist<CR>", { silent = true, desc = "Add to Location List" })
vim.keymap.set("n", "<leader>sl", "<cmd>FzfLua quickfix<CR>", { desc = "Quickfix List" })
vim.keymap.set("n", "<leader>sL", "<cmd>FzfLua loclist<CR>", { desc = "Location List" })
```

## `fzf-lua` Integration

Use `fzf_delete_qf` and `fzf_delete_loclist` with `reload = true` to delete items directly from `FzfLua quickfix` / `FzfLua loclist` (supports multi-select with `<Tab>`):

```lua
require("fzf-lua").setup({
  quickfix = {
    actions = {
      ["ctrl-x"] = {
        reload = true,
        fn = function(selected)
          require("loccy").fzf_delete_qf(selected)
        end,
      },
    },
  },
  loclist = {
    actions = {
      ["ctrl-x"] = {
        reload = true,
        fn = function(selected)
          require("loccy").fzf_delete_loclist(selected)
        end,
      },
    },
  },
})
```

## Lua API

- `require("loccy").format(label, msg)` — format an entry with ANSI colors and timestamp (`<label> - <msg> HH:MM:SS`)
- `require("loccy").track_qf(index, filename)` / `remove_qf(index)` — keep quickfix filename protection in sync with manual edits
- `require("loccy").track_loclist(index, filename)` / `remove_loclist(index)` — keep location list filename protection in sync
- `require("loccy").fzf_delete_qf(selected)` — `fzf-lua` delete action for quickfix
- `require("loccy").fzf_delete_loclist(selected)` — `fzf-lua` delete action for location list
