local giticons = require('icons').git


return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local gitsigns = require("gitsigns")
		gitsigns.setup({
			signs = {
				add = { text = giticons.add },
				change = { text = giticons.change },
				delete = { text = giticons.delete },
				topdelete = { text = giticons.topdelete },
				changedelete = { text = giticons.changedelete },
				untracked = { text = giticons.untracked },
			},
			attach_to_untracked = true,
			on_attach = function(bufnr)
				local gs = gitsigns
				local function map(mode, l, r, opts)
					opts = opts or {}
					opts.buffer = bufnr
					opts.desc = opts.desc or ""
					vim.keymap.set(mode, l, r, opts)
				end
				-- Navigation
				map("n", "]c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "]c", bang = true })
					else
						gs.next_hunk()
					end
				end, { desc = "Next hunk" })
				map("n", "[c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "[c", bang = true })
					else
						gs.prev_hunk()
					end
				end, { desc = "Previous hunk" })
				map("n", "<leader>gj", gs.next_hunk, { desc = "Next hunk" })
				map("n", "<leader>gk", gs.prev_hunk, { desc = "Previous hunk" })
				map("n", "<leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
				map("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
				map("n", "<leader>gS", gs.stage_buffer, { desc = "Stage buffer" })
				map("n", "<leader>gR", gs.reset_buffer, { desc = "Reset buffer" })
				map("n", "<leader>gu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
				map("n", "<leader>gp", gs.preview_hunk, { desc = "Preview hunk" })
				map("n", "<leader>gl", function() gs.blame_line({ full = true }) end, { desc = "Blame line" })
				map("n", "<leader>gb", gs.toggle_current_line_blame, { desc = "Toggle line blame" })
				map("n", "<leader>gd", gs.diffthis, { desc = "Diff this" })
				map("n", "<leader>gD", function() gs.diffthis("~") end, { desc = "Diff this ~" })
				map("n", "<leader>gtd", gs.toggle_deleted, { desc = "Toggle deleted" })
				-- Visual mode
				map("v", "<leader>gs", function()
					gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "Stage hunk" })
				map("v", "<leader>gr", function()
					gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "Reset hunk" })
				-- Text object
				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select hunk" })
				-- Telescope integration
				map("n", "<leader>go", "<cmd>Telescope git_status<cr>", { desc = "Open changed file" })
				map("n", "<leader>gB", "<cmd>Telescope git_branches<cr>", { desc = "Checkout branch" })
				map("n", "<leader>gc", "<cmd>Telescope git_commits<cr>", { desc = "Checkout commit" })
				map("n", "<leader>gC", "<cmd>Telescope git_bcommits<cr>", { desc = "Buffer commits" })
			end,
		})
		-- Highlight customization
		local highlights = {
			GitSignsAdd = { guibg = "none" },
			GitSignsChange = { guibg = "none" },
			GitSignsDelete = { guibg = "none" },
			GitSignsChangeDelete = { guibg = "none" },
			GitSignsTopDelete = { guibg = "none" },
		}
		for group, opts in pairs(highlights) do
			vim.cmd(string.format("highlight %s guibg=%s", group, opts.guibg))
		end
	end,
}
