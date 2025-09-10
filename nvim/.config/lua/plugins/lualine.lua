return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local lualine_theme = require('themes.lualine')

		require('lualine').setup {
			options = {
				theme = lualine_theme,
				component_separators = { left = '│', right = '│' },
				section_separators = { left = '', right = '' },
				globalstatus = true,
			},
			sections = {
				lualine_a = {
					{
						'mode',
						fmt = function(str) return str:sub(1, 1) end,
					},
				},
				lualine_b = {
					{
						'branch',
					},
					{
						"diagnostics",
						sources = { "nvim_diagnostic" },
						sections = { "error", "warn" },
						always_visible = true,
					},
				},
				lualine_c = {
					{
						'filename',
						path = 2,
						file_status = true,
					},
				},

				lualine_x = {},

				lualine_y = {
					{
						"diff"
					}
				},
			},
		}
	end,
}
