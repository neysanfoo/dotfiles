-- Run with the real config and installed plugins:
-- nvim --headless -i NONE -c 'luafile tests/health_config_spec.lua'
vim.defer_fn(function()
  local ok, err = xpcall(function()
    local removed = { ["lazy.nvim"] = true, LuaSnip = true, ["friendly-snippets"] = true, ["nvim-lspconfig"] = true,
      ["mason-lspconfig.nvim"] = true, ["copilot.vim"] = true, ["vim-dadbod"] = true, ["vim-dadbod-ui"] = true,
      ["vim-dadbod-completion"] = true }
    for _, plugin in ipairs(vim.pack.get(nil, { info = false })) do
      assert(not removed[plugin.spec.name], "Legacy package still managed: " .. plugin.spec.name)
    end
    for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
      assert(not path:find("/lazy/", 1, true), "Legacy runtime remains: " .. path)
      assert(not path:find("/copilot.vim", 1, true), "Removed Copilot is still on runtimepath")
    end
    assert(package.loaded.lazy == nil)
    assert(not require("core.completion").loaded, "Completion UI loaded before editing")
    assert(not package.loaded["render-markdown"] and not package.loaded.trouble, "Optional UI loaded at startup")
    assert(vim.fn.maparg("<C-Up>", "n", false, true).callback == require("tmux").resize_top)
    print("PASS: native packages, removed plugins stay removed, deferred UI and tmux mappings")

    for _, cmd in ipairs({ "Telescope", "GitDiffFiles", "Run", "AerialToggle", "TypstPreview", "PackUpdate", "PackInfo", "LspInstallAll", "Problems", "Trouble" }) do
      assert(vim.fn.exists(":" .. cmd) == 2, "Missing command: " .. cmd)
    end
    local sorter = require("telescope.config").values.generic_sorter({})
    sorter:_init()
    assert(sorter:scoring_function("needle", "needle.lua") > 0)
    sorter:_destroy()
    assert(not vim.o.autocomplete, "Native completion must not compete with Blink")
    assert(type(vim.snippet.expand) == "function")
    assert(vim.lsp.config["*"].capabilities.textDocument.completion.completionItem.snippetSupport)
    print("PASS: plugin commands, native fuzzy sorting, snippets and LSP capabilities")

    local lua_ls = assert(vim.lsp.config.lua_ls)
    local lua_settings = lua_ls.settings.Lua
    assert(type(lua_settings) == "table", "Expected LuaLS settings")
    ---@cast lua_settings { runtime: { pathStrict: boolean }, workspace: { library: string[] } }
    assert(lua_settings.runtime.pathStrict, "LuaLS must not confuse plugin APIs with config modules")
    local config_dir = assert(vim.uv.fs_realpath(vim.fn.stdpath("config")))
    local lua_root = assert(vim.fs.root(config_dir, lua_ls.root_markers))
    assert(lua_root == config_dir, "LuaLS should use the Neovim config as its workspace, not all dotfiles")
    local libraries = lua_settings.workspace.library
    assert(not vim.tbl_contains(libraries, config_dir) and not vim.tbl_contains(libraries, config_dir .. "/lua"),
      "Own configuration must remain workspace source, not a read-only library")
    for _, package in ipairs(vim.pack.get(nil, { info = false })) do
      local source = vim.uv.fs_realpath(package.path .. "/lua")
      if source then assert(vim.tbl_contains(libraries, source), "Missing LuaLS plugin library: " .. package.spec.name) end
    end
    print("PASS: LuaLS strict module lookup, isolated config workspace and native package libraries")

    -- Exercise LspAttach without launching or editing a real project.
    local buffer = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(buffer)
    vim.api.nvim_exec_autocmds("LspAttach", { buffer = buffer, data = { client_id = -1 } })
    assert(vim.fn.maparg(" lr", "n", false, true).rhs == "<cmd>lsp restart<CR>")
    assert(vim.fn.maparg(" cA", "x", false, true).callback == vim.lsp.buf.code_action)
    assert(vim.fn.maparg(" ca", "n", false, true).buffer == 1)
    assert(vim.fn.maparg("gr", "n", false, true).rhs == "<cmd>Telescope lsp_references<CR>")
    vim.cmd.enew()
    assert(vim.fn.maparg(" ca", "n") == "", "LSP mappings leaked into an unrelated buffer")
    print("PASS: current LSP APIs and buffer-local code actions")
    vim.bo.filetype = "sql"
    assert(vim.bo.omnifunc ~= "vim_dadbod_completion#omni", "Removed Dadbod omnifunc was still configured")
    print("PASS: no dangling SQL completion hooks")

    local method = "client/registerCapability"
    local original = vim.lsp.handlers[method]
    local forwarded
    vim.lsp.handlers[method] = function(_, result) forwarded = result end
    local success, failure = pcall(vim.lsp.config.mdx_analyzer.handlers[method], nil, {
      registrations = { {
        method = "workspace/didChangeWatchedFiles",
        registerOptions = {
          watchers = { { globPattern = "**/*.{mdx}" }, { globPattern = "**/*.{js,ts}" } },
        }
      } },
    }, {}, {})
    vim.lsp.handlers[method] = original
    assert(success, failure)
    local watchers = forwarded.registrations[1].registerOptions.watchers
    assert(watchers[1].globPattern == "**/*.mdx")
    assert(watchers[2].globPattern == "**/*.{js,ts}")
    print("PASS: MDX watcher compatibility without altering other patterns")
  end, debug.traceback)
  if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
  else
    print("All configuration health regression checks passed")
    vim.cmd("qa!")
  end
end, 100)
