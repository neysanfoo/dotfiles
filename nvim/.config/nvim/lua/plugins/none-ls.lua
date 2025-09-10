return {
	"nvimtools/none-ls.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
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
						"yaml",
					},
					extra_args = { "--no-use-tabs", "--tab-width", "2" },
				}),
			},
		})
	end,
}
