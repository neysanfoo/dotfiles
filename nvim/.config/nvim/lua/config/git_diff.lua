local M = {}

local scopes = { "all", "unstaged", "staged" }
local labels = { all = "All vs HEAD + new files", unstaged = "Unstaged + new files", staged = "Staged" }
local namespace = vim.api.nvim_create_namespace("git_diff_review")
local generation = 0

local function lines(text)
  local result = vim.split(text, "\n", { plain = true })
  if result[#result] == "" then
    table.remove(result)
  end
  return result
end

local function parse_patch(file, patch)
  file.patch, file.changes, file.added, file.removed = lines(patch), {}, 0, 0
  local old_line, new_line, new_last
  for index, line in ipairs(file.patch) do
    local old, new, count = line:match("^@@ %-(%d+),?%d* %+(%d+),?(%d*) @@")
    if line:match("^diff %-%-git ") then
      old_line, new_line = nil, nil
    elseif old then
      old_line, new_line = tonumber(old), tonumber(new)
      new_last = new_line + (tonumber(count) or 1) - 1
    elseif old_line then
      local sign = line:sub(1, 1)
      if sign == "+" or sign == "-" then
        table.insert(file.changes, {
          file = file,
          sign = sign,
          text = line:sub(2),
          -- EOF deletions point to the nearest surviving line, without loading files.
          lnum = math.max(sign == "-" and math.min(new_line, new_last) or new_line, 1),
          diff_lnum = sign == "+" and new_line or old_line,
          preview_lnum = index,
        })
        if sign == "+" then
          file.added, new_line = file.added + 1, new_line + 1
        else
          file.removed, old_line = file.removed + 1, old_line + 1
        end
      elseif sign == " " then
        old_line, new_line = old_line + 1, new_line + 1
      end
    end
  end
  -- Binary files, empty files, renames and mode changes still need a review entry.
  if #file.changes == 0 then
    local summary = patch:find("Binary files", 1, true) and "Binary file changed" or "File metadata changed"
    table.insert(
      file.changes,
      { file = file, sign = "~", text = summary, lnum = 1, diff_lnum = 1, preview_lnum = 1 }
    )
  end
end

local function parse_diff(output)
  if output == "" then
    return {}
  end
  -- Raw NUL-delimited paths avoid parsing Git's quoted patch filenames.
  local boundary = assert(output:find("\0\0", 1, true), "Missing Git diff metadata")
  local fields = vim.split(output:sub(1, boundary - 1), "\0", { plain = true })
  local files, index = {}, 1
  while index <= #fields do
    local status = assert(fields[index]:match(" (%u)%d*$"), "Invalid Git diff status")
    local file = { status = status, path = fields[index + 1] }
    index = index + 2
    if status == "R" or status == "C" then
      file.old_path, file.path = file.path, fields[index]
      index = index + 1
    end
    table.insert(files, file)
  end
  local patches = vim.split(output:sub(boundary + 2), "\ndiff --git ", { plain = true })
  local patch_index = 1
  for _, file in ipairs(files) do
    -- A type change (e.g. file to symlink) produces a deletion and an addition patch.
    local parts = {}
    for _ = 1, file.status == "T" and 2 or 1 do
      assert(patches[patch_index], "Cannot match Git patches to files (check for unresolved conflicts)")
      table.insert(parts, (patch_index == 1 and "" or "diff --git ") .. patches[patch_index])
      patch_index = patch_index + 1
    end
    parse_patch(file, table.concat(parts, "\n"))
  end
  assert(patch_index == #patches + 1, "Cannot match Git patches to files (check for unresolved conflicts)")
  return files
end

-- Git runs asynchronously; all Neovim API work resumes on the main loop.
function M.collect(cwd, scope, callback)
  local thread = coroutine.create(function()
    local function git(args, allow_difference)
      local command = { "git", "--no-pager", "-C", cwd }
      vim.list_extend(command, args)
      local result = coroutine.yield(command)
      if result.code ~= 0 and not (allow_difference and result.code == 1) then
        error(vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr) or "Git command failed", 0)
      end
      return result.stdout or ""
    end
    cwd = git({ "rev-parse", "--show-toplevel" }):gsub("\n$", "")
    local args = {
      "diff",
      "--no-color",
      "--no-ext-diff",
      "--no-textconv",
      "--no-relative",
      "--src-prefix=a/",
      "--dst-prefix=b/",
      "--unified=3",
      "--inter-hunk-context=0",
      "--output-indicator-new=+",
      "--output-indicator-old=-",
      "--output-indicator-context= ",
      "--submodule=short",
      "--ignore-submodules=none",
      "--no-renames",
      "--no-exit-code",
    }
    local tracked = vim.list_extend(vim.deepcopy(args), { "--raw", "-z", "--patch", "--find-renames" })
    if scope == "all" then
      -- An empty tree also supports repositories with no first commit (including SHA-256 repos).
      local head = git({ "rev-parse", "--verify", "--quiet", "HEAD" }, true):gsub("\n$", "")
      table.insert(
        tracked,
        head ~= "" and head or git({ "hash-object", "-t", "tree", "--stdin" }):gsub("\n$", "")
      )
    elseif scope == "staged" then
      table.insert(tracked, "--cached")
    end
    table.insert(tracked, "--")
    local files = parse_diff(git(tracked))
    if scope ~= "staged" then
      for _, path in
      ipairs(
        vim.split(
          git({ "ls-files", "--others", "--exclude-standard", "-z" }),
          "\0",
          { plain = true, trimempty = true }
        )
      )
      do
        local file = { path = path, status = "?" }
        local untracked = vim.list_extend(vim.deepcopy(args), { "--no-index", "--", "/dev/null", path })
        parse_patch(file, git(untracked, true))
        table.insert(files, file)
      end
    end
    return { root = cwd, scope = scope, files = files }
  end)
  local function resume(...)
    local ok, value = coroutine.resume(thread, ...)
    if not ok then
      callback(nil, value)
    elseif coroutine.status(thread) == "dead" then
      callback(value)
    else
      local launched, err = pcall(
        vim.system,
        value,
        { stdin = "", timeout = 15000, env = { GIT_OPTIONAL_LOCKS = "0" } },
        function(result)
          vim.schedule(function()
            resume(result)
          end)
        end
      )
      if not launched then
        callback(nil, err)
      end
    end
  end
  resume()
end

local function entries(data, group_files)
  local result = {}
  for _, file in ipairs(data.files) do
    local changes = group_files and { file.changes[1] } or file.changes
    local path = file.old_path and (file.old_path .. " -> " .. file.path) or file.path
    for _, change in ipairs(changes) do
      local text = group_files and string.format("[%s] +%d -%d", file.status, file.added, file.removed)
          or (change.sign .. " " .. change.text)
      local searchable = { path, text }
      if group_files then
        for _, item in ipairs(file.changes) do
          table.insert(searchable, item.text)
        end
      end
      table.insert(result, {
        value = change,
        filename = data.root .. "/" .. file.path,
        lnum = change.lnum,
        col = 1,
        text = text,
        ordinal = table.concat(searchable, " "),
        display = function()
          local display = string.format(
            "%s:%d  %s",
            vim.fn.strtrans(path),
            change.diff_lnum,
            vim.fn.strtrans((text:gsub("\t", "  ")))
          )
          local highlight = change.sign == "+" and "DiffAdd"
              or change.sign == "-" and "DiffDelete"
              or "Comment"
          return display,
              { { { #vim.fn.strtrans(path) + #tostring(change.diff_lnum) + 3, #display }, highlight } }
        end,
      })
    end
  end
  return result
end

local function prepare_entry(entry, data)
  local file = entry.value.file
  -- Staged coordinates refer to the index; deleted files have no working-tree target.
  -- Open a persistent read-only patch so Enter and quickfix keep accurate locations.
  if data.scope == "staged" or file.status == "T" or vim.fn.filereadable(entry.filename) == 0 then
    if not file.bufnr or not vim.api.nvim_buf_is_valid(file.bufnr) then
      file.bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(
        file.bufnr,
        string.format("git-review://%d/%s/%s", file.bufnr, data.scope, file.path)
      )
      vim.api.nvim_buf_set_lines(file.bufnr, 0, -1, false, file.patch)
      vim.bo[file.bufnr].filetype = "diff"
      vim.bo[file.bufnr].bufhidden = "hide"
      vim.bo[file.bufnr].swapfile = false
      vim.bo[file.bufnr].modifiable = false
      vim.bo[file.bufnr].readonly = true
    end
    entry.bufnr, entry.lnum = file.bufnr, entry.value.preview_lnum
    entry.filename = vim.api.nvim_buf_get_name(file.bufnr)
  end
end

function M.open(opts)
  opts = opts or {}
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local finders = require("telescope.finders")
  local scope_index = vim.fn.index(scopes, opts.scope or "all") + 1
  if scope_index == 0 then
    vim.notify("Git diff scope must be all, unstaged, or staged", vim.log.levels.ERROR)
    return
  end
  local group_files, data, loading = opts.group_files == true, nil, false
  local cwd = opts.cwd or vim.fn.getcwd()
  -- Telescope stores this at runtime but omits it from its Picker annotation.
  ---@class GitDiffPicker: Picker
  ---@field prompt_title string
  local picker
  local function finder()
    return finders.new_table({
      results = data and entries(data, group_files) or {},
      entry_maker = function(entry)
        return entry
      end,
    })
  end
  local function title(suffix)
    picker.prompt_title = "Git diff | " .. labels[scopes[scope_index]] .. (suffix or "")
    picker.layout.prompt.border:change_title(picker.prompt_title)
    local count = data and #data.files or 0
    picker.layout.results.border:change_title(
      string.format("%s | %d files | C-f view  C-g scope  C-r refresh", group_files and "Files" or "Lines", count)
    )
  end
  local function refresh()
    if loading or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
      return
    end
    loading = true
    title(" | Loading…")
    M.collect(cwd, scopes[scope_index], function(result, err)
      if not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
        return
      end
      loading = false
      if err then
        title(" | Error")
        vim.notify("Git diff: " .. err, vim.log.levels.ERROR)
        return
      end
      data = result
      generation = generation + 1
      title(#data.files == 0 and " | No changes" or nil)
      picker:refresh(finder(), { reset_prompt = false })
    end)
  end
  local previewer = require("telescope.previewers").new_buffer_previewer({
    title = "Diff | Enter open  Tab mark  C-q quickfix",
    get_buffer_by_name = function(_, entry)
      return generation .. ":" .. entry.value.file.path
    end,
    define_preview = function(self, entry)
      local bufnr, winid = self.state.bufnr, self.state.winid
      if not self.state.bufname then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, entry.value.file.patch)
        require("telescope.previewers.utils").highlighter(bufnr, "diff")
      end
      vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
      vim.api.nvim_buf_set_extmark(
        bufnr,
        namespace,
        entry.value.preview_lnum - 1,
        0,
        { line_hl_group = "TelescopePreviewLine" }
      )
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
          vim.api.nvim_win_set_cursor(winid, { entry.value.preview_lnum, 0 })
          vim.api.nvim_win_call(winid, function()
            vim.cmd("normal! zz")
          end)
        end
      end)
    end,
  })
  local picker_opts = vim.tbl_deep_extend("force", {
    layout_strategy = "flex",
    layout_config = {
      width = 0.95,
      height = 0.9,
      horizontal = { preview_width = 0.55 },
      vertical = { preview_height = 0.5 },
    },
    sorting_strategy = "ascending",
  }, opts)
  picker = require("telescope.pickers").new(picker_opts, {
    prompt_title = "Git diff",
    finder = finder(),
    previewer = previewer,
    sorter = require("telescope.config").values.generic_sorter(picker_opts),
    -- Changed files such as .gitignore and vendor code must not be silently hidden.
    file_ignore_patterns = {},
    attach_mappings = function(prompt_bufnr, map)
      for _, action in ipairs({ "select_default", "select_horizontal", "select_vertical", "select_tab" }) do
        actions[action]:enhance({
          pre = function()
            local entry = action_state.get_selected_entry()
            if entry and data then
              prepare_entry(entry, data)
            end
          end,
        })
      end
      for _, mode in ipairs({ "i", "n" }) do
        map(mode, "<C-q>", function()
          if loading or not data then
            return
          end
          local selected = picker:get_multi_selection()
          if #selected > 0 then
            for _, entry in ipairs(selected) do
              prepare_entry(entry, data)
            end
          else
            for entry in picker.manager:iter() do
              prepare_entry(entry, data)
            end
          end
          actions.smart_send_to_qflist(prompt_bufnr)
          actions.open_qflist(prompt_bufnr)
        end)
        map(mode, "<C-f>", function()
          group_files = not group_files
          title()
          picker:refresh(finder(), { reset_prompt = false })
        end)
        map(mode, "<C-g>", function()
          if loading then
            return
          end
          scope_index = scope_index % #scopes + 1
          data = nil
          picker:refresh(finder(), { reset_prompt = false })
          refresh()
        end)
        map(mode, "<C-r>", refresh)
      end
      vim.schedule(refresh)
      return true
    end,
  }) --[[@as GitDiffPicker]]
  picker:find()
  return picker
end

return M
