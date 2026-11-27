return {
  "sontungexpt/vietnamese.nvim",
  dependencies = {
    "sontungexpt/bim.nvim",
  },
  event = "InsertEnter",
  keys = {
    { "<M-v>", "<cmd>VietnameseToggle<cr>", mode = { "n", "i" }, desc = "Toggle Vietnamese input" },
  },
  opts = {},
}
