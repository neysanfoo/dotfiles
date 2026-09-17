return function()
  -- Mason manages executables only. Server configuration/activation is native.
  require("mason").setup({
    ui = { icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" } },
  })
  vim.api.nvim_create_user_command("LspInstallAll", function()
    vim.cmd(
    "MasonInstall lua-language-server basedpyright ruff gopls rust-analyzer clangd typescript-language-server html-lsp css-lsp json-lsp bash-language-server dockerfile-language-server cmake-language-server tailwindcss-language-server vim-language-server jdtls mdx-analyzer prettier")
  end, { desc = "Install this config's servers and Prettier with Mason" })
end
