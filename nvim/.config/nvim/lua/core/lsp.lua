-- Blink augments these capabilities before any server starts; snippets remain native.
vim.lsp.config("*", {
  capabilities = { textDocument = { completion = { completionItem = { snippetSupport = true } } } },
})

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
  "leanfmt",
  "lua_ls",
  "ruff",
  "rust_analyzer",
  "tailwindcss",
  "vimls",
  "cssls",
  "ts_ls",
  "mdx_analyzer"
})

-- ==========================================
-- Server overrides
-- ==========================================
-- Server definitions are local lsp/<name>.lua files (no nvim-lspconfig).
-- These explicit overrides complement those native definitions.

-- JDTLS needs Java >= 21. Use the installed Homebrew JDK for the server only;
-- leave the shell/project Java runtime unchanged.
local jdtls_java_home = "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
if vim.fn.executable(jdtls_java_home .. "/bin/java") == 1 then
  vim.lsp.config("jdtls", { cmd_env = { JAVA_HOME = jdtls_java_home } })
end

-- Resolve MDX's TypeScript SDK, falling back to Mason outside a TS project.
vim.lsp.config("mdx_analyzer", {
  handlers = {
    ["client/registerCapability"] = function(err, result, ctx, config)
      -- The installed MDX server emits a single-item brace group. Neovim
      -- 0.12 rejects it, silently losing the watcher for external MDX edits.
      for _, registration in ipairs(result and result.registrations or {}) do
        if registration.method == "workspace/didChangeWatchedFiles" then
          for _, watcher in ipairs((registration.registerOptions or {}).watchers or {}) do
            if watcher.globPattern == "**/*.{mdx}" then
              watcher.globPattern = "**/*.mdx"
            end
          end
        end
      end
      return vim.lsp.handlers["client/registerCapability"](err, result, ctx, config)
    end,
  },
  before_init = function(params, config)
    -- Since 0.12 a JSON null arrives as vim.NIL (userdata), which is truthy in
    -- Lua, so an `or` chain over these fields has to skip it explicitly.
    local function present(v)
      if v == nil or v == vim.NIL or v == "" then
        return nil
      end
      return v
    end

    local root_uri = present(params.rootUri)
    local root = present(config.root_dir)
        or present(params.rootPath)
        or (root_uri and vim.uri_to_fname(root_uri))

    local candidates = {}
    if root then
      for _, dir in ipairs(vim.fs.find("node_modules", { path = root, upward = true, limit = math.huge })) do
        candidates[#candidates + 1] = dir .. "/typescript/lib"
      end
    end
    candidates[#candidates + 1] = vim.fn.expand(
      "~/.local/share/nvim/mason/packages/typescript-language-server/node_modules/typescript/lib"
    )

    for _, tsdk in ipairs(candidates) do
      if vim.uv.fs_stat(tsdk) then
        params.initializationOptions = params.initializationOptions or {}
        params.initializationOptions.typescript =
            params.initializationOptions.typescript or {}
        params.initializationOptions.typescript.tsdk = tsdk
        return
      end
    end
  end,
})

require("core.ui").setup()

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
    end
    local bufnr = event.buf
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client then require("core.completion").attach(client, bufnr) end

    map("gr", "<cmd>Telescope lsp_references<CR>", "Show LSP references")
    map("gl", function() require("core.ui").diagnostics() end, "Line diagnostics")
    map("K", require("core.ui").hover, "Hover documentation")
    map("gs", require("core.ui").signature, "Signature Documentation")
    map("gd", vim.lsp.buf.definition, "Goto Definition")
    map("gD", vim.lsp.buf.declaration, "Goto Declaration")

    map("<leader>gv", "<cmd>vsplit | lua vim.lsp.buf.definition()<cr>", "Goto Definition in Vertical Split")

    -- Buffer-local maps are discoverable by which-key without re-registering
    -- global mappings every time another server attaches.
    map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
    for _, lhs in ipairs({ "<leader>ca", "<leader>cA" }) do
      vim.keymap.set("x", lhs, vim.lsp.buf.code_action, { buffer = bufnr, desc = "LSP: Range Code Actions" })
    end
    map("<leader>ls", require("core.ui").signature, "Display Signature Information")
    map("<leader>rn", vim.lsp.buf.rename, "Rename all references")
    map("<leader>lc", require("config.utils").copyFilePathAndLineNumber, "Copy File Path and Line Number")
    map("<leader>li", "<cmd>checkhealth vim.lsp<CR>", "LSP Info")
    map("<leader>lr", "<cmd>lsp restart<CR>", "Restart attached LSPs")
    map("<leader>ld", "<cmd>Telescope diagnostics bufnr=0<CR>", "Buffer Diagnostics")
    map("<leader>lD", "<cmd>Telescope diagnostics<CR>", "Workspace Diagnostics")
    map("<leader>lj", function() vim.diagnostic.jump({ count = 1 }) end, "Next Diagnostic")
    map("<leader>lk", function() vim.diagnostic.jump({ count = -1 }) end, "Previous Diagnostic")


    if client and client:supports_method("textDocument/formatting", bufnr) then
      map("<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
    end

    if client and client:supports_method("textDocument/rangeFormatting", bufnr) then
      vim.keymap.set("x", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end,
        { buffer = bufnr, desc = "Format range" })
    end
  end,

})
