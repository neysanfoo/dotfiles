return {
	cmd = { "basedpyright-langserver", "--stdio" },
	filetypes = { "python" },
	root_markers = { "pyproject.toml", "setup.cfg", "setup.py", "requirements.txt", ".git" },
	settings = {
		basedpyright = {
			analysis = {
				typeCheckingMode = "basic", -- or "strict"
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				diagnosticMode = "openFilesOnly",
				diagnosticSeverityOverrides = {
					reportUnusedImport = "none", -- Let Ruff handle this
					reportUnusedVariable = "none",
					reportDuplicateImport = "none",
				}
			}
		}
	}
}
