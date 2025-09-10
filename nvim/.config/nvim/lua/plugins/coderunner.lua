return {
	"neysanfoo/coderunner.nvim",
	config = function()
		require("coderunner").setup({
			terminal_id = 5, -- use terminal 5 for RunInTerm
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
				tex = 'latexmk -pdf "$fullFilePath"',
				-- add other filetypes and their corresponding run commands here
			},
		})
		-- Set up the keybinding
		vim.keymap.set("n", "<Leader>i", "<cmd>Run<cr>", { noremap = true, silent = true, desc = "Run code" })
	end,
}
