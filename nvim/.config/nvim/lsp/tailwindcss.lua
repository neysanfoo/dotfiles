return {
  cmd = { 'tailwindcss-language-server', '--stdio' },
  filetypes = { 'html', 'css', 'scss', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'svelte', 'vue' },
  root_dir = function(bufnr, on_dir)
    local root = vim.fs.root(bufnr,
      { 'tailwind.config.js', 'tailwind.config.cjs', 'tailwind.config.mjs', 'tailwind.config.ts' })
    if root then
      on_dir(root); return
    end
    -- Tailwind v4 may have no config. Avoid starting in unrelated projects.
    local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
    for _, file in ipairs(vim.fs.find('package.json', { path = dir, upward = true, limit = math.huge })) do
      local ok, package = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(file), '\n')) end)
      if ok and ((package.dependencies or {}).tailwindcss or (package.devDependencies or {}).tailwindcss) then
        on_dir(vim.fs.dirname(file))
        return
      end
    end
  end,
  settings = { tailwindCSS = { validate = true }, editor = { tabSize = 2 } },
}
