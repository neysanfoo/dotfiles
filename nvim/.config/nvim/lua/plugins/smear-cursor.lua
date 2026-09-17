return function()
  local smear = require("smear_cursor")
  smear.setup({
    smear_between_buffers = false,
    -- Preserve the previous Normal-mode-only behavior after the plugin update.
    smear_insert_mode = false,
    smear_to_cmd = false,
    -- Keep code-buffer trails underneath documentation/completion windows.
    windows_zindex = 45,
  })

  -- Pause by window, not filetype: ordinary Markdown files still animate.
  -- Keep the user's toggle separate from this temporary popup pause.
  local wanted = true
  local function sync()
    local window = vim.api.nvim_win_get_config(0)
    local enabled = wanted and window.relative == "" and not window.external
    if smear.enabled ~= enabled then smear.enabled = enabled end
  end
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    group = vim.api.nvim_create_augroup("smear_cursor_windows", { clear = true }),
    callback = sync,
    desc = "Use the native cursor inside floating windows",
  })
  vim.api.nvim_create_user_command("SmearCursorToggle", function()
    wanted = not wanted
    sync()
  end, { desc = "Toggle cursor animation (always paused in floating windows)" })
  sync()
end
