return {
	"github/copilot.vim",
	lazy = true,
	cmd = "Copilot",
	config = function()
		-- Disable default Tab mapping
		vim.g.copilot_no_tab_map = true

		-- Simple styling
		vim.api.nvim_set_hl(0, "CopilotSuggestion", {
			fg = "#6272a4",
			italic = true
		})

		vim.keymap.set('i', '<C-l>', 'copilot#Accept("\\<CR>")', {
			expr = true,
			replace_keycodes = false
		})
		vim.g.copilot_no_tab_map = true
	end,
}
