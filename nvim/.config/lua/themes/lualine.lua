local colors = {
  bg         = '#282828',
  fg         = '#ebdbb2',
  blue       = '#83a598',
  green      = '#b8bb26',
  orange     = '#fe8019',
  red        = '#fb4934',
  violet     = '#d3869b',
  gray       = '#928374',
  light_gray = '#a89984',
  dark_gray  = '#3c3836',
  panel      = '#32302f',
}

local B = { fg = colors.fg,         bg = colors.dark_gray }
local C = { fg = colors.light_gray, bg = colors.panel     }

local gruvbox_custom = {
  normal  = { a = { fg = colors.bg, bg = colors.blue,   gui = 'bold' }, b = B, c = C },
  insert  = { a = { fg = colors.bg, bg = colors.green,  gui = 'bold' }, b = B, c = C },
  visual  = { a = { fg = colors.bg, bg = colors.orange, gui = 'bold' }, b = B, c = C },
  command = { a = { fg = colors.bg, bg = colors.red,    gui = 'bold' }, b = B, c = C },
  replace = { a = { fg = colors.bg, bg = colors.violet, gui = 'bold' }, b = B, c = C },
  inactive= {
    a = { fg = colors.gray, bg = colors.panel },
    b = { fg = colors.gray, bg = colors.panel },
    c = { fg = colors.gray, bg = colors.panel },
  },
}

return gruvbox_custom
