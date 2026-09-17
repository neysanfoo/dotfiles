return function()
  require("trouble").setup({
    focus = true,
    auto_open = false,
    auto_close = false,
    auto_preview = false, -- p peeks; Enter jumps. List navigation leaves the editor alone.
    warn_no_results = false,
    open_no_results = true,
    multiline = true,
    max_items = 500,
    win = { position = "bottom", size = 0.25 },
  })
end
