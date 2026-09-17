return function()
  require("party").setup({})
  vim.keymap.set("n", "<leader>lol", "<cmd>PartyToggle<CR>", { desc = "Toggle party" })
end
