local diagnostic_icons = require('icons').diagnostics

-- Enable the desired LSPs
vim.lsp.enable({
	"basedpyright",
	"bashls",
	"clangd",
	"cmake",
	"dockerls",
	"gopls",
	"html",
	"jdtls",
	"jsonls",
	"lua_ls",
	"ruff",
	"rust_analyzer",
	"tailwindcss",
	"vimls",
	"cssls",
	"ts_ls"
})

-- ==========================================
-- Diagnostic Configuration
-- ==========================================

vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = false,
	underline = true,
	severity_sort = true,
	update_in_insert = false,
	float = {
		header = "",
		prefix = "",
		border = "rounded",
	},
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = diagnostic_icons.ERROR,
			[vim.diagnostic.severity.WARN]  = diagnostic_icons.WARN,
			[vim.diagnostic.severity.HINT]  = diagnostic_icons.HINT,
			[vim.diagnostic.severity.INFO]  = diagnostic_icons.INFO,
		},
	},
})

-- ==========================================
-- Highlight Configuration
-- ==========================================

-- Gutter styling
local highlights = {
	SignColumn = { guibg = "none" },
	DiagnosticSignError = { guifg = "#ff0000", guibg = "none" },
	DiagnosticSignWarn = { guifg = "#ff8800", guibg = "none" },
	DiagnosticSignHint = { guifg = "#00ffff", guibg = "none" },
	DiagnosticSignInfo = { guifg = "#00ff00", guibg = "none" },
}

for group, opts in pairs(highlights) do
	vim.cmd(string.format("highlight %s guifg=%s guibg=%s",
		group, opts.guifg or "none", opts.guibg or "none"))
end

-- Set highlight links
local highlight_links = {
	NormalFloat = "Normal",
	FloatBorder = "Comment",
	DiagnosticFloatingError = "DiagnosticError",
	DiagnosticFloatingWarn = "DiagnosticWarn",
	DiagnosticFloatingInfo = "DiagnosticInfo",
	DiagnosticFloatingHint = "DiagnosticHint",
}

for group, link in pairs(highlight_links) do
	vim.api.nvim_set_hl(0, group, { link = link })
end

vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#1e1e2e" })
vim.api.nvim_set_hl(0, "FloatBorder", { bg = "#1e1e2e", fg = "#89b4fa" })
vim.api.nvim_set_hl(0, "Pmenu", { bg = "#1e1e2e" })
vim.api.nvim_set_hl(0, "PmenuSel", { bg = "#313244" })


vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
		end
		local bufnr = event.buf
		local client = vim.lsp.get_client_by_id(event.data.client_id)

		map("gr", "<cmd>Telescope lsp_references<CR>", "Show LSP references")
		map("gl", vim.diagnostic.open_float, "Open Diagnostic Float")
		map("K", function() vim.lsp.buf.hover({ border = "rounded" }) end, "Hover documentation")
		map("ls", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, "Signature help")
		map("gs", vim.lsp.buf.signature_help, "Signature Documentation")
		map("gd", vim.lsp.buf.definition, "Goto Declaration")
		map("gD", vim.lsp.buf.declaration, "Goto Declaration")

		map("<leader>gv", "<cmd>vsplit | lua vim.lsp.buf.definition()<cr>", "Goto Definition in Vertical Split")

		local wk = require("which-key")
		wk.add({
			{ "<leader>ca", vim.lsp.buf.code_action,                             desc = "Code Action" },
			{ "<leader>cA", vim.lsp.buf.range_code_action,                       desc = "Range Code Actions" },
			{ "<leader>ls", vim.lsp.buf.signature_help,                          desc = "Display Signature Information" },
			{ "<leader>rn", vim.lsp.buf.rename,                                  desc = "Rename all references" },
			{ "<leader>lc", require("config.utils").copyFilePathAndLineNumber,   desc = "Copy File Path and Line Number" },
			{ "<leader>li", "<cmd>LspInfo<CR>",                                  desc = "LSP Info" },
			{ "<leader>lr", "<cmd>LspRestart<CR>",                               desc = "Restart LSP" },
			{ "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, desc = "Format current buffer" },
			{ "<leader>ld", "<cmd>Telescope diagnostics bufnr=0<CR>",            desc = "Buffer Diagnostics" },
			{ "<leader>lD", "<cmd>Telescope diagnostics<CR>",                    desc = "Workspace Diagnostics" },
			{ "<leader>lj", function() vim.diagnostic.jump({ count = 1 }) end,   desc = "Next Diagnostic" },
			{ "<leader>lk", function() vim.diagnostic.jump({ count = -1 }) end,  desc = "Previous Diagnostic" },
		})


		if client and client:supports_method("textDocument/formatting", bufnr) then
			map("<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
		end

		if client and client:supports_method("textDocument/rangeFormatting", bufnr) then
			vim.keymap.set("x", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end,
				{ buffer = bufnr, desc = "Format range" })
		end
	end,

})
