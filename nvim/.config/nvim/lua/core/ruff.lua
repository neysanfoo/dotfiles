-- Resolve once per language-server start, never on cursor movement or formatting.
local M = {}
local windows = vim.fn.has("win32") == 1
local binary = windows and "Scripts/ruff.exe" or "bin/ruff"

local function ancestors(dir)
  local dirs = {}
  while dir do
    dirs[#dirs + 1] = dir
    -- Do not accidentally borrow an environment from a different repository.
    if vim.uv.fs_stat(dir .. "/.git") then break end
    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end
  return dirs
end

local function environment(dirs)
  for _, dir in ipairs(dirs) do
    for _, name in ipairs({ ".venv", "venv" }) do
      local exe = vim.fs.joinpath(dir, name, binary)
      if vim.fn.executable(exe) == 1 then return exe end
    end
  end
end

-- This only reads a simple, single-line literal `extend` path. Ruff itself
-- remains responsible for parsing/validating TOML and all formatter settings.
local function config_info(filename)
  local ok, lines = pcall(vim.fn.readfile, filename)
  if not ok then return end
  local pyproject = vim.fs.basename(filename) == "pyproject.toml"
  local section, found, extends = not pyproject, not pyproject, nil
  for _, line in ipairs(lines) do
    local header = line:match("^%s*(%[.-%])")
    if header then
      section = pyproject and header == "[tool.ruff]"
      found = found or section
    elseif section then
      local value, tail = line:match([[^%s*extend%s*=%s*"([^"\]+)"%s*(.*)$]])
      if not value then value, tail = line:match("^%s*extend%s*=%s*'([^']+)'%s*(.*)$") end
      if value and (tail == "" or tail:sub(1, 1) == "#") then extends = value end
    end
  end
  return found, extends
end

local function nearest_config(dirs)
  for _, dir in ipairs(dirs) do
    for _, name in ipairs({ ".ruff.toml", "ruff.toml", "pyproject.toml" }) do
      local filename = vim.fs.joinpath(dir, name)
      if config_info(filename) then return filename end
    end
  end
end

function M.executable(root)
  local dirs = ancestors(vim.fs.normalize(root or vim.uv.cwd()))
  local exe = environment(dirs)
  if exe then return exe end

  -- A scripts/ruff.toml can extend a sibling Python project's configuration.
  -- Follow that explicit relationship instead of scanning unrelated subprojects.
  local filename, seen = nearest_config(dirs), {}
  for _ = 1, 16 do
    if not filename or seen[filename] then break end
    seen[filename] = true
    local _, extends = config_info(filename)
    if not extends then break end
    extends = vim.fs.normalize(extends)
    local absolute = extends:sub(1, 1) == "/" or (windows and extends:match("^%a:/"))
    filename = vim.fs.normalize(absolute and extends or vim.fs.joinpath(vim.fs.dirname(filename), extends))
    if not vim.uv.fs_stat(filename) then break end
    exe = environment(ancestors(vim.fs.dirname(filename)))
    if exe then return exe end
  end

  local mason = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", windows and "ruff.exe" or "ruff")
  if vim.fn.executable(mason) == 1 then return mason end
  local system = vim.fn.exepath("ruff")
  return system ~= "" and system or "ruff"
end

function M.start(dispatchers, config)
  -- Record the actual executable for :checkhealth vim.lsp and troubleshooting.
  config.cmd = { M.executable(config.root_dir), "server" }
  return vim.lsp.rpc.start(config.cmd, dispatchers, {
    cwd = config.cmd_cwd, env = config.cmd_env, detached = config.detached,
  })
end

return M
