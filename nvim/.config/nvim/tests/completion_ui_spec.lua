-- nvim --headless -u NONE -i NONE -l tests/completion_ui_spec.lua
-- An embedded Neovim exercises real Insert keys and the full config.
-- Uses a local mock LSP: no network or Python provider is needed.
local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-n", "-i", "NONE" }, {
  rpc = true, on_stderr = function(_, data) io.stderr:write(table.concat(data, '\n')) end,
})
assert(child > 0, "Could not start embedded Neovim")
local step = 'startup'
vim.defer_fn(function()
  io.stderr:write('UI test watchdog stopped child at: ' .. step .. '\n')
  vim.fn.jobstop(child)
end, 30000)
local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
local function lua(code) return rpc("nvim_exec_lua", code, {}) end
local function keys(sequence) rpc("nvim_input", sequence) end
local function expect(expression, message)
  step = message
  assert(vim.wait(10000, function() return lua("return not not (" .. expression .. ")") == true end, 20), message)
end

local ok, err = xpcall(function()
  rpc("nvim_ui_attach", 100, 35, { rgb = true })
  lua([[
		vim.o.messagesopt = 'wait:0,history:500'
		require('core.completion').load()
		_G.ui_test_check_selection = function()
			for _, name in ipairs({'PmenuSel', 'BlinkCmpMenuSelection'}) do
				local selection = vim.api.nvim_get_hl(0, {name=name, link=false})
				assert(selection.fg == 0xfbf1c7 and selection.bg == 0x504945,
					'Completion selection should use bright text on a distinct warm-grey background')
				assert(selection.bold and not selection.reverse, 'Completion selection should be bold, not inverted')
			end
		end
		_G.ui_test_check_selection()
		vim.cmd.colorscheme('gruvbox')
		_G.ui_test_check_selection()
		require('blink.cmp.config').completion.menu.auto_show = false
		_G.ui_test_requests = {}
		_G.ui_test_documentation = '# Documentation\n\n```lua\nnative(value)\n```\n\n'
			.. '[View documents](http://www.lua.org/manual/5.1/manual.html#pdf-require) and [More](https://example.com/a_(b))\n\n'
			.. '<https://example.com/reference>\n\n'
			.. '[Local file](file:///private/tmp/example.lua)\n\n'
			.. '`[Code example](https://example.com/not-a-link)`\n\n'
			.. string.rep('Useful **parameter** details with `inline code`.\n\n', 25)
		vim.cmd.enew()
		vim.bo.buftype = 'nofile'
		vim.bo.commentstring = '-- %s'
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { '-- first', '' })
		vim.api.nvim_win_set_cursor(0, { 2, 0 })
		_G.completion_test_client = vim.lsp.start({
			name = 'native_completion_test',
			cmd = function(dispatchers)
				local closed, request_id = false, 0
				return {
					request = function(method, params, callback)
						_G.ui_test_requests[#_G.ui_test_requests + 1] = method
						request_id = request_id + 1
						local response
						if method == 'initialize' then
							response = { capabilities = {
								completionProvider = { triggerCharacters = { '.' } }, textDocumentSync = 1,
								hoverProvider = true, signatureHelpProvider = { triggerCharacters = { '(', ',' } },
							} }
						elseif method == 'textDocument/hover' then
							response = { contents = { kind = 'markdown', value = _G.ui_test_documentation } }
						elseif method == 'textDocument/signatureHelp' then
							response = { activeSignature = 0, activeParameter = 0, signatures = { {
								label = 'native(value: string)', parameters = { { label = { 7, 20 } } },
								documentation = 'This description should not overwhelm the compact parameter hint.',
							} } }
						elseif method == 'textDocument/completion' then
							response = { isIncomplete = false, items = { {
								label = 'nativeSnippet', filterText = 'nativeSnippet', kind = 15,
								documentation = { kind = 'markdown', value = _G.ui_test_documentation },
								insertText = 'native(${1:value})$0', insertTextFormat = 2,
								additionalTextEdits = { {
									range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } },
									newText = '-- import added\n',
								} },
							} } }
						end
						vim.schedule(function() callback(nil, response) end)
						return true, request_id
					end,
					notify = function(method)
						if method == 'exit' then closed = true; dispatchers.on_exit(0, 0) end
						return true
					end,
					is_closing = function() return closed end,
					terminate = function() closed = true end,
				}
			end,
		})
	]])
  expect("vim.lsp.get_client_by_id(_G.completion_test_client).initialized", "Test server did not initialize")
  keys("ina")
  expect("vim.fn.mode() == 'i'", "Did not enter Insert mode")
  expect("vim.fn.maparg('<C-Space>', 'i', false, true).buffer == 1", "Blink keymaps did not initialize")
  keys("<C-Space>")
  expect("require('blink.cmp').is_visible()", "Manual completion menu missing")
  keys("<C-j>")
  expect("require('blink.cmp').get_selected_item()", "Ctrl-J did not select a candidate")
  lua("_G.ui_test_check_selection()")
  print("PASS: readable completion selection after lazy loading and colorscheme reload")
  assert(lua("return vim.fn.getline(2)") == "na", "Navigating suggestions inserted text")
  expect("require('blink.cmp').is_documentation_visible()", "Completion documentation did not appear")
  lua([[
		_G.docs_win = require('blink.cmp.completion.windows.documentation').win:get_win()
		_G.docs_buf = vim.api.nvim_win_get_buf(_G.docs_win)
		local config = vim.api.nvim_win_get_config(_G.docs_win)
		assert(config.width <= 72 and config.height <= 18 and config.border[1] == '╭')
	]])
  expect(
  "require('core.ui').renderer_loaded and #vim.api.nvim_buf_get_extmarks(_G.docs_buf, vim.api.nvim_get_namespaces()['render-markdown.nvim'], 0, -1, {}) > 0",
    "Markdown completion docs were not rendered")
  keys("<C-f>")
  expect("vim.fn.line('w0', _G.docs_win) > 1", "Ctrl-F did not scroll completion documentation")
  assert(lua("return vim.fn.mode()") == "i", "Scrolling docs left Insert mode")
  print("PASS: bounded, rendered completion documentation and in-place scrolling")
  keys("<CR>")
  expect("vim.snippet.active()", "Enter did not expand the native snippet")
  assert(lua("return vim.fn.getline(1)") == "-- import added", "Additional import edits were lost")
  assert(lua("return vim.fn.getline('$')") == "native(value)", "Snippet inserted incorrectly")
  keys("<C-n>")
  expect("not vim.snippet.active()", "Ctrl-N did not jump to final snippet position")
  keys("<Esc>")
  expect("vim.fn.mode() == 'n'", "Did not return to Normal mode")
  print("PASS: Blink manual completion, selection, native snippets, import edits and snippet jumping")

  lua([[
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { '-- first', '' })
		vim.api.nvim_win_set_cursor(0, { 2, 0 })
		require('blink.cmp.config').completion.menu.auto_show = true
	]])
  keys("ina")
  expect("require('blink.cmp').is_visible()", "Automatic LSP completion menu missing")
  assert(lua("return require('blink.cmp').get_selected_item() == nil"), "Completion was preselected")
  keys("<CR>")
  expect("vim.fn.line('$') == 3", "Enter without a selection did not insert a newline")
  assert(lua("return vim.fn.getline(2)") == "na", "Enter accepted an unselected completion")
  keys("<Esc>")
  expect("vim.fn.mode() == 'n'", "Did not leave Insert mode")
  print("PASS: automatic LSP completion and newline without accidental acceptance")

  lua([[
		_G.source_buf, _G.source_win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(0, { 2, 0 })
	]])
  keys("K")
  expect(
  "vim.b[_G.source_buf].lsp_floating_preview and vim.api.nvim_win_is_valid(vim.b[_G.source_buf].lsp_floating_preview)",
    "K did not open hover")
  lua([[
		_G.hover_win = vim.b[_G.source_buf].lsp_floating_preview
		local config = vim.api.nvim_win_get_config(_G.hover_win)
		assert(config.width <= 84 and config.height <= 20 and config.border[1] == '╭')
		assert(config.title[1][1] == ' Documentation ', 'Hover title should not include shortcut reminders')
		assert(vim.api.nvim_get_current_win() == _G.source_win, 'Hover stole focus')
	]])
  keys("K")
  expect("vim.api.nvim_get_current_win() == _G.hover_win", "Second K did not focus hover")
  expect("not require('smear_cursor').enabled", "Smear Cursor should pause in focused documentation")
  lua([[
		local buf = vim.api.nvim_win_get_buf(_G.hover_win)
		local marks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {details=true})
		for _, mark in ipairs(marks) do
			for _, chunk in ipairs(mark[4].virt_text or {}) do
				assert(not chunk[1]:find('[gx]', 1, true), 'Browser shortcut reminder should be absent')
			end
		end
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		assert(not table.concat(lines, '\n'):find('[gx]', 1, true), 'Browser shortcut reminder should not be in the Markdown')
		for row, line in ipairs(lines) do
			local col = line:find('View documents', 1, true)
			if col then vim.api.nvim_win_set_cursor(_G.hover_win, {row, col - 1}); break end
		end
		_G.ui_test_original_open = vim.ui.open
		vim.ui.open = function(url)
			_G.ui_test_opened_url = url
			return {wait = function() return {code = 0} end}
		end
	]])
  keys("gx")
  expect("_G.ui_test_opened_url == 'http://www.lua.org/manual/5.1/manual.html#pdf-require'",
    "gx did not retain the original browser URL")
  lua("vim.ui.open = _G.ui_test_original_open")
  print("PASS: clean documentation title, no browser-link reminders, and gx target preserved")
  keys("<C-f>")
  expect("vim.fn.line('w0', _G.hover_win) > 1", "Focused hover did not scroll")
  assert(lua("return not require('smear_cursor').enabled"), "Scrolling documentation re-enabled Smear Cursor")
  keys("q")
  expect("vim.api.nvim_get_current_win() == _G.source_win and not vim.api.nvim_win_is_valid(_G.hover_win)",
    "q did not return from hover")
  expect("require('smear_cursor').enabled", "Smear Cursor did not resume after closing documentation")
  print("PASS: native hover opens, focuses on second K, scrolls and closes")

  lua([[
		vim.api.nvim_buf_set_name(0, '/private/tmp/nvim-ui-mock.lua')
		local ns = vim.api.nvim_create_namespace('ui-test-diagnostics')
		vim.diagnostic.set(ns, 0, {
			{ lnum = 1, col = 0, severity = vim.diagnostic.severity.ERROR,
				message = 'Expected a string\nThe argument has type number.', source = 'MockLS', code = 'E101' },
			{ lnum = 0, col = 0, severity = vim.diagnostic.severity.WARN,
				message = 'Unused import', source = 'MockLS', code = 'W001' },
		})
		local config = vim.diagnostic.config()
		assert(config.virtual_text.current_line and not config.virtual_lines and not config.update_in_insert)
	]])
  keys("gl")
  expect(
  "vim.b[_G.source_buf].lsp_floating_preview and vim.api.nvim_win_is_valid(vim.b[_G.source_buf].lsp_floating_preview)",
    "gl did not open diagnostics")
  lua([[
		_G.diagnostic_win = vim.b[_G.source_buf].lsp_floating_preview
		assert(vim.api.nvim_win_get_config(_G.diagnostic_win).title[1][1] == ' Diagnostics ',
			'Diagnostics title should not include shortcut reminders')
		local buf = vim.api.nvim_win_get_buf(_G.diagnostic_win)
		local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
		assert(text:find('The argument has type number.', 1, true), 'Missing diagnostic detail')
		assert(text:find('MockLS · E101', 1, true), 'Missing diagnostic source/code')
	]])
  keys("gl")
  expect("vim.api.nvim_get_current_win() == _G.diagnostic_win", "Second gl did not focus diagnostics")
  expect("not require('smear_cursor').enabled", "Smear Cursor should pause in focused diagnostics")
  keys("<Esc>")
  expect("vim.api.nvim_get_current_win() == _G.source_win and not vim.api.nvim_win_is_valid(_G.diagnostic_win)",
    "Escape did not close diagnostics")
  print("PASS: quiet inline diagnostics, full details, source/code and focusable float")

  lua("vim.cmd.Problems()")
  expect("require('trouble').is_open({mode='diagnostics'}) and vim.bo.filetype == 'trouble'",
    "Problems panel did not open and focus")
  expect("table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), string.char(10)):find('Expected a string', 1, true)",
    "Problems did not list diagnostic")
  lua([[
		assert(not require('trouble.config').auto_preview, 'Problems should not move the source cursor automatically')
		require('trouble').close({mode='diagnostics'})
	]])
  expect("vim.api.nvim_get_current_win() == _G.source_win", "Problems did not return to source")
  lua("vim.cmd('Problems!')")
  expect("vim.bo.filetype == 'trouble'", "Buffer Problems panel did not open")
  lua("require('trouble').close({mode='diagnostics'})")
  print("PASS: workspace and buffer Problems panels load on demand")

  lua([[
		vim.api.nvim_set_current_win(_G.source_win)
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { '-- first', '' })
		vim.api.nvim_win_set_cursor(0, { 2, 0 })
	]])
  keys("inative(")
  expect("require('blink.cmp.signature.window').win:is_open()", "Automatic parameter hints did not open")
  lua([[
		local win = require('blink.cmp.signature.window').win
		assert(vim.api.nvim_win_get_height(win:get_win()) <= 4)
		local text = table.concat(vim.api.nvim_buf_get_lines(win:get_buf(), 0, -1, false), '\n')
		assert(text:find('native(value: string)', 1, true))
		assert(not text:find('overwhelm', 1, true), 'Long signature documentation should stay hidden')
	]])
  keys("<Esc>")
  expect("vim.fn.mode() == 'n'", "Could not leave parameter hint")
  print("PASS: automatic compact parameter hints")

  lua([[
		vim.lsp.enable('gopls', false)
		vim.cmd.enew({ bang = true })
		vim.bo.buftype = 'nofile'
		vim.bo.filetype = 'go'
		require('blink.cmp.config').completion.menu.auto_show = false
	]])
  keys("iie<C-n>")
  expect("vim.snippet.active()", "Go ie shortcut did not expand")
  assert(lua("return vim.fn.getline(1)") == "if err != nil {", "Go snippet left trigger text behind")
  keys("<C-n>")
  expect("not vim.snippet.active()", "Could not exit Go snippet")
  keys("<Esc>")
  expect("vim.fn.mode() == 'n'", "Did not leave Go snippet")
  print("PASS: Go error-handling snippet uses vim.snippet")

  lua([[
		vim.cmd.enew({ bang = true })
		vim.bo.buftype = 'nofile'
		vim.bo.autocomplete = false
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { '{}' })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
	]])
  keys("a")
  expect("vim.fn.mode() == 'i' and vim.api.nvim_win_get_cursor(0)[2] == 1",
    "Could not position Insert cursor between brackets")
  keys("<CR>")
  expect("vim.fn.line('$') == 3", "Enter did not preserve bracket pairing")
  assert(lua("return vim.fn.getline(1)") == "{" and lua("return vim.fn.getline(3)") == "}")
  print("PASS: Enter fallback retains automatic bracket pairing")
  local messages = lua("return vim.api.nvim_exec2('messages', {output=true}).output")
  assert(type(messages) == "string", "Expected message history as a string")
  assert(not messages:find('stack traceback', 1, true), messages)
end, debug.traceback)

if not ok then
  local _, messages = pcall(lua, "return vim.api.nvim_exec2('messages', {output=true}).output")
  io.stderr:write(tostring(messages) .. "\n")
  local _, state = pcall(lua, [[return vim.inspect({
		mode=vim.fn.mode(), line=vim.fn.getline('.'), lines=vim.api.nvim_buf_get_lines(0,0,-1,false), cursor=vim.api.nvim_win_get_cursor(0), requests=_G.ui_test_requests,
		mapping=vim.fn.maparg('<C-Space>', 'i', false, true),
		blink=package.loaded['blink.cmp.completion'] ~= nil,
		context=package.loaded['blink.cmp.completion.trigger'] and require('blink.cmp.completion.trigger').context,
	})]])
  io.stderr:write(tostring(state) .. "\n")
end
pcall(rpc, "nvim_command", "qa!")
vim.fn.jobstop(child)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("All completion UI checks passed")
vim.cmd("qa!")
