return function()
  require("gruvbox").setup({
    terminal_colors = true,
    undercurl = true,
    underline = true,
    bold = true,
    italic = {
      strings = true,
      emphasis = true, -- Explicitly retain Gruvbox's default.
      comments = true,
      operators = false,
      folds = true,
    },
    strikethrough = true,
    invert_selection = false,
    invert_signs = false,
    invert_tabline = false,
    invert_intend_guides = false,
    inverse = true,
    contrast = "", -- "hard", "soft" or ""
    palette_overrides = {},
    overrides = {
      SignColumn  = { bg = "#282828" },
      NormalFloat = { bg = "#282828" },             -- match main background
      FloatBorder = { bg = "#282828", fg = "#ebdbb2" }, -- border stands out
      Pmenu       = { bg = "#282828" },             -- completion menu
      -- Override both: Gruvbox's default selection foreground is dark.
      PmenuSel    = { fg = "#fbf1c7", bg = "#504945", bold = true },
    },
    dim_inactive = false,
    transparent_mode = false,
  })
  vim.cmd("colorscheme gruvbox")
end
