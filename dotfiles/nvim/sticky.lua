-- Sticky note (Mod+n): bare text, autosave. Sourced with `nvim -S` after LazyVim init.
-- lualine (VeryLazy) restores laststatus from this global, so set both.
vim.g.lualine_laststatus = 0
vim.o.laststatus = 0
vim.o.cmdheight = 0
vim.o.ruler = false
vim.o.showmode = false
local function bare()
  vim.wo.number, vim.wo.relativenumber = false, false
  vim.wo.signcolumn, vim.wo.foldcolumn, vim.wo.statuscolumn = "no", "0", ""
  vim.wo.wrap = false
end
bare()
vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", once = true, callback = function()
  vim.schedule(function()
    vim.o.laststatus = 0
    bare()
  end)
end })
-- popup toggle kills nvim, so write on every change
vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, { buffer = 0, command = "silent write" })
