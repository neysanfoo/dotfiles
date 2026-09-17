return function()
  local keymap = vim.keymap
  keymap.set("n", "<leader>fml", "<cmd>CellularAutomaton make_it_rain<CR>")
end
