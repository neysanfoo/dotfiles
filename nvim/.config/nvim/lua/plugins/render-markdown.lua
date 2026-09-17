return function()
  require("render-markdown").setup({
    file_types = { "markdown", "blink-cmp-documentation" },
    -- Documentation only: leave ordinary Markdown editing/preview unchanged.
    ignore = function(buf) return vim.b[buf].ide_documentation ~= true end,
    -- Do not mutate global Markdown highlighting queries in ordinary buffers.
    patterns = { markdown = { disable = false } },
    render_modes = true,
    debounce = 60,
    max_file_size = 0.5,
    anti_conceal = { enabled = false },
    sign = { enabled = false },
    heading = { sign = false, width = "block", icons = { "", "", "", "", "", "" } },
    code = { sign = false, width = "block", left_pad = 1, right_pad = 1, language_icon = false },
    latex = { enabled = false },
    win_options = {
      conceallevel = { default = 0, rendered = 2 },
      concealcursor = { default = "", rendered = "nvic" },
    },
  })
end
