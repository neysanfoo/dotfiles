-- Run from this config: nvim --headless -u NONE -i NONE -l tests/git_diff_spec.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local telescope_dev = vim.fn.expand("~/src/neysan.telescope.nvim")
if vim.uv.fs_stat(telescope_dev) then
  vim.opt.runtimepath:append(telescope_dev)
else
  vim.cmd.packadd("telescope.nvim")
end
for _, name in ipairs({ "plenary.nvim", "telescope-fzf-native.nvim", "project.nvim" }) do
  vim.cmd.packadd(name)
end
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
vim.env.GIT_CONFIG_NOSYSTEM = "1"
vim.o.swapfile = false
vim.o.hidden = true
vim.o.columns = 180
vim.o.lines = 55

local review = require("config.git_diff")
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, "p")

local function git(root, ...)
  local command = { "git", "-C", root }
  vim.list_extend(command, { ... })
  local result = vim.system(command, { text = true }):wait()
  assert(result.code == 0, result.stderr)
  return result.stdout
end

local function write(root, path, content)
  vim.fn.mkdir(vim.fs.dirname(root .. "/" .. path), "p")
  vim.fn.writefile(content, root .. "/" .. path)
end

local function init(name)
  local root = temp .. "/" .. name
  vim.fn.mkdir(root, "p")
  git(root, "init", "-q")
  git(root, "config", "user.name", "Diff Test")
  git(root, "config", "user.email", "diff@example.invalid")
  return vim.uv.fs_realpath(root)
end

local function collect(root, scope)
  local done, data, err
  review.collect(root, scope or "all", function(result, failure)
    done, data, err = true, result, failure
  end)
  assert(
    vim.wait(15000, function()
      return done
    end, 10),
    "Diff collection timed out"
  )
  assert(not err, err)
  return data
end

local function files_by_path(data)
  local result = {}
  for _, file in ipairs(data.files) do
    result[file.path] = file
  end
  return result
end

local function has(file, text, sign)
  assert(file, "Missing file")
  for _, change in ipairs(file.changes) do
    if change.text == text and (not sign or change.sign == sign) then
      return change
    end
  end
end

local function wait_for(predicate, message)
  assert(vim.wait(10000, predicate, 10), message)
end

local function picker_ready(picker)
  wait_for(function()
    return picker.manager and picker.manager:num_results() > 0 and not picker.prompt_title:find("Loading", 1, true)
  end, "Picker did not load")
end

local function filter(picker, prompt, predicate)
  picker:set_prompt(prompt)
  wait_for(function()
    if not picker.manager or picker.manager:num_results() == 0 then
      return false
    end
    for entry in picker.manager:iter() do
      if not predicate(entry) then
        return false
      end
    end
    return true
  end, "Filter did not match: " .. prompt)
end

local function press(picker, key, mode)
  assert(vim.api.nvim_get_current_buf() == picker.prompt_bufnr, "Picker prompt is not focused")
  local mapping = vim.fn.maparg(key, mode or "i", false, true)
  assert(mapping.callback, "Missing mapping: " .. key)
  mapping.callback()
end

local ok, err = xpcall(function()
  local root = init("review")
  local odd_path = 'space ü "quote"\tline\nfile.txt'
  write(root, "mixed.txt", { "anchor", "original", "tail" })
  write(root, "deleted.txt", { "deleted needle", "last deleted" })
  write(root, "rename-old.txt", { "rename contents" })
  write(root, "eof.txt", { "survivor", "remove at EOF", "remove last" })
  write(root, ".gitignore", { "ignored/" })
  write(root, "vendor/change.txt", { "old vendor" })
  write(root, odd_path, { "old odd" })
  write(root, "binary.dat", { "old\nbytes" }) -- writefile encodes embedded newlines as NUL.
  write(root, "mode.sh", { "exit 0" })
  write(root, "type-change.txt", { "regular file" })
  local many = {}
  for i = 1, 30 do
    many[i] = "line " .. i
  end
  write(root, "hunks.txt", many)
  git(root, "add", ".")
  git(root, "commit", "-qm", "base")
  write(root, "mixed.txt", { "anchor", "staged needle", "tail" })
  git(root, "add", "mixed.txt")
  write(root, "mixed.txt", { "inserted", "anchor", "working needle", "tail" })
  assert(vim.uv.fs_unlink(root .. "/deleted.txt"))
  git(root, "mv", "rename-old.txt", "rename-new.txt")
  write(root, "eof.txt", { "survivor" })
  write(root, "vendor/change.txt", { "vendor needle" })
  write(root, ".gitignore", { "ignored/", "*.log" })
  write(root, odd_path, { "odd needle" })
  write(root, "binary.dat", { "new\nbytes" })
  assert(vim.uv.fs_chmod(root .. "/mode.sh", 493))
  assert(vim.uv.fs_unlink(root .. "/type-change.txt"))
  assert(vim.uv.fs_symlink("mixed.txt", root .. "/type-change.txt"))
  many[2], many[27] = "first hunk needle", "second hunk needle"
  write(root, "hunks.txt", many)
  write(root, "new.txt", { "new needle" })
  write(root, "empty.txt", {})
  write(root, "ignored/nope.txt", { "should not appear" })
  local before = git(root, "status", "--porcelain=v1")
  local data = collect(root .. "/vendor")
  assert(data.root == root)
  local files = files_by_path(data)
  assert(has(files["mixed.txt"], "working needle", "+").lnum == 3)
  assert(has(files["mixed.txt"], "original", "-"))
  assert(not has(files["mixed.txt"], "staged needle"))
  assert(has(files["hunks.txt"], "first hunk needle").lnum == 2)
  assert(has(files["hunks.txt"], "second hunk needle").lnum == 27)
  assert(files["deleted.txt"].removed == 2)
  assert(has(files["eof.txt"], "remove last", "-").lnum == 1)
  assert(files["rename-new.txt"].old_path == "rename-old.txt")
  assert(files["binary.dat"].changes[1].text == "Binary file changed")
  assert(files["mode.sh"].added == 0 and #files["mode.sh"].changes == 1)
  assert(files["type-change.txt"].status == "T")
  assert(has(files["type-change.txt"], "mixed.txt", "+"))
  assert(files["empty.txt"] and files["empty.txt"].status == "?")
  assert(has(files[odd_path], "odd needle", "+"))
  assert(files[".gitignore"] and files["vendor/change.txt"])
  assert(not files["ignored/nope.txt"])
  local staged = files_by_path(collect(root, "staged"))
  assert(has(staged["mixed.txt"], "staged needle", "+"))
  assert(not staged["new.txt"] and not staged["deleted.txt"])
  local unstaged = files_by_path(collect(root, "unstaged"))
  assert(has(unstaged["mixed.txt"], "staged needle", "-"))
  assert(has(unstaged["mixed.txt"], "working needle", "+"))
  assert(not unstaged["rename-new.txt"])
  assert(git(root, "status", "--porcelain=v1") == before, "Review changed Git state")
  print("PASS: scopes, hunks, paths, renames, binary/empty/mode changes, ignored files, read-only Git")

  local unborn = init("unborn")
  write(unborn, "staged.txt", { "initial staged" })
  git(unborn, "add", ".")
  write(unborn, "staged.txt", { "initial working" })
  write(unborn, "new.txt", { "initial new" })
  local first = files_by_path(collect(unborn))
  assert(has(first["staged.txt"], "initial working", "+") and first["new.txt"])
  assert(has(files_by_path(collect(unborn, "staged"))["staged.txt"], "initial staged", "+"))
  git(unborn, "add", ".")
  git(unborn, "commit", "-qm", "initial")
  assert(#collect(unborn).files == 0)
  local completed, nonrepo_error
  review.collect(temp, "all", function(_, failure)
    completed, nonrepo_error = true, failure
  end)
  wait_for(function()
    return completed
  end, "Non-repository check timed out")
  assert(type(nonrepo_error) == "string", "Expected a non-repository error")
  assert(nonrepo_error:find("not a git repository", 1, true))
  print("PASS: first commit, clean repository, non-repository error")

  require("plugins.telescope")()
  require("telescope.config").values.history.path = temp .. "/telescope_history"
  assert(vim.fn.maparg("<leader>gf", "n") ~= "", "Review keybinding missing")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local picker = assert(review.open({ cwd = root }))
  picker_ready(picker)
  local total = picker.manager:num_results()
  filter(picker, "mixed working needle", function(entry)
    return entry.value.text == "working needle"
  end)
  wait_for(function()
    local state = picker.previewer.state
    return state
        and vim.api.nvim_buf_is_valid(state.bufnr)
        and vim.tbl_contains(vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false), "+working needle")
  end, "Diff preview is missing selected text")
  press(picker, "<C-q>")
  local qf = vim.fn.getqflist()
  assert(#qf == 1 and qf[1].lnum == 3 and qf[1].text == "+ working needle")
  assert(vim.bo.filetype == "qf")
  vim.cmd("cclose")

  picker = assert(review.open({ cwd = root }))
  picker_ready(picker)
  filter(picker, "needle", function(entry)
    return entry.value.text:find("needle", 1, true) ~= nil
  end)
  actions.toggle_selection(picker.prompt_bufnr)
  press(picker, "<C-q>", "n")
  assert(#vim.fn.getqflist() == 1, "Marks should override matching results")
  vim.cmd("cclose")

  picker = assert(review.open({ cwd = root }))
  picker_ready(picker)
  press(picker, "<C-f>")
  wait_for(function()
    return picker.manager:num_results() == #data.files
  end, "File grouping failed")
  assert(picker.manager:num_results() < total)
  filter(picker, "working needle", function(entry)
    return entry.value.file.path == "mixed.txt"
  end)
  assert(picker.manager:num_results() == 1)
  press(picker, "<C-g>")
  picker_ready(picker)
  assert(picker.prompt_title:find("Unstaged", 1, true))
  assert(picker:_get_prompt() == "working needle")
  actions.close(picker.prompt_bufnr)

  picker = assert(review.open({ cwd = root, scope = "staged" }))
  picker_ready(picker)
  filter(picker, "staged needle", function(entry)
    return entry.value.text == "staged needle"
  end)
  press(picker, "<C-q>")
  qf = vim.fn.getqflist()
  assert(#qf == 1 and not vim.bo[qf[1].bufnr].modifiable)
  assert(vim.api.nvim_buf_get_lines(qf[1].bufnr, qf[1].lnum - 1, qf[1].lnum, false)[1] == "+staged needle")
  vim.cmd("cclose")
  vim.cmd("cfirst")
  assert(vim.bo.filetype == "diff")

  picker = assert(review.open({ cwd = root }))
  picker_ready(picker)
  filter(picker, "deleted needle", function(entry)
    return entry.value.text == "deleted needle"
  end)
  actions.select_default(picker.prompt_bufnr)
  assert(vim.bo.filetype == "diff" and not vim.bo.modifiable)
  assert(vim.api.nvim_get_current_line() == "-deleted needle")
  assert(not vim.uv.fs_stat(root .. "/deleted.txt"))

  picker = assert(review.open({ cwd = root }))
  picker_ready(picker)
  filter(picker, "remove last", function(entry)
    return entry.value.text == "remove last"
  end)
  actions.select_default(picker.prompt_bufnr)
  assert(vim.api.nvim_buf_get_name(0) == root .. "/eof.txt")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 1)

  picker = assert(review.open({ cwd = root }))
  picker_ready(picker)
  filter(picker, "new needle", function(entry)
    return entry.value.text == "new needle"
  end)
  write(root, "new.txt", { "new needle", "refresh addition" })
  press(picker, "<C-r>")
  picker_ready(picker)
  assert(picker:_get_prompt() == "new needle")
  filter(picker, "refresh addition", function(entry)
    return entry.value.text == "refresh addition"
  end)
  local selected = assert(action_state.get_selected_entry(), "Expected the refreshed entry to be selected")
  assert(selected.value.text == "refresh addition")
  actions.close(picker.prompt_bufnr)
  picker = assert(review.open({ cwd = root }))
  actions.close(picker.prompt_bufnr)
  vim.wait(50, function()
    return false
  end, 10)
  assert(vim.v.errmsg == "", vim.v.errmsg)
  print(
    "PASS: actual Telescope mappings, content search, previews, quickfix, marks, file view, scope switch, refresh, navigation"
  )
end, debug.traceback)

vim.fn.delete(temp, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("All Git diff review checks passed")
vim.cmd("qa!")
