-- cd into the file's folder so scripts can use relative paths and local functions
require("config.run")(function(f)
  return "cd " .. vim.fn.shellescape(vim.fn.expand("%:p:h")) .. " && matlab -batch " .. vim.fn.shellescape("run(" .. vim.fn.string(vim.fn.expand("%:p")) .. ")")
end)
