-- nvim --headless -u NONE -i NONE -l tests/ruff_spec.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local root = assert(vim.uv.fs_mkdtemp(vim.uv.os_tmpdir() .. '/nvim-ruff-test-XXXXXX'))
root = assert(vim.uv.fs_realpath(root))
vim.lsp.log._set_filename(vim.fn.tempname() .. '.log')
local ruff = require('core.ruff')
local binary = vim.fn.has('win32') == 1 and 'Scripts/ruff.exe' or 'bin/ruff'
local function write(name, lines)
  local filename = root .. '/' .. name
  vim.fn.mkdir(vim.fs.dirname(filename), 'p')
  vim.fn.writefile(lines or {}, filename)
  return filename
end
local function executable(name)
  local filename = write(name .. '/' .. binary)
  assert(vim.uv.fs_chmod(filename, 493)) -- 0755; only used for discovery, never executed.
  return filename
end
local original_start, original_executable, original_exepath = vim.lsp.rpc.start, vim.fn.executable, vim.fn.exepath
local ok, err = xpcall(function()
  write('empty/.git', {})
  local fallback = ruff.executable(root .. '/empty')
  local mason = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason/bin', vim.fn.has('win32') == 1 and 'ruff.exe' or 'ruff')
  if vim.fn.executable(mason) == 1 then assert(fallback == mason, 'Mason must be the first fallback') end
  write('repo/.git', {})
  write('repo/catalog/pyproject.toml', { '[tool.ruff]', 'line-length = 100' })
  local catalog = executable('repo/catalog/.venv')
  write('repo/scripts/ruff.toml', { 'extend = "../catalog/pyproject.toml" # shared project' })
  assert(ruff.executable(root .. '/repo/catalog') == catalog, 'Project Ruff should beat Mason')
  assert(ruff.executable(root .. '/repo/scripts') == catalog, 'Sibling Ruff should follow explicit inheritance')
  assert(ruff.executable(root .. '/empty') == fallback, 'Project selection leaked to another workspace')
  write('repo/scripts/sub/file.py', {})
  assert(ruff.executable(root .. '/repo/scripts/sub') == catalog, 'Nested files should inherit the same project')
  local scripts = executable('repo/scripts/.venv')
  assert(ruff.executable(root .. '/repo/scripts') == scripts, 'Nearest local environment should beat inherited one')
  local legacy = executable('repo/legacy/venv')
  assert(ruff.executable(root .. '/repo/legacy') == legacy, 'venv directory should also work')
  executable('.venv')
  assert(ruff.executable(root .. '/empty') == fallback, 'Discovery escaped the Git boundary')
  print('PASS: nearest environment, inherited sibling, venv, independent workspaces, Git boundary and Mason fallback')

  write('repo/chain/ruff.toml', { "extend = '../shared/ruff.toml'" })
  write('repo/shared/ruff.toml', { 'extend = "../catalog/pyproject.toml"' })
  assert(ruff.executable(root .. '/repo/chain') == catalog, 'Multi-hop literal inheritance should work')
  write('repo/absolute/ruff.toml', { 'extend = "' .. root .. '/repo/catalog/pyproject.toml"' })
  assert(ruff.executable(root .. '/repo/absolute') == catalog, 'Absolute inheritance should work')
  write('repo/from-pyproject/pyproject.toml', {
    '[project]', 'name = "example"', '[tool.ruff]', 'extend = "../catalog/pyproject.toml"',
  })
  assert(ruff.executable(root .. '/repo/from-pyproject') == catalog, 'pyproject Ruff section should support inheritance')
  write('repo/cycle/ruff.toml', { 'extend = "../cycle2/ruff.toml"' })
  write('repo/cycle2/ruff.toml', { 'extend = "../cycle/ruff.toml"' })
  assert(ruff.executable(root .. '/repo/cycle') == fallback, 'Cyclic inheritance should terminate safely')
  write('repo/missing/ruff.toml', { 'extend = "../absent/ruff.toml"' })
  assert(ruff.executable(root .. '/repo/missing') == fallback, 'Missing inherited config should not break startup')
  write('repo/precedence/.ruff.toml', { 'line-length = 88' })
  write('repo/precedence/ruff.toml', { 'extend = "../catalog/pyproject.toml"' })
  assert(ruff.executable(root .. '/repo/precedence') == fallback, '.ruff.toml should take precedence over ruff.toml')
  write('repo/not-ruff/pyproject.toml', { '[tool.other]', 'extend = "../catalog/pyproject.toml"' })
  assert(ruff.executable(root .. '/repo/not-ruff') == fallback, 'Do not read another tool\'s extend key')
  print('PASS: config precedence, literal/absolute/chained inheritance, missing targets and cycles')

  local spec = dofile('lsp/ruff.lua')
  assert(vim.fs.root(root .. '/repo/chain', spec.root_markers) == root .. '/repo/chain',
    'ruff.toml must define the LSP root')
  local calls = {}
  -- Deliberate test doubles, restored below even if an assertion fails.
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.rpc.start = function(cmd, dispatchers, opts)
    calls[#calls + 1] = { cmd = cmd, dispatchers = dispatchers, opts = opts }
    return { test = true }
  end
  local config = { root_dir = root .. '/repo/catalog', cmd_env = { RUFF_TEST = '1' }, cmd_cwd = root, detached = false }
  local dispatchers = {}
  assert(spec.cmd(dispatchers, config).test)
  assert(config.cmd[1] == catalog and config.cmd[2] == 'server', 'Actual executable should be recorded for inspection')
  assert(calls[1].dispatchers == dispatchers and calls[1].opts.env == config.cmd_env)
  assert(calls[1].opts.cwd == root and calls[1].opts.detached == false, 'Preserve native process options')
  spec.cmd(dispatchers, { root_dir = root .. '/empty' })
  assert(calls[2].cmd[1] == fallback and type(spec.cmd) == 'function',
    'One server should not overwrite another\'s factory')
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.fn.executable = function() return 0 end
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.fn.exepath = function() return '/system/ruff' end
  assert(ruff.executable(root .. '/empty') == '/system/ruff', 'PATH fallback should work without Mason')
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.fn.exepath = function() return '' end
  assert(ruff.executable(root .. '/empty') == 'ruff', 'Missing Ruff should retain the native executable-not-found error')
  print('PASS: native LSP launch, inspectable command, independent clients and system fallback')
end, debug.traceback)
vim.lsp.rpc.start, vim.fn.executable, vim.fn.exepath = original_start, original_executable, original_exepath
vim.fn.delete(root, 'rf')
if not ok then error(err) end
print('All Ruff resolver checks passed')
