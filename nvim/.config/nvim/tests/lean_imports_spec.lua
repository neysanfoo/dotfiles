-- nvim --headless -u NONE -i NONE -l tests/lean_imports_spec.lua
-- Requires the installed lean.nvim and LEAN_TEST_TOOLCHAIN (defaults to v4.33.1).
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/site/pack/core/opt/lean.nvim")
vim.o.swapfile = false
vim.o.hidden = true

local root = assert(vim.uv.fs_mkdtemp(vim.uv.os_tmpdir() .. "/lean-imports-XXXXXX"))
vim.fn.mkdir(root .. "/ImportCheck", "p")
root = assert(vim.uv.fs_realpath(root))
vim.lsp.log._set_filename(root .. "/lsp.log")

local function write(path, lines)
  vim.fn.writefile(lines, root .. "/" .. path)
end

local client_id
local ok, err = xpcall(function()
  write("lean-toolchain", { vim.env.LEAN_TEST_TOOLCHAIN or "leanprover/lean4:v4.33.1" })
  write("lakefile.toml", { 'name = "import_check"', "[[lean_lib]]", 'name = "ImportCheck"' })
  write("ImportCheck/FirstDep.lean", { "def firstValue : Nat := 42" })
  write("ImportCheck/SecondDep.lean", { "def secondValue : Nat := 43" })
  write("First.lean", { "import ImportCheck.FirstDep", "example : firstValue = 42 := rfl" })
  write("Second.lean", { "import ImportCheck.SecondDep", "example : secondValue = 43 := rfl" })

  local spec = require("plugins.lean")
  spec.init()
  require("lean").init()
  local original_on_init = vim.lsp.config.leanls.on_init
  spec.setup()
  local config = assert(vim.lsp.config.leanls)
  local callbacks = config.on_init
  assert(type(callbacks) == "table", "Expected a list of initialization callbacks")
  assert(callbacks[1] == original_on_init, "Lean's existing initialization was replaced")

  local sent = {}
  local fake_client = {
    notify = function(_, method, params)
      sent[#sent + 1] = { method = method, params = vim.deepcopy(params) }
    end,
  }
  -- Only notify is exercised by this initialization wrapper.
  ---@cast fake_client vim.lsp.Client
  for _, callback in ipairs(callbacks) do
    callback(fake_client, { capabilities = {} })
  end
  fake_client:notify("textDocument/didOpen", {})
  fake_client:notify("textDocument/didOpen", { dependencyBuildMode = "never" })
  fake_client:notify("textDocument/didOpen", { dependencyBuildMode = "always" })
  fake_client:notify("textDocument/didOpen", { dependencyBuildMode = "once" })
  fake_client:notify("textDocument/didChange", { contentChanges = {} })
  assert(sent[1].params.dependencyBuildMode == "once")
  assert(sent[2].params.dependencyBuildMode == "never")
  assert(sent[3].params.dependencyBuildMode == "always")
  assert(sent[4].params.dependencyBuildMode == "once")
  assert(sent[5].params.dependencyBuildMode == nil)
  print("PASS: build-on-open policy, explicit modes and original initialization")

  local prompts = 0
  -- Deliberate UI mock: count unwanted import prompts without opening a picker.
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.ui.select = function(_, opts, choose)
    if opts.prompt:find("Imports are out of date", 1, true) then
      prompts = prompts + 1
    end
    choose("not now")
  end

  local function open(path)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. path))
    vim.bo.filetype = "lean"
    local bufnr = vim.api.nvim_get_current_buf()
    local client_config = vim.tbl_extend("force", config, { root_dir = root })
    client_id = assert(vim.lsp.start(client_config, { bufnr = bufnr }))
    assert(
      vim.wait(15000, function()
        local client = vim.lsp.get_client_by_id(client_id)
        return client ~= nil and client.initialized == true and vim.lsp.buf_is_attached(bufnr, client_id)
      end, 10),
      "Lean client did not initialize"
    )
    local client = assert(vim.lsp.get_client_by_id(client_id))
    -- Lean's custom protocol method is not in Neovim's standard LSP enum.
    ---@diagnostic disable-next-line: param-type-mismatch
    local response, failure = client:request_sync("textDocument/waitForDiagnostics", {
      uri = vim.uri_from_bufnr(bufnr),
      version = vim.lsp.util.buf_versions[bufnr],
    }, 30000, bufnr)
    assert(response and not response.err, vim.inspect(failure or response))
    assert(
      #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR }) == 0,
      vim.inspect(vim.diagnostic.get(bufnr))
    )
    assert(prompts == 0, "Opening a Lean file still prompted for a restart")
    return bufnr
  end

  local first = open("First.lean")
  assert(vim.uv.fs_stat(root .. "/.lake/build/lib/lean/ImportCheck/FirstDep.olean"), "First import was not built")
  local second = open("Second.lean")
  assert(vim.uv.fs_stat(root .. "/.lake/build/lib/lean/ImportCheck/SecondDep.olean"), "Second import was not built")
  vim.api.nvim_set_current_buf(first)
  vim.api.nvim_set_current_buf(second)
  assert(prompts == 0)
  print("PASS: opening and switching between real Lean files builds missing imports without prompting")

  write("ImportCheck/SecondDep.lean", { "def secondValue : Nat := 44" })
  require("lean.lsp").restart_file(second)
  local client = assert(vim.lsp.get_client_by_id(client_id))
  -- Lean's custom protocol method is not in Neovim's standard LSP enum.
  ---@diagnostic disable-next-line: param-type-mismatch
  local response, failure = client:request_sync("textDocument/waitForDiagnostics", {
    uri = vim.uri_from_bufnr(second),
    version = 0,
  }, 30000, second)
  assert(response and not response.err, vim.inspect(failure or response))
  assert(
    #vim.diagnostic.get(second, { severity = vim.diagnostic.severity.ERROR }) > 0,
    "Expected the proof to fail after rebuilding the changed dependency"
  )
  assert(prompts == 0)
  assert(vim.v.errmsg == "", vim.v.errmsg)
  print("PASS: manual restart rebuilds changed imports and proof errors remain visible")
end, debug.traceback)

if client_id then
  local client = vim.lsp.get_client_by_id(client_id)
  if client then
    client:stop()
    if not vim.wait(5000, function()
          return client:is_stopped()
        end, 10) then
      client:stop(true)
    end
  end
end
if not ok then
  io.stderr:write(err .. "\nFixture and log: " .. root .. "\n")
  vim.cmd("cquit 1")
end
vim.fn.delete(root, "rf")
print("All Lean import checks passed")
vim.cmd("qa!")
