-- Lean files only compile in the context of their Lake package, so walk up to the
-- nearest lakefile and run through `lake lean`; a loose file falls back to bare `lean`.
local lean = table.concat({
  'p="$dir"',
  'while [ "$p" != / ] && [ ! -e "$p/lakefile.toml" ] && [ ! -e "$p/lakefile.lean" ]; do p=$(dirname "$p"); done',
  'if [ -e "$p/lakefile.toml" ] || [ -e "$p/lakefile.lean" ]',
  'then cd "$p" && lake lean "$fullFilePath"',
  'else lean "$fullFilePath"',
  'fi',
}, "; ")

return function()
  require("coderunner").setup({
    terminal_id = 5,   -- use terminal 5 for RunInTerm
    clear_before_run = true,
    focus_back = true, -- return to editor after running
    filetype_commands = {
      python = 'python3 -u "$fullFilePath"',
      lua = "lua",
      c = { 'gcc "$fullFilePath" -o "$dir/out"', '"$dir/./out"' },
      cpp = { 'g++ -std=c++17 "$fullFilePath" -o "$dir/out"', '"$dir/./out"' },
      java = { 'javac "$fullFilePath"', 'java -cp ".:$dir" "$fileNameWithoutExt"' },
      javascript = 'node "$fullFilePath"',
      go = 'go run "$fullFilePath"',
      rust = { 'rustc "$fullFilePath" -o "$dir/out"', '"$dir/./out"' },
      prolog = 'swipl -s "$fullFilePath" -g main -t halt',
      tex =
      'cd "$dir" && mkdir -p .build && latexmk -pdf -outdir=.build "$fileName" && mv ".build/$fileNameWithoutExt.pdf" .',
      typst = 'typst compile "$fullFilePath"',
      lean = lean,
      -- add other filetypes and their corresponding run commands here
    },
  })
  -- Set up the keybinding
  vim.keymap.set("n", "<Leader>i", "<cmd>Run<cr>", { noremap = true, silent = true, desc = "Run code" })
end
