-- Include installed plugin APIs (also deferred vim.pack packages), not just our
-- setup functions. Only index their Lua sources, not their tests/build outputs.
local library, seen = {}, {}
local config_dir = vim.uv.fs_realpath(vim.fn.stdpath("config")) or vim.fn.stdpath("config")
local function add_library(path)
  local real = vim.uv.fs_realpath(path)
  if not real or seen[real] or real == config_dir or real == config_dir .. "/lua" then return end
  seen[real] = true
  library[#library + 1] = real
end
add_library(vim.env.VIMRUNTIME)
for _, path in ipairs(vim.api.nvim_get_runtime_file("lua", true)) do add_library(path) end
for _, package in ipairs(vim.pack.get(nil, { info = false })) do add_library(package.path .. "/lua") end

return {
  -- Command and arguments to start the server.
  cmd = { 'lua-language-server' },

  -- Filetypes to automatically attach to.
  filetypes = { 'lua' },

  root_markers = { { '.luarc.json', '.luarc.jsonc' }, '.git' },

  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
        path = { "?.lua", "?/init.lua", "lua/?.lua", "lua/?/init.lua" },
        -- require("gitsigns") must not resolve to lua/plugins/gitsigns.lua.
        pathStrict = true,
      },

      diagnostics = {
        globals = { "vim" },
      },

      workspace = {
        library = library,
        checkThirdParty = false,
      },

      format = {
        enable = true,
        defaultConfig = {
          align_continuous_inline_comment = "false",
          space_before_inline_comment = "keep",
        },
      },

      telemetry = {
        enable = false,
      },
    },
  }
}
