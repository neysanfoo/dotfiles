return {
	"akinsho/toggleterm.nvim",
	version = "*",
	config = function()
		local toggleterm = require("toggleterm")
		local icons = require("icons").ui

		vim.api.nvim_set_hl(0, "TerminalTitle", { fg = "#89b4fa", bg = "#1e1e2e", bold = true })

		local function responsive_term_width()
			local cols = vim.o.columns
			local w = (cols >= 160 and 100) or (cols >= 90 and 80) or 70
			return math.min(w, cols - 4)
		end

		toggleterm.setup({
			open_mapping = [[<C-\>]],
			hide_numbers = true,
			start_in_insert = true,
			insert_mappings = true,
			direction = "float",
			float_opts = {
				border = "curved",
				title_pos = "left",
				width = responsive_term_width,
				height = function()
					return math.floor(vim.o.lines * 0.5)
				end,
			},
			on_open = function(term)
				local name = term.display_name or ("Term " .. term.id)
				local title = string.format(" %s %s %s ", icons.terminal, name, icons.dot)
				vim.api.nvim_win_set_config(term.window, { title = title, title_pos = "left" })
			end,
		})

		function _G.set_terminal_keymaps()
			local opts = { noremap = true, silent = true }
			vim.api.nvim_buf_set_keymap(0, "t", "<Esc>", [[<C-\><C-n>]], opts)
			vim.keymap.set("n", "<Esc><Esc>", function()
				local term_id = vim.b.toggle_number
				local tt = require("toggleterm.terminal")
				local term = term_id and tt.get(term_id) or nil
				if term and term:is_open() then term:close() end
			end, vim.tbl_extend("force", opts, { buffer = 0 }))
		end

		vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

		local opts = { noremap = true, silent = true }
		vim.keymap.set("n", "<leader>1", "<cmd>1ToggleTerm<cr>", opts)
		vim.keymap.set("n", "<leader>2", "<cmd>2ToggleTerm<cr>", opts)
		vim.keymap.set("n", "<leader>3", "<cmd>3ToggleTerm<cr>", opts)

		vim.keymap.set("n", "<leader>ts", "<cmd>TermSelect<cr>", { desc = "Select Terminal" })
		vim.keymap.set("n", "<leader>tr", "<cmd>ToggleTermSetName<cr>", { desc = "Rename Terminal" })

		function _RENAME_AND_REFRESH_TERMINAL()
			vim.ui.input({ prompt = "Terminal name: " }, function(name)
				if name then
					local term_id = vim.b.toggle_number
					vim.cmd("ToggleTermSetName " .. name)
					vim.defer_fn(function()
						local terms = require("toggleterm.terminal").get_all()
						local term = terms[term_id]
						if term and term:is_open() then
							local display_name = term.display_name or ("Term " .. term.id)
							local title = string.format(" %s %s %s ", icons.terminal, display_name, icons.dot)
							vim.api.nvim_win_set_config(term.window, { title = title, title_pos = "left" })
						end
					end, 100)
				end
			end)
		end

		vim.keymap.set("n", "<leader>tr", "<cmd>lua _RENAME_AND_REFRESH_TERMINAL()<CR>", { desc = "Rename Terminal" })
	end,
}
