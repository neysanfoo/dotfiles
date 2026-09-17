return {
  cmd = { 'vim-language-server', '--stdio' },
  filetypes = { 'vim' },
  root_markers = { '.git' },
  init_options = {
    isNeovim = true,
    diagnostic = { enable = true },
    indexes = { runtimepath = true, gap = 100, count = 3, projectRootPatterns = { 'runtime', 'nvim', '.git', 'autoload', 'plugin' } },
    suggest = { fromVimruntime = true, fromRuntimepath = true },
  },
}
