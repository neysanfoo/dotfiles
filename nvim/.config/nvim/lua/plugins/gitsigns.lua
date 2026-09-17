local giticons = require('icons').git


return function()
  local gitsigns = require("gitsigns")
  gitsigns.setup({
    signs = {
      add = { text = giticons.add },
      change = { text = giticons.change },
      delete = { text = giticons.delete },
      topdelete = { text = giticons.topdelete },
      changedelete = { text = giticons.changedelete },
      untracked = { text = giticons.untracked },
    },
    attach_to_untracked = true,
    on_attach = function(bufnr)
      local gs = gitsigns
      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        opts.desc = opts.desc or ""
        vim.keymap.set(mode, l, r, opts)
      end
      -- Navigation
      map("n", "]c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gs.nav_hunk("next")
        end
      end, { desc = "Next hunk" })
      map("n", "[c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gs.nav_hunk("prev")
        end
      end, { desc = "Previous hunk" })
      map("n", "<leader>gj", function() gs.nav_hunk("next") end, { desc = "Next hunk" })
      map("n", "<leader>gk", function() gs.nav_hunk("prev") end, { desc = "Previous hunk" })
      map("n", "<leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
      map("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
      map("n", "<leader>gS", gs.stage_buffer, { desc = "Stage buffer" })
      map("n", "<leader>gR", gs.reset_buffer, { desc = "Reset buffer" })
      -- Preserve undo-last-stage; stage_hunk() on a staged sign targets the cursor instead.
      ---@diagnostic disable-next-line: deprecated
      map("n", "<leader>gu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
      map("n", "<leader>gp", gs.preview_hunk, { desc = "Preview hunk" })
      map("n", "<leader>gl", function() gs.blame_line({ full = true }) end, { desc = "Blame line" })
      map("n", "<leader>gb", gs.toggle_current_line_blame, { desc = "Toggle line blame" })
      map("n", "<leader>gd", gs.diffthis, { desc = "Diff this" })
      map("n", "<leader>gD", function() gs.diffthis("~") end, { desc = "Diff this ~" })
      -- Preserve the all-deletions toggle; preview_hunk_inline() shows only the current hunk.
      ---@diagnostic disable-next-line: deprecated
      map("n", "<leader>gtd", gs.toggle_deleted, { desc = "Toggle deleted" })
      -- Visual mode
      map("v", "<leader>gs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, { desc = "Stage hunk" })
      map("v", "<leader>gr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, { desc = "Reset hunk" })
      -- Text object
      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select hunk" })
      -- Telescope integration
      map("n", "<leader>go", "<cmd>Telescope git_status<cr>", { desc = "Open changed file" })
      map("n", "<leader>gB", "<cmd>Telescope git_branches<cr>", { desc = "Checkout branch" })
      map("n", "<leader>gc", "<cmd>Telescope git_commits<cr>", { desc = "Checkout commit" })
      map("n", "<leader>gC", "<cmd>Telescope git_bcommits<cr>", { desc = "Buffer commits" })
    end,
  })
  -- Highlight customization
  local highlights = {
    GitSignsAdd = { bg = "none" },
    GitSignsChange = { bg = "none" },
    GitSignsDelete = { bg = "none" },
    GitSignsChangeDelete = { bg = "none" },
    GitSignsTopDelete = { bg = "none" },
    GitSignsCurrentLineBlame = {
      fg = "#e0e0e0",
    },
  }
  for group, opts in pairs(highlights) do
    local current = vim.api.nvim_get_hl(0, { name = group, link = false })
    vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", current, opts))
  end
end
