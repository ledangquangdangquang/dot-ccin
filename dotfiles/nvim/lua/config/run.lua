-- Buffer-local F5: save, then run `cmd(file)` (a shell string) in a bottom terminal split that stays open
return function(cmd)
  vim.keymap.set("n", "<F5>", function()
    vim.cmd("write")
    Snacks.terminal(cmd(vim.fn.shellescape(vim.fn.expand("%:p"))), { auto_close = false, win = { position = "bottom" } })
  end, { buffer = true, desc = "Run file" })
end
