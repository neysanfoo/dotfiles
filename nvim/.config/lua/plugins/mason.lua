return {
	{
		"mason-org/mason.nvim",
		config = function()
			require("mason").setup({
				ui = {
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = {
			"williamboman/mason.nvim",
			"neovim/nvim-lspconfig",
		},
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"basedpyright",
					"ruff",
					"gopls",
					"rust_analyzer",
					"clangd",
					"ts_ls",
					"html",
					"cssls",
					"jsonls",
					"bashls",
					"dockerls",
					"cmake",
					"tailwindcss",
					"vimls",
					"jdtls",
				},
				automatic_enable = true,
			})
		end,
	},
}
