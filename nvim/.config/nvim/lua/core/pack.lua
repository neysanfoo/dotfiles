-- Native package management. Plugin configuration lives in plain Lua functions;
-- dependencies are explicitly ordered here, with no Lazy spec compatibility layer.
local M = {}
local function github(repo, version)
  return { src = "https://github.com/" .. repo .. ".git", version = version }
end

M.specs = {
  github("nvim-lua/plenary.nvim"),
  github("nvim-tree/nvim-web-devicons"),
  github("mason-org/mason.nvim"),
  github("nvim-treesitter/nvim-treesitter", "master"),
  github("windwp/nvim-ts-autotag"),
  github("ahmedkhalf/project.nvim"),
  github("nvim-telescope/telescope-fzf-native.nvim"),
  github("ellisonleao/gruvbox.nvim"),
  github("aserowy/tmux.nvim"),
  github("akinsho/toggleterm.nvim", vim.version.range("*")),
  github("nvim-tree/nvim-tree.lua"),
  github("folke/which-key.nvim"),
  github("nvim-lualine/lualine.nvim"),
  github("lewis6991/gitsigns.nvim"),
  github("nvimtools/none-ls.nvim"),
  github("Julian/lean.nvim"),
  github("windwp/nvim-autopairs"),
  github("stevearc/aerial.nvim"),
  github("eandrju/cellular-automaton.nvim"),
  github("neysanfoo/coderunner.nvim"),
  github("neysanfoo/party.nvim"),
  github("karb94/neoscroll.nvim"),
  github("sphamba/smear-cursor.nvim"),
  github("iamcco/markdown-preview.nvim"),
  github("chomosuke/typst-preview.nvim", vim.version.range("1")),
  github("neysanfoo/wordy.nvim"),
  github("nvzone/volt"),
  github("nvzone/typr"),
  github("nvim-pack/nvim-spectre"),
  github("saghen/blink.cmp", vim.version.range("1")),
  -- The last 3.x tag predates Neovim 0.12's decoration-provider API fixes.
  github("folke/trouble.nvim", "main"),
  github("MeanderingProgrammer/render-markdown.nvim", vim.version.range("8")),
}

local function build(name, path)
  if name == "telescope-fzf-native.nvim" then
    local result = vim.system({ "make" }, { cwd = path, text = true }):wait()
    assert(result.code == 0, "Telescope FZF build failed: " .. (result.stderr or ""))
  elseif name == "nvim-treesitter" then
    vim.cmd.packadd("nvim-treesitter")
    vim.cmd("TSUpdate")
  elseif name == "markdown-preview.nvim" then
    vim.cmd.packadd("markdown-preview.nvim")
    vim.fn["mkdp#util#install"]()
  end
end

function M.setup()
  local pending = {}
  local ready = false
  vim.api.nvim_create_autocmd("PackChanged", {
    group = vim.api.nvim_create_augroup("native_pack_builds", { clear = true }),
    callback = function(event)
      local change = event.data
      if change.kind ~= "install" and change.kind ~= "update" then return end
      if ready or change.spec.name == "telescope-fzf-native.nvim" then
        build(change.spec.name, change.path)
      else
        pending[change.spec.name] = change.path
      end
    end,
  })

  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1
  require("plugins.lean").init()

  -- Preserve the live development checkout (vim.pack would clone it). On
  -- another machine, manage the same fork normally if that checkout is absent.
  local telescope_dev = vim.fn.expand("~/src/neysan.telescope.nvim")
  local use_dev = vim.uv.fs_stat(telescope_dev .. "/lua/telescope") ~= nil
  local specs = vim.deepcopy(M.specs)
  if use_dev then
    vim.opt.runtimepath:append(telescope_dev)
  else
    specs[#specs + 1] = github("neysanfoo/telescope.nvim")
  end

  vim.pack.add(specs, {
    load = function(package)
      -- UI libraries are configured on demand, not on every blank startup.
      local deferred = { ["blink.cmp"] = true, ["trouble.nvim"] = true, ["render-markdown.nvim"] = true }
      if not deferred[package.spec.name] then
        vim.cmd.packadd(package.spec.name)
      end
    end,
  })
  if use_dev then
    for _, script in ipairs(vim.fn.glob(telescope_dev .. "/plugin/**/*.{vim,lua}", false, true)) do
      vim.cmd.source({ script, magic = { file = false } })
    end
  end

  for _, module in ipairs({
    "colorscheme", "mason", "treesitter", "project", "telescope", "tmux",
    "toggleterm", "nvim-tree", "whichkey", "lualine", "gitsigns", "none-ls",
    "autopairs", "aerial", "cellular-automaton", "coderunner", "party",
    "markdown-preview", "typst-preview", "wordy", "typr", "spectre",
  }) do
    require("plugins." .. module)()
  end
  require("plugins.lean").setup()
  require("plugins.leanfmt")
  require("core.completion").prepare()

  -- Defer purely visual setup until startup has completed.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("native_pack_ui", { clear = true }),
    once = true,
    callback = function()
      require("plugins.neoscroll")()
      require("plugins.smear-cursor")()
    end,
  })
  vim.api.nvim_create_user_command("PackUpdate", function() vim.pack.update() end, { desc = "Review plugin updates" })
  vim.api.nvim_create_user_command("PackInfo", function() vim.pack.update(nil, { offline = true }) end,
    { desc = "Inspect native packages" })
  ready = true
  for name, path in pairs(pending) do build(name, path) end
end

return M
