return function()
  local null_ls = require("null-ls")

  null_ls.setup({
    sources = {
      null_ls.builtins.formatting.prettier.with({
        filetypes = {
          "javascript",
          "javascriptreact",
          "typescript",
          "typescriptreact",
          "json",
          "html",
          "css",
          "markdown",
          "mdx",
          "yaml",
        },
        extra_args = { "--no-use-tabs", "--tab-width", "2" },
      }),
    },
  })
end
