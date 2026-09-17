-- nvim --headless -u NONE -i NONE -l tests/comment_keymaps_spec.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.swapfile = false
require("config.keymaps")

for _, lhs in ipairs({ "gcc", "gco", "gcO", "gcA", "gb", "gbc" }) do
  assert(vim.fn.maparg(lhs, "n") == "", lhs .. " is still mapped")
end
assert(vim.fn.maparg("gb", "x") == "")
for _, mode in ipairs({ "n", "x", "o" }) do
  assert(vim.fn.maparg("gc", mode) ~= "", "Built-in gc was removed in mode " .. mode)
end

local function reset()
  vim.cmd.enew({ bang = true })
  vim.bo.commentstring = "-- %s"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second", "third" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

local function keys(sequence)
  vim.api.nvim_feedkeys(vim.keycode(sequence), "xt", false)
end

for _, shortcut in ipairs({ "<Space>/", "<D-/>" }) do
  reset()
  keys(shortcut)
  assert(vim.fn.getline(1) == "-- first", "Line toggle failed: " .. shortcut)
  keys(shortcut)
  assert(vim.fn.getline(1) == "first", "Line uncomment failed: " .. shortcut)
  keys("2" .. shortcut)
  assert(vim.fn.getline(2) == "-- second", "Count was lost: " .. shortcut)
  reset()
  keys("Vj" .. shortcut)
  assert(vim.fn.getline(1) == "-- first" and vim.fn.getline(2) == "-- second", "Visual toggle failed")
end
reset()
keys("<Space>/j.")
assert(vim.fn.getline(2) == "-- second", "Dot-repeat was lost")
reset()
keys("a<D-/><Esc>")
assert(vim.fn.getline(1) == "-- first", "Insert-mode Cmd+/ failed")

-- Reload also clears shortcuts left over from the previous configuration.
vim.keymap.set("n", "gco", "<Nop>")
vim.keymap.set("x", "gb", "<Nop>")
dofile("lua/config/keymaps.lua")
assert(vim.fn.maparg("gco", "n") == "" and vim.fn.maparg("gb", "x") == "")
print("PASS: removed shortcuts; normal/visual/insert toggles, counts, dot-repeat and reload")
vim.cmd("qa!")
