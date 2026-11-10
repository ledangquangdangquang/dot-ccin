require("config.run")(function(f)
  local out = vim.fn.tempname()
  return "g++ " .. f .. " -o " .. out .. " && " .. out
end)
