return function()
  require("blink.cmp").setup({
    enabled = function()
      return not vim.tbl_contains({ "TelescopePrompt", "spectre_panel", "trouble" }, vim.bo.filetype)
    end,
    snippets = { preset = "default" }, -- vim.snippet, not LuaSnip
    fuzzy = { implementation = "prefer_rust" },
    appearance = { nerd_font_variant = "mono" },
    keymap = {
      preset = "none",
      ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-e>"] = { "cancel", "hide_signature", "fallback" },
      ["<CR>"] = { "accept", "fallback" },
      ["<C-y>"] = { "select_and_accept", "fallback" },
      ["<C-j>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Tab>"] = { "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "snippet_backward", "fallback" },
      ["<C-n>"] = {
        "snippet_forward",
        function(cmp)
          if not require("core.completion").go_iferr_available() then return end
          cmp.hide()
          vim.schedule(function() require("core.completion").expand_go_iferr() end)
          return true
        end,
        "select_next", "fallback_to_mappings",
      },
      ["<C-p>"] = { "snippet_backward", "select_prev", "fallback_to_mappings" },
      ["<C-f>"] = { "scroll_documentation_down", "scroll_signature_down", "fallback" },
      ["<C-b>"] = { "scroll_documentation_up", "scroll_signature_up", "fallback" },
      ["<C-s>"] = { "show_signature", "hide_signature", "fallback" },
    },
    completion = {
      list = { selection = { preselect = false, auto_insert = false } },
      ghost_text = { enabled = false },
      accept = { auto_brackets = { enabled = true } },
      menu = {
        border = "rounded",
        min_width = 24,
        max_height = 10,
        auto_show_delay_ms = 60,
        draw = {
          padding = { 1, 1 },
          gap = 2,
          columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
          components = {
            label = { width = { fill = true, max = 48 } },
            label_description = { width = { max = 28 } },
            source_name = { width = { max = 8 } },
          },
        },
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 180,
        update_delay_ms = 50,
        window = { border = "rounded", max_width = 72, max_height = 18, desired_min_height = 4 },
        draw = function(opts)
          -- The renderer uses Neovim's highlighter; do not run a second,
          -- synchronous Tree-sitter pass over every documentation line.
          opts.default_implementation({ use_treesitter_highlighting = false })
          -- Blink draws before opening the window; render after it is visible.
          local buf = opts.window:get_buf()
          vim.schedule(function()
            local win = opts.window:get_win()
            if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
              require("core.ui").render_document(buf, win)
            end
          end)
        end,
      },
    },
    signature = {
      enabled = true,
      window = { border = "rounded", max_width = 80, max_height = 4, show_documentation = false },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      providers = {
        lsp = { name = "LSP", score_offset = 10 },
        path = { name = "Path" },
        snippets = { name = "Snippet" },
        buffer = {
          name = "Text",
          min_keyword_length = 3,
          max_items = 8,
          score_offset = -5,
          opts = { get_bufnrs = function() return { vim.api.nvim_get_current_buf() } end },
        },
      },
    },
    -- Native command-line completion keeps command execution and Telescope input predictable.
    cmdline = { enabled = false },
  })
end
