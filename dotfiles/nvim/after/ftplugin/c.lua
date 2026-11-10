require("config.run")(function(f)
  local out = vim.fn.tempname()
  return "gcc " .. f .. " -o " .. out .. " && " .. out
end)
