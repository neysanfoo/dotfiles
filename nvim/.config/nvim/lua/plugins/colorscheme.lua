return {
	"ellisonleao/gruvbox.nvim",
	priority = 1000,
	config = function()
		require("gruvbox").setup({
			terminal_colors = true,
			undercurl = true,
			underline = true,
			bold = true,
			italic = {
				strings = true,
				comments = true,
				operators = false,
				folds = true,
			},
			strikethrough = true,
			invert_selection = false,
			invert_signs = false,
			invert_tabline = false,
			invert_intend_guides = false,
			inverse = true,
			contrast = "", -- "hard", "soft" or ""
			palette_overrides = {},
			overrides = {
				SignColumn  = { bg = "#282828" },
				NormalFloat = { bg = "#282828" },             -- match main background
				FloatBorder = { bg = "#282828", fg = "#ebdbb2" }, -- border stands out
				Pmenu       = { bg = "#282828" },             -- completion menu
				PmenuSel    = { bg = "#3c3836" },             -- selected item slightly lighter
			},
			dim_inactive = false,
			transparent_mode = false,
		})
		vim.cmd("colorscheme gruvbox")
	end,
}
