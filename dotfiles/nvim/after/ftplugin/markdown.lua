-- F5: save and open a live-reloading preview in the browser (live-preview.nvim)
vim.keymap.set("n", "<F5>", "<cmd>write | LivePreview start<CR>", { buffer = true, desc = "Live preview Markdown" })
