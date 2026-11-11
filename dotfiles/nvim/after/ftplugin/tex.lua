-- F5: save and toggle VimTeX continuous compile (zathura viewer)
vim.keymap.set("n", "<F5>", "<cmd>write | VimtexCompile<CR>", { buffer = true, desc = "Vimtex Compile" })
