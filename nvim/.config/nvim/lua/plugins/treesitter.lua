return function()
  require("core.treesitter_compat").setup()
  require("nvim-ts-autotag").setup({})
  -- import nvim-treesitter plugin
  local treesitter = require("nvim-treesitter.configs")

  -- configure treesitter
  treesitter.setup({
    -- enable syntax highlighting
    highlight = {
      enable = true,
    },
    -- enable indentation
    indent = { enable = true, disable = { "rust" } },
    -- ensure these language parsers are installed
    ensure_installed = {
      "json",
      "javascript",
      "typescript",
      "tsx",
      "yaml",
      "html",
      "css",
      "prisma",
      "markdown",
      "markdown_inline",
      "svelte",
      "graphql",
      "bash",
      "lua",
      "vim",
      "dockerfile",
      "gitignore",
      "rust",
      "python",
      "toml",
      "cpp",
    },
    -- auto install above language parsers
    auto_install = true,
    modules = {},
    sync_install = false,
    ignore_install = {},
  })
end
