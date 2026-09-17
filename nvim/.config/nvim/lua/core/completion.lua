local M = {}

function M.go_iferr_available()
  if vim.bo.filetype ~= "go" or vim.fn.mode() ~= "i" then return false end
  local prefix = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_win_get_cursor(0)[2])
  return prefix:match("%f[%w]ie$") ~= nil
end

function M.expand_go_iferr()
  if not M.go_iferr_available() then return end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  vim.api.nvim_buf_set_text(0, row, col - 2, row, col, { "" })
  vim.api.nvim_win_set_cursor(0, { row + 1, col - 2 })
  vim.snippet.expand("if err != nil {\n\t${1:// handle error}\n}\n$0")
end

function M.attach(client, bufnr)
  if not client:supports_method("textDocument/completion", bufnr) then return end
  -- Blink owns automatic completion. Keep omnifunc available as a native fallback.
  vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
end

function M.load()
  if M.loaded then return end
  require("plugins.blink")()
  M.loaded = true
end

function M.prepare()
  -- Add to runtime without sourcing plugin scripts. Capabilities must be sent
  -- before the first LSP initializes; the UI itself can wait for editing.
  vim.cmd.packadd({ "blink.cmp", bang = true })
  vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
  vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile", "InsertEnter" }, {
    group = vim.api.nvim_create_augroup("ide_completion_load", { clear = true }),
    once = true,
    callback = M.load,
  })
end

function M.setup()
  vim.opt.completeopt = { "menuone", "noselect", "popup", "fuzzy" }
  vim.opt.complete = { ".", "w", "b" }
  -- Never run Neovim's automatic popup and Blink's menu simultaneously.
  vim.opt.autocomplete = false
  vim.opt.pumborder = "rounded"
  vim.opt.wildmenu = true
  vim.opt.wildmode = "longest:full,full"
  vim.opt.wildoptions = { "pum", "fuzzy" }

  local expr = { expr = true, silent = true }
  local function selected()
    return vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected >= 0
  end
  vim.keymap.set("i", "<CR>", function()
    if selected() then return vim.keycode("<C-y>") end
    local autopairs = package.loaded["nvim-autopairs"]
    local newline = autopairs and autopairs.autopairs_cr() or vim.keycode("<CR>")
    return (vim.fn.pumvisible() == 1 and vim.keycode("<C-e>") or "") .. newline
  end, { expr = true, silent = true, replace_keycodes = false })
  vim.keymap.set("i", "<C-j>", function() return vim.fn.pumvisible() == 1 and "<C-n>" or "<C-j>" end, expr)
  vim.keymap.set("i", "<C-k>", function() return vim.fn.pumvisible() == 1 and "<C-p>" or "<C-k>" end, expr)
  for key, direction in pairs({ ["<C-n>"] = 1, ["<C-p>"] = -1 }) do
    vim.keymap.set({ "i", "s" }, key, function()
      if vim.snippet.active({ direction = direction }) then
        return ("<Cmd>lua vim.snippet.jump(%d)<CR>"):format(direction)
      end
      if direction == 1 and M.go_iferr_available() then
        return "<Cmd>lua require('core.completion').expand_go_iferr()<CR>"
      end
      return key
    end, vim.tbl_extend("force", expr, { desc = "Native snippet jump or completion" }))
  end
  vim.keymap.set("i", "<C-Space>", function()
    if vim.bo.omnifunc ~= "" then return "<C-x><C-o>" end
    return "<C-n>"
  end, vim.tbl_extend("force", expr, { desc = "Trigger native completion" }))
  -- Ctrl-E cancels native completion; Ctrl-X Ctrl-F completes filesystem paths.
  -- Cmdline Tab/Shift-Tab remain native; retain Ctrl-J/K while its menu is open.
  vim.keymap.set("c", "<C-j>", function() return vim.fn.wildmenumode() == 1 and "<C-n>" or "<C-j>" end, expr)
  vim.keymap.set("c", "<C-k>", function() return vim.fn.wildmenumode() == 1 and "<C-p>" or "<C-k>" end, expr)

  local group = vim.api.nvim_create_augroup("native_completion", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "TelescopePrompt", "spectre_panel" },
    callback = function(event) vim.bo[event.buf].autocomplete = false end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "go",
    callback = function(event)
      vim.api.nvim_buf_create_user_command(event.buf, "GoIfErr", function()
        vim.snippet.expand("if err != nil {\n\t${1:// handle error}\n}\n$0")
      end, { desc = "Expand the native Go error-handling snippet" })
    end,
  })
end

return M
