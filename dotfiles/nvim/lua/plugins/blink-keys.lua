-- No menu open: C-j/C-k walk command history (plain fallback would make C-j run the command like Enter)
local function key(k)
  return function()
    vim.api.nvim_feedkeys(vim.keycode(k), "n", false)
    return true
  end
end

return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      ["<C-j>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback" },
    },
    cmdline = {
      keymap = {
        ["<C-j>"] = { "select_next", key("<Down>") },
        ["<C-k>"] = { "select_prev", key("<Up>") },
      },
    },
  },
}
