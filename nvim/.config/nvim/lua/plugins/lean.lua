local keys = {
  { "i",     "LeanInfoviewToggle",                   "Toggle infoview" },
  { "<Tab>", "LeanGotoInfoview",                     "Jump to infoview" },

  { "r",     "LeanRestartFile",                      "Restart Lean server for this file" },
  { "s",     "LeanInfoviewAcceptSuggestion",         "Accept first suggestion" },
  { "\\",    "LeanAbbreviationsReverseLookup",       "How to type the character under the cursor" },

  { "x",     "LeanInfoviewAddPin",                   "Add pin" },
  { "c",     "LeanInfoviewClearPins",                "Clear all pins" },
  { "p",     "LeanInfoviewPinTogglePause",           "Toggle pausing pins" },

  { "dx",    "LeanInfoviewSetDiffPin",               "Set diff pin" },
  { "dc",    "LeanInfoviewClearDiffPin",             "Clear diff pin" },
  { "dd",    "LeanInfoviewToggleAutoDiffPin",        "Toggle auto-diff" },
  { "dt",    "LeanInfoviewToggleNoClearAutoDiffPin", "Toggle auto-diff, keeping pins" },

  { "w",     "LeanInfoviewEnableWidgets",            "Enable widgets" },
  { "W",     "LeanInfoviewDisableWidgets",           "Disable widgets" },
  { "v",     "LeanInfoviewViewOptions",              "Infoview view options" },
}

---@param bufnr integer
local function hover(bufnr)
  vim.keymap.set("n", "K", "<cmd>LeanHover<cr>", {
    buffer = bufnr,
    desc = "LSP: Lean interactive hover",
  })
end

return {
  setup = function()
    -- lean.nvim defaults to "never", which asks to restart each newly opened
    -- file with stale imports. Build once on open, keeping manual restarts intact.
    local on_init = vim.lsp.config.leanls.on_init
    local callbacks = type(on_init) == "table" and vim.list_extend({}, on_init) or { on_init }
    callbacks[#callbacks + 1] = function(client)
      local notify = client.notify
      client.notify = function(self, method, params)
        if method == "textDocument/didOpen" and params.dependencyBuildMode == nil then
          params.dependencyBuildMode = "once"
        end
        return notify(self, method, params)
      end
    end
    vim.lsp.config("leanls", { on_init = callbacks })

    local open_floating_preview = vim.lsp.util.open_floating_preview
    -- Intentional wrapper, composed with the shared documentation UI.
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
      opts = opts or {}
      if opts.focus_id == "lean_hover" or vim.bo.filetype == "lean" then
        opts = vim.tbl_extend("keep", opts, { border = "rounded" })
      end
      return open_floating_preview(contents, syntax, opts)
    end
  end,

  init = function()
    ---@type lean.Config
    vim.g.lean_config = {
      mappings = false,
      progress_bars = { enable = false },
      infoview = { autoopen = false },
      graphics = { enabled = true },
    }

    local group = vim.api.nvim_create_augroup("lean_keymaps", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "lean",
      callback = function(event)
        for _, mapping in ipairs(keys) do
          local lhs, command, desc = unpack(mapping)
          vim.keymap.set("n", "<leader>L" .. lhs, "<cmd>" .. command .. "<cr>", {
            buffer = event.buf,
            desc = desc,
          })
        end
        hover(event.buf)

        local ok, wk = pcall(require, "which-key")
        if ok then
          wk.add({
            { "<leader>L",  group = "Lean",      buffer = event.buf },
            { "<leader>Ld", group = "Diff pins", buffer = event.buf },
          })
        end
      end,
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      group = group,
      callback = function(event)
        if vim.bo[event.buf].filetype == "lean" then
          hover(event.buf)
        end
      end,
    })
  end,
}
