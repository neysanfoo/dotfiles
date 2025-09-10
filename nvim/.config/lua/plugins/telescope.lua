return {
	dir = "~/src/neysan.telescope.nvim",
	name = "Telescope",
	dev = true,
	branch = "master",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-tree/nvim-web-devicons",
	},
	keys = {
		{ "<leader>ff", desc = "Find files" },
		{ "<leader>fh", desc = "Find hidden files" },
		{ "<leader>fb", desc = "Find buffers" },
		{ "<leader>fr", desc = "Recent files" },
		{ "<leader>fd", desc = "Diagnostics" },
		{ "<leader>ft", desc = "Live grep" },
		{ "<leader>fc", desc = "Find word under cursor" },
		{ "<leader>fp", desc = "Find projects" },
		{ "<leader>b",  desc = "Buffer picker" },
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		local config = {
			defaults = {
				prompt_prefix = "",
				selection_caret = "",
				entry_prefix = "",
				initial_mode = "insert",
				selection_strategy = "reset",
				file_ignore_patterns = { "%.git", "node_modules", "vendor" },
				winblend = 0,
				color_devicons = true,
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous,
						["<C-j>"] = actions.move_selection_next,
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
					},
				},
			},
			pickers = {
				find_files = {
					theme = "dropdown",
					previewer = false,
				},
				live_grep = {
					theme = "dropdown",
				},
				grep_string = {
					theme = "dropdown",
				},
				buffers = {
					initial_mode = "insert",
					mappings = {
						i = {
							["<C-d>"] = actions.delete_buffer,
						},
						n = {
							["dd"] = actions.delete_buffer,
						},
					},
				},
				git_files = {
					hidden = true,
					show_untracked = true,
				},
			},
		}

		telescope.setup(config)

		local get_cwd_display = function()
			local cwd = vim.fn.getcwd()
			local home = vim.fn.expand("~")
			if cwd:find(home, 1, true) == 1 then
				return "~" .. cwd:sub(#home + 1)
			end
			return cwd
		end

		local builtin = require("telescope.builtin")
		local keymap = vim.keymap.set

		-- File finding
		keymap("n", "<leader>ff", function()
			builtin.find_files({
				follow = true,
				no_ignore = false,
				prompt_title = "Find Files in " .. get_cwd_display(),
			})
		end, { desc = "Find files" })

		keymap("n", "<leader>fh", function()
			builtin.find_files({
				follow = true,
				no_ignore = true,
				hidden = true,
				prompt_title = "Find Hidden Files in " .. get_cwd_display(),
			})
		end, { desc = "Find hidden files" })

		keymap("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
		keymap("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
		keymap("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics" })

		-- Search operations
		keymap("n", "<leader>ft", function()
			builtin.live_grep({
				additional_args = { "-u" },
				prompt_title = "Live Grep in " .. get_cwd_display(),
			})
		end, { desc = "Live grep" })

		keymap("n", "<leader>fc", function()
			builtin.grep_string({
				prompt_title = "Grep String in " .. get_cwd_display(),
			})
		end, { desc = "Find word under cursor" })

		-- Special pickers
		keymap("n", "<leader>b", function()
			builtin.buffers(require("telescope.themes").get_dropdown({ previewer = false }))
		end, { desc = "Buffer picker" })

		keymap("n", "<leader>fp", "<cmd>Telescope projects theme=dropdown<cr>", { desc = "Find projects" })
	end,
}
