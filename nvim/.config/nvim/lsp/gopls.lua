return {
	cmd = { 'gopls' },
	filetypes = { 'go', 'gomod', 'gowork' },
	root_markers = { 'go.work', 'go.mod', '.git' },
	settings = {
		gopls = {
			analyses = { unusedparams = true },
			completeUnimported = true,
		},
	},
}
