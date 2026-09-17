local opts = { noremap = true, silent = true }

local keymap = vim.keymap.set

-- CORE KEYMAPS --

-- Leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Window navigation
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- EDITING --

-- Better paste
keymap("v", "p", '"_dP', opts)
keymap("i", "<C-r>", "<C-r><C-p>", opts)

-- Move text up and down in Visual Mode
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)

-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Clear search highlight
keymap("n", "<Leader>h", ":nohlsearch<CR>", opts)

-- Close buffer
keymap("n", "<S-q>", ":bd<CR>", opts)

-- Save file
keymap("n", "<Leader>w", ":w<CR>", opts)

-- Line Numbers
keymap("n", "<Leader>nr", ":set relativenumber<CR>", opts)
keymap("n", "<Leader>nn", ":set number<CR>", opts)

-- COMMENTING --
-- Keep the built-in gc operator/textobject, but remove the unused shortcuts.
-- Also clear old custom mappings when this file is re-sourced in a live session.
for _, lhs in ipairs({ "gcc", "gco", "gcO", "gcA", "gb", "gbc" }) do
  pcall(vim.keymap.del, "n", lhs)
end
pcall(vim.keymap.del, "x", "gb")

keymap("n", "<leader>/", "gc_", { remap = true, silent = true, desc = "Toggle comment" })
keymap("x", "<leader>/", "gc", { remap = true, silent = true, desc = "Toggle comment" })
keymap("n", "<D-/>", "gc_", { remap = true, silent = true, desc = "Toggle comment" })
keymap("x", "<D-/>", "gc", { remap = true, silent = true, desc = "Toggle comment" })
keymap("i", "<D-/>", "<Esc>gc_a", { remap = true, silent = true, desc = "Toggle comment" })
