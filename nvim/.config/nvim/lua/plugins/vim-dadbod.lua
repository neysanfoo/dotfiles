return function()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("native_sql_completion", { clear = true }),
    pattern = { "sql", "mysql", "plsql" },
    callback = function(event)
      vim.bo[event.buf].omnifunc = "vim_dadbod_completion#omni"
      vim.bo[event.buf].complete = "o,.,w,b"
    end,
  })
end
