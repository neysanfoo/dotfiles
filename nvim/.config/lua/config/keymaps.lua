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

-- Tmux integration
local tmux_ok = pcall(require, 'tmux')
if tmux_ok then
	keymap("n", "<C-Up>", "<cmd>lua require('tmux').resize_top()<cr>", opts)
	keymap("n", "<C-Down>", "<cmd>lua require('tmux').resize_bottom()<cr>", opts)
	keymap("n", "<C-Left>", "<cmd>lua require('tmux').resize_left()<cr>", opts)
	keymap("n", "<C-Right>", "<cmd>lua require('tmux').resize_right()<cr>", opts)
end

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
