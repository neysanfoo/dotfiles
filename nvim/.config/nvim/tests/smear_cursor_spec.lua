-- nvim --headless -u NONE -i NONE -l tests/smear_cursor_spec.lua
-- Real plugin + embedded UI, without language servers or the rest of the config.
local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-n", "-u", "NONE", "-i", "NONE" },
  { rpc = true })
local function rpc(method, ...) return vim.rpcrequest(child, method, ...) end
local function lua(code) return rpc("nvim_exec_lua", code, {}) end
local function expect(expression, message)
  assert(vim.wait(2000, function() return lua("return not not (" .. expression .. ")") == true end, 5), message)
end
local function wait(ms) vim.wait(ms, function() return false end, 5) end

local ok, err = xpcall(function()
  rpc("nvim_ui_attach", 100, 35, { rgb = true })
  lua([[
		vim.o.messagesopt = 'wait:0,history:500'
		vim.o.termguicolors = true
		vim.opt.runtimepath:prepend(vim.fn.getcwd())
		vim.cmd.packadd('smear-cursor.nvim')
		require('plugins.smear-cursor')()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn['repeat']({'Some documentation or code to navigate.'}, 100))
		vim.bo.filetype = 'markdown'
		_G.source_win = vim.api.nvim_get_current_win()
		_G.doc_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(_G.doc_buf, 0, -1, false, vim.fn['repeat']({'Documentation line to navigate.'}, 100))
		vim.bo[_G.doc_buf].filetype = 'markdown'
		_G.open_docs = function(focus)
			return vim.api.nvim_open_win(_G.doc_buf, focus, {
				relative = 'editor', row = 4, col = 20, width = 50, height = 12,
				border = 'rounded', style = 'minimal',
			})
		end
		_G.trails = function()
			local count = 0
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local config = vim.api.nvim_win_get_config(win)
				if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'smear-cursor' and not config.hide then
					assert(config.zindex < 50, 'Code trails should remain underneath popups')
					count = count + 1
				end
			end
			return count
		end
	]])
  expect("require('smear_cursor').enabled", "Ordinary Markdown should still animate")
  wait(30)
  rpc("nvim_input", "15j20l")
  expect("_G.trails() > 0", "Smear Cursor should actually draw in a normal editor window")
  -- Enter a popup while an animation is still running, not just from rest.
  lua("_G.doc_win = _G.open_docs(true)")
  expect("not require('smear_cursor').enabled", "Focused popup should pause Smear Cursor")
  expect("_G.trails() == 0", "Old code-buffer trail should clear on popup entry")
  for _, motion in ipairs({ "j", "10j", "<C-d>", "5k", "<C-u>", "G", "gg" }) do
    rpc("nvim_input", motion)
    for _ = 1, 8 do
      wait(10)
      assert(lua("return _G.trails() == 0 and not require('smear_cursor').enabled"),
        "Popup movement/scrolling should never paint a cursor trail: " .. motion)
    end
  end
  print("PASS: real code animation; focused popup movement and scrolling have no trails")
  lua("vim.api.nvim_win_close(_G.doc_win, true)")
  expect("require('smear_cursor').enabled", "Closing a popup should resume the effect")
  lua("_G.doc_win = _G.open_docs(false)")
  assert(lua("return require('smear_cursor').enabled"), "Unfocused previews should not disable code animation")
  lua("vim.api.nvim_set_current_win(_G.doc_win); vim.cmd.SmearCursorToggle()")
  lua("vim.api.nvim_win_close(_G.doc_win, true)")
  assert(lua("return not require('smear_cursor').enabled"), "Disabling inside a popup should stay disabled on return")
  lua("_G.doc_win = _G.open_docs(true); vim.cmd.SmearCursorToggle()")
  assert(lua("return not require('smear_cursor').enabled"), "Enabling inside a popup should wait until returning to code")
  lua("vim.api.nvim_win_close(_G.doc_win, true)")
  expect("require('smear_cursor').enabled", "User preference should resume after leaving the popup")
  for _ = 1, 10 do
    lua("_G.doc_win = _G.open_docs(true); vim.api.nvim_win_close(_G.doc_win, true)")
  end
  wait(100)
  assert(lua("return require('smear_cursor').enabled and _G.trails() == 0"),
    "Rapid popup switching left a trail or lost enabled state")
  print("PASS: unfocused previews, persistent toggle preference, and rapid popup switching")
end, debug.traceback)
pcall(rpc, "nvim_command", "qa!")
vim.fn.jobstop(child)
if not ok then error(err) end
print("All Smear Cursor checks passed")
