-- Native-LSP presentation; document rendering and Problems load on demand.
local M = {}
local names = { "Error", "Warn", "Info", "Hint" }
local icons = require("icons").diagnostics

function M.float_options(title)
  return {
    border = "rounded", title = " " .. title .. " ", title_pos = "left",
    max_width = math.max(20, math.min(84, vim.o.columns - 6)),
    max_height = math.max(4, math.min(20, math.floor(vim.o.lines * 0.45))),
    wrap = true, focusable = true, close_events = { "CursorMoved", "InsertEnter", "BufHidden" },
  }
end

local function decorate(buf, win)
  if not (buf and win and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)) then return end
  for key, value in pairs({
    wrap = true, linebreak = true, breakindent = true, signcolumn = "no",
    number = false, relativenumber = false, scrolloff = 1,
  }) do vim.wo[win][key] = value end
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end, { buffer = buf, silent = true, nowait = true, desc = "Close documentation" })
  end
  -- Focused docs scroll immediately, independently of main-buffer animations.
  for key, motion in pairs({ ["<C-f>"] = "<C-d>", ["<C-b>"] = "<C-u>" }) do
    vim.keymap.set("n", key, function()
      vim.cmd.normal({ args = { vim.keycode(motion) }, bang = true })
    end, { buffer = buf, silent = true, desc = "Scroll documentation" })
  end
end

function M.render_document(buf, win)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.b[buf].ide_documentation = true
  pcall(vim.treesitter.start, buf, "markdown")
  if not M.renderer_loaded then
    vim.cmd.packadd("render-markdown.nvim")
    require("plugins.render-markdown")()
    M.renderer_loaded = true
  end
  require("render-markdown").render({ buf = buf, win = win })
end

function M.hover()
  vim.lsp.buf.hover(M.float_options("Documentation"))
end

function M.signature()
  vim.lsp.buf.signature_help(M.float_options("Parameters"))
end

function M.diagnostics(opts)
  local config = vim.tbl_extend("force", M.float_options("Diagnostics"), { scope = "line" }, opts or {})
  local buf, win = vim.diagnostic.open_float(config)
  decorate(buf, win)
  return buf, win
end

function M.load_problems()
  if not M.problems_loaded then
    pcall(vim.api.nvim_del_user_command, "Trouble")
    vim.cmd.packadd("trouble.nvim")
    require("plugins.trouble")()
    M.problems_loaded = true
  end
  return require("trouble")
end

function M.problems(buffer_only)
  -- Trouble resolves `source` from the named mode; this API accepts partial options.
  ---@diagnostic disable-next-line: missing-fields
  M.load_problems().toggle({ mode = "diagnostics", filter = buffer_only and { buf = 0 } or nil })
end

function M.highlights()
  local function hl(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end
  local normal, comment, accent = hl("Normal"), hl("Comment"), hl("Special")
  local background = hl("NormalFloat").bg or normal.bg
  vim.api.nvim_set_hl(0, "NormalFloat", { fg = normal.fg, bg = background })
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = comment.fg, bg = background })
  vim.api.nvim_set_hl(0, "FloatTitle", { fg = accent.fg, bg = background, bold = true })
  for _, name in ipairs(names) do
    vim.api.nvim_set_hl(0, "DiagnosticVirtualText" .. name, { fg = hl("Diagnostic" .. name).fg, italic = true })
    vim.api.nvim_set_hl(0, "DiagnosticFloating" .. name, { link = "Diagnostic" .. name })
  end
  for group, target in pairs({
    BlinkCmpMenu = "NormalFloat", BlinkCmpMenuBorder = "FloatBorder",
    BlinkCmpMenuSelection = "PmenuSel", BlinkCmpDoc = "NormalFloat",
    BlinkCmpDocBorder = "FloatBorder", BlinkCmpDocSeparator = "FloatBorder",
    BlinkCmpSignatureHelp = "NormalFloat", BlinkCmpSignatureHelpBorder = "FloatBorder",
    BlinkCmpLabelDescription = "Comment", BlinkCmpLabelDetail = "Comment", BlinkCmpSource = "Comment",
  }) do vim.api.nvim_set_hl(0, group, { link = target }) end
  vim.api.nvim_set_hl(0, "BlinkCmpLabelMatch", { fg = accent.fg, bold = true })
  vim.api.nvim_set_hl(0, "BlinkCmpSignatureHelpActiveParameter", { fg = accent.fg, bold = true, underline = true })
end

function M.setup()
  vim.diagnostic.config({
    virtual_text = {
      current_line = true, spacing = 2, prefix = "●",
      severity = { min = vim.diagnostic.severity.WARN },
      format = function(diagnostic)
        local line = diagnostic.message:match("[^\r\n]+") or ""
        return vim.fn.strchars(line) > 80 and (vim.fn.strcharpart(line, 0, 77) .. "…") or line
      end,
    },
    virtual_lines = false,
    underline = { severity = { min = vim.diagnostic.severity.WARN } },
    severity_sort = true, update_in_insert = false,
    float = vim.tbl_extend("force", M.float_options("Diagnostics"), {
      header = false, source = false,
      prefix = function(diagnostic)
        local name = names[diagnostic.severity or 1]
        return icons[name:upper()] .. " ", "Diagnostic" .. name
      end,
      suffix = function(diagnostic)
        local parts = {}
        if diagnostic.source and diagnostic.source ~= "" then parts[#parts + 1] = diagnostic.source end
        if diagnostic.code then parts[#parts + 1] = tostring(diagnostic.code) end
        return #parts > 0 and ("  [" .. table.concat(parts, " · ") .. "]") or "", "Comment"
      end,
    }),
    signs = { text = {
      [vim.diagnostic.severity.ERROR] = icons.ERROR,
      [vim.diagnostic.severity.WARN] = icons.WARN,
      [vim.diagnostic.severity.INFO] = icons.INFO,
      [vim.diagnostic.severity.HINT] = icons.HINT,
    } },
    jump = { on_jump = function(_, bufnr)
      if bufnr == vim.api.nvim_get_current_buf() then M.diagnostics({ focus = false }) end
    end },
  })
  local group = vim.api.nvim_create_augroup("ide_ui", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = M.highlights })
  M.highlights()
  vim.treesitter.language.register("markdown", "blink-cmp-documentation")

  -- Keep native requests and second-press focus; leave Lean's widget hover alone.
  local open = vim.lsp.util.open_floating_preview
  -- Intentional wrapper: preserve native requests and decorate their result.
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
    local id = opts and opts.focus_id
    local docs = id == "textDocument/hover" or id == "textDocument/signatureHelp"
    local buf, win = open(contents, syntax, opts, ...)
    if docs then
      decorate(buf, win)
      if syntax == "markdown" then
        M.render_document(buf, win)
      end
    end
    return buf, win
  end

  vim.api.nvim_create_user_command("Trouble", function(args)
    M.load_problems()
    vim.cmd({ cmd = "Trouble", args = args.fargs, bang = args.bang })
  end, { nargs = "*", bang = true, desc = "Open the Problems and navigation panel" })
  vim.api.nvim_create_user_command("Problems", function(args) M.problems(args.bang) end,
    { bang = true, desc = "Workspace Problems (! for current buffer)" })
  vim.keymap.set("n", "<leader>xx", function() M.problems(false) end, { desc = "Workspace Problems" })
  vim.keymap.set("n", "<leader>xX", function() M.problems(true) end, { desc = "Buffer Problems" })
  vim.keymap.set("n", "<leader>xq", function() M.load_problems().toggle("qflist") end,
    { desc = "Quickfix Problems panel" })
end

return M
