local function format(bufnr)
  bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "leanfmt" })[1]
  if not client then
    return
  end
  local tick = vim.b[bufnr].changedtick
  client:request("textDocument/formatting", vim.lsp.util.make_formatting_params(), function(err, result)
    if err or not result then
      return
    end
    -- The buffer moved under the request; the edits describe a document that no longer exists.
    if vim.b[bufnr].changedtick ~= tick then
      return
    end
    vim.lsp.util.apply_text_edits(result, bufnr, client.offset_encoding)
  end, bufnr)
end

local group = vim.api.nvim_create_augroup("leanfmt_keymaps", { clear = true })

local function bind(buf)
  vim.keymap.set("n", "<leader>lf", function()
    format(buf)
  end, { buffer = buf, desc = "Format buffer (leanfmt)" })
end

vim.api.nvim_create_autocmd({ "FileType", "LspAttach" }, {
  group = group,
  callback = function(event)
    if vim.bo[event.buf].filetype == "lean" then
      bind(event.buf)
    end
  end,
})

return {}
