return {
	"saghen/blink.cmp",
	event = { "InsertEnter", "CmdlineEnter" },
	dependencies = {
		{ "L3MON4D3/LuaSnip", version = "v2.*" },
		"rafamadriz/friendly-snippets",
	},
	version = "1.*",
	opts = {
		snippets = { preset = "luasnip" },
		keymap = {
			preset = "default",
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-j>"] = { "select_next", "fallback" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
			["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
			["<CR>"] = { "accept", "fallback" },
			["<C-e>"] = { "show", "hide", "fallback" },
		},
		cmdline = {
			keymap = {
				["<C-k>"] = { "select_prev", "fallback" },
				["<C-j>"] = { "select_next", "fallback" },
				["<CR>"] = { "accept", "fallback" },
				["<C-e>"] = { "show", "hide", "fallback" },
			},
			completion = {
				list = { selection = { preselect = false, auto_insert = true } },
			},
			sources = { "cmdline", "path" },
		},
		appearance = {
			nerd_font_variant = "mono",
		},
		completion = {
			list = { selection = { preselect = false, auto_insert = true } },
			documentation = {
				auto_show = false,
				auto_show_delay_ms = 250,
				window = {
					border = "rounded",
					max_width = 80,
					max_height = 20,
					winblend = 0,
					winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
				},
			},
			ghost_text = { enabled = true, show_with_menu = true },
			menu = {
				min_width = 24,
				max_height = 12,
				border = "rounded",
				winblend = 0,
				winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
				scrolloff = 2,
				draw = {
					align_to = "label",
					padding = { 1, 2 },
					gap = 2,
					treesitter = { "lsp" },
					columns = {
						{ "kind_icon" },
						{ "label",      "label_description", gap = 1 },
						{ "source_name" },
					},
					components = {
						label = { width = { fill = true, max = 60 } },
						label_description = { width = { max = 40 } },
						source_name = { width = { max = 12 } },
						kind_icon = {
							highlight = function(ctx)
								return { { group = ctx.kind_hl, priority = 20000 } }
							end,
						},
					},
				},
			},
		},
		sources = {
			default = { "lsp", "path", "snippets", "buffer" },
			providers = {
				lsp = { score_offset = 10, fallbacks = {} },
				snippets = { score_offset = 2 },
				path = { score_offset = 0 },
				buffer = { score_offset = -2 },
				cmdline = {
					name = "cmdline",
					module = "blink.cmp.sources.cmdline",
					score_offset = 10,
				},
			},
		},
		fuzzy = { implementation = "prefer_rust" },
	},
	opts_extend = { "sources.default" },
	config = function(_, opts)
		require("blink.cmp").setup(opts)
		-- LuaSnip setup
		local ok, luasnip = pcall(require, "luasnip")
		if ok then
			require("luasnip.loaders.from_vscode").lazy_load()
			-- Custom snippets
			luasnip.add_snippets("go", {
				luasnip.snippet("ie", {
					luasnip.text_node({ "if err != nil {", "\t// handle error", "}" }),
				}),
			})
			-- Snippet navigation keymaps (avoid conflict with Copilot's Ctrl-L)
			vim.keymap.set({ "i", "s" }, "<C-n>", function()
				if luasnip.expand_or_jumpable() then
					luasnip.expand_or_jump()
				end
			end, { desc = "Expand or jump snippet" })
			vim.keymap.set({ "i", "s" }, "<C-p>", function()
				if luasnip.jumpable(-1) then
					luasnip.jump(-1)
				end
			end, { desc = "Jump back in snippet" })
		end
	end,
}
