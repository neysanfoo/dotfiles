local M = {}

--- Diagnostic severities.
M.diagnostics = {
	ERROR = "",
	WARN  = "",
	HINT  = "󰌶",
	INFO  = "",
}

-- Git Icons
M.git = {
	branch       = "",
	add          = "│",
	change       = "│",
	delete       = "󰐊",
	topdelete    = "󰐊",
	changedelete = "▎",
	untracked    = "┆",
	unstaged     = "",
	staged       = "S",
	unmerged     = "",
	renamed      = "➜",
	ignored      = "◌",
}

-- Nvim-tree
M.nvimtree = {
	glyphs = {
		default = "",
		symlink = "",
		folder = {
			arrow_open   = "",
			arrow_closed = "",
			default      = "",
			open         = "",
			empty        = "",
			empty_open   = "",
			symlink      = "",
			symlink_open = "",
		},
		git = {
			unstaged  = "",
			staged    = "S",
			unmerged  = "",
			renamed   = "➜",
			untracked = "U",
			deleted   = "",
			ignored   = "◌",
		},
	},
	diagnostics = {
		error   = " ",
		warning = " ",
		hint    = "󰌶 ",
		info    = " ",
	},
}


M.ui = {
	terminal = "󰆍",
	dot      = "●",
}

return M
