return {
	"neysanfoo/party.nvim",
	config = function()
		require("party").setup({})
	end,
	vim.api.nvim_set_keymap("n", "<leader>lol", ":PartyToggle<CR>", { noremap = true, silent = true }),
}
