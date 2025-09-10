return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "classic",
		plugins = {
			marks = true,
			registers = true,
			spelling = {
				enabled = true,
				suggestions = 20,
			},
			presets = {
				operators = false,
				motions = false,
				text_objects = false,
				windows = false,
				nav = false,
				z = false,
				g = false,
			},
		},
		win = {
			border = "rounded",
			no_overlap = false,
			padding = { 1, 2 },
			title = false,
			title_pos = "center",
			zindex = 1000,
		},
		show_help = false,
		show_keys = false,
		disable = {
			buftypes = {},
			filetypes = { "TelescopePrompt" },
		},
		icons = {
			mappings = false,
		}
	},
	config = function(_, opts)
		local wk = require("which-key")
		wk.setup(opts)

		wk.add({
			-- Main groups (only register groups, not individual keymaps from other plugins)
			{ "<leader>f", group = "Find" },
			{ "<leader>g", group = "Git" },
			{ "<leader>l", group = "LSP" },
			{ "<leader>n", group = "Numbers" },
			{ "<leader>s", group = "Search" },
			{ "<leader>r", group = "Rename" },
			{ "<leader>x", group = "Diagnostics" },
			{ "<leader>t", group = "Terminal" },
		})
	end,
}
