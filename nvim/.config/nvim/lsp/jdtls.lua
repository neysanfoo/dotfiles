return {
  cmd = function(dispatchers, config)
    -- Independent workspace even for projects with the same directory name.
    local root = config.root_dir or vim.fn.getcwd()
    local workspace = vim.fn.stdpath('cache') .. '/jdtls/' .. vim.fn.sha256(root)
    vim.fn.mkdir(workspace, 'p')
    return vim.lsp.rpc.start({ 'jdtls', '-data', workspace }, dispatchers, {
      cwd = root, env = config.cmd_env, detached = config.detached,
    })
  end,
  filetypes = { 'java' },
  root_markers = { { 'mvnw', 'gradlew', 'settings.gradle', 'settings.gradle.kts' }, { 'pom.xml', 'build.gradle', 'build.gradle.kts' }, '.git' },
}
