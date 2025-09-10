return {
	cmd = { "ruff", "server", "--preview" },
	filetypes = { "python" },
	root_markers = { "pyproject.toml", "setup.cfg", "setup.py", ".git" },
	init_options = {
		settings = {
			args = { "--fix" }, -- Enables auto-fix formatting
		},
	},
}
