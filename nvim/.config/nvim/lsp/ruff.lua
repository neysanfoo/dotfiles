return {
  cmd = function(dispatchers, config) return require("core.ruff").start(dispatchers, config) end,
  filetypes = { "python" },
  root_markers = { { ".ruff.toml", "ruff.toml", "pyproject.toml", "setup.cfg", "setup.py" }, ".git" },
  on_attach = function(client)
    -- basedpyright owns hover; Ruff handles linting/fixes/formatting.
    client.server_capabilities.hoverProvider = false
  end,
}
