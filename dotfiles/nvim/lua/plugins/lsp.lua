-- Servers come from modules/packages.nix, so Mason must not install them.
return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      nil_ls = { mason = false },
      -- pull diagnostics race: nvim keeps pyright's empty result, so errors never show
      pyright = { mason = false, init_options = { disablePullDiagnostics = true } },
      clangd = { mason = false },
      html = { mason = false },
      vtsls = { mason = false },
      matlab_ls = {
        mason = false,
        settings = {
          MATLAB = {
            installPath = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.exepath("matlab")), ":h:h"),
          },
        },
      },
    },
  },
}
