return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local nvimtree = require("nvim-tree")
		local icons = require("icons")

		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1

		-- subtle indent color (optional)
		vim.cmd([[ highlight NvimTreeIndentMarker guifg=#3FC5FF ]])

		nvimtree.setup({
			filters = { dotfiles = false },
			update_focused_file = { enable = true, update_cwd = true },

			renderer = {
				root_folder_modifier = ":t",
				icons = {
					glyphs = icons.nvimtree.glyphs,
				},
			},

			diagnostics = {
				enable = true,
				show_on_dirs = false,
				icons = icons.nvimtree.diagnostics,
			},

			view = {
				width = 30,
				side = "left",
			},

			sync_root_with_cwd = false,
			respect_buf_cwd = false,
		})

		-- keymaps
		vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
	end,
}
