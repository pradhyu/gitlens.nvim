-- gitlens.nvim: Show inline git blame info for current line
local M = {}

-- Plugin configuration with defaults
M.config = {
  -- How long to show the virtual text (in ms)
  show_time = 3000,
  -- Virtual text highlight group
  hl_group = "GitLensBlame",
  -- Format string for the blame message
  -- Available placeholders:
  -- %a - author name
  -- %d - date/time
  -- %m - commit message
  -- %h - short commit hash
  format = " %a | %d | %m (%h)",
  -- Date format (passed to os.date)
  date_format = "%Y-%m-%d %H:%M",
  -- Maximum length of commit message
  max_msg_len = 50,
  -- Whether to show virtual text automatically when the cursor stays on a line
  auto_show = true,
  -- Delay before showing blame info automatically (in ms)
  auto_show_delay = 1000,
  -- Git command timeout (in ms)
  git_cmd_timeout = 5000,
  -- Whether to show diff information in a floating window
  show_diff = true,
  -- Width of the diff floating window (0 for auto-sizing)
  diff_window_width = 0,
  -- Height of the diff floating window (0 for auto-sizing)
  diff_window_height = 0,
  -- Border style for the diff floating window
  diff_window_border = "single",
}

-- Store timer references
local auto_timer = nil
local clear_timer = nil

-- Store namespace for virtual text
local ns_id = nil

-- Function to get git directory
local function get_git_dir()
  local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
  if not handle then
    return nil
  end
  
  local git_dir = handle:read("*a"):gsub("%s+$", "")
  handle:close()
  
  if git_dir == "" then
    return nil
  end
  
  return git_dir
end

-- Format the blame info according to user config
local function format_blame_info(info)
  if not info then return "" end
  
  local msg = info.message or ""
  if #msg > M.config.max_msg_len then
    msg = string.sub(msg, 1, M.config.max_msg_len) .. "..."
  end
  
  local formatted = M.config.format
  formatted = formatted:gsub("%%a", info.author or "Unknown")
  formatted = formatted:gsub("%%d", info.date or "")
  formatted = formatted:gsub("%%m", msg)
  formatted = formatted:gsub("%%h", info.hash and string.sub(info.hash, 1, 7) or "")
  
  return formatted
end

-- Run git blame for the current line
local function get_blame_info(file_path, line_num)
  -- Path is relative to git root
  local handle = io.popen(string.format(
    "git blame -L %d,%d --porcelain %s 2>/dev/null", 
    line_num, line_num, file_path
  ))
  
  if not handle then return nil end
  
  local blame_output = handle:read("*a")
  handle:close()
  
  if blame_output == "" then return nil end
  
  -- Parse the git blame output
  local hash = blame_output:match("^(%x+)")
  local author = blame_output:match("author ([^\n]+)")
  local time = blame_output:match("author%-time (%d+)")
  local message = blame_output:match("summary ([^\n]+)")
  
  -- Format date
  local date = ""
  if time then
    date = os.date(M.config.date_format, tonumber(time))
  end
  
  return {
    hash = hash,
    author = author,
    date = date,
    message = message
  }
end

-- Show blame info as virtual text
local function show_blame_info()
  -- Clear any existing timer
  if auto_timer then
    vim.loop.timer_stop(auto_timer)
    auto_timer = nil
  end
  
  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
  
  -- Get current buffer and cursor position
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  
  -- Get file path relative to git root
  local git_dir = get_git_dir()
  if not git_dir then
    return
  end
  
  local file_path = vim.fn.expand("%:p")
  local rel_path = file_path:sub(#git_dir + 2) -- +2 to remove the trailing slash
  
  -- Get blame info
  local blame_info = get_blame_info(rel_path, line_num)
  if not blame_info then
    return
  end
  
  -- Format the blame message
  local formatted_text = format_blame_info(blame_info)
  
  -- Show virtual text
  vim.api.nvim_buf_set_virtual_text(
    bufnr,
    ns_id,
    line_num - 1,
    {{formatted_text, M.config.hl_group}},
    {}
  )
  
  -- Clear virtual text after specified time
  if clear_timer then
    vim.loop.timer_stop(clear_timer)
  end
  
  clear_timer = vim.defer_fn(function()
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    clear_timer = nil
  end, M.config.show_time)
end

-- Setup auto show timer
local function setup_auto_show()
  if auto_timer then
    vim.loop.timer_stop(auto_timer)
  end
  
  auto_timer = vim.defer_fn(function()
    show_blame_info()
    auto_timer = nil
  end, M.config.auto_show_delay)
end

-- Initialize the plugin
function M.setup(opts)
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Create namespace for virtual text
  ns_id = vim.api.nvim_create_namespace("GitLensBlame")
  
  -- Set highlight group if it doesn't exist
  if vim.fn.hlexists(M.config.hl_group) == 0 then
    vim.api.nvim_set_hl(0, M.config.hl_group, { fg = "#888888", italic = true })
  end
  
  -- Create user commands
  vim.api.nvim_create_user_command("GitLensShow", show_blame_info, {})
  vim.api.nvim_create_user_command("GitLensShowDiff", function() show_commit_diff() end, {})
  
  -- Set up auto events
  if M.config.auto_show then
    local group = vim.api.nvim_create_augroup("GitLens", { clear = true })
    vim.api.nvim_create_autocmd({"CursorHold"}, {
      group = group,
      callback = function()
        -- Only try to show blame info in normal mode
        if vim.api.nvim_get_mode().mode == "n" then
          setup_auto_show()
        end
      end,
    })
    vim.api.nvim_create_autocmd({"CursorMoved", "InsertEnter", "BufLeave"}, {
      group = group,
      callback = function()
        -- Clear existing virtual text
        vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
        
        -- Cancel any pending timers
        if auto_timer then
          vim.loop.timer_stop(auto_timer)
          auto_timer = nil
        end
        
        if clear_timer then
          vim.loop.timer_stop(clear_timer)
          clear_timer = nil
        end
      end,
    })
  end
end

-- Command to toggle auto show
function M.toggle_auto_show()
  M.config.auto_show = not M.config.auto_show
  if M.config.auto_show then
    print("GitLens auto show enabled")
    M.setup(M.config)
  else
    print("GitLens auto show disabled")
    vim.api.nvim_create_augroup("GitLens", { clear = true })
  end
end

-- Function to show diff for the commit that last changed the current line
function show_commit_diff()
  -- Get current buffer and cursor position
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  
  -- Get file path relative to git root
  local git_dir = get_git_dir()
  if not git_dir then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end
  
  local file_path = vim.fn.expand("%:p")
  local rel_path = file_path:sub(#git_dir + 2) -- +2 to remove the trailing slash
  
  -- Get blame info to get the commit hash
  local blame_info = get_blame_info(rel_path, line_num)
  if not blame_info or not blame_info.hash then
    vim.notify("Could not get commit info for current line", vim.log.levels.ERROR)
    return
  end
  
  -- Get commit hash and parent hash
  local hash = blame_info.hash
  local parent_hash = nil
  
  -- Get the parent commit hash
  local handle = io.popen(string.format("git rev-parse %s^ 2>/dev/null", hash))
  if handle then
    parent_hash = handle:read("*a"):gsub("%s+$", "")
    handle:close()
  end
  
  if not parent_hash or parent_hash == "" then
    -- This might be the first commit
    vim.notify("This appears to be the first commit for this line", vim.log.levels.INFO)
    return
  end
  
  -- Get the diff between the commit and its parent
  local diff_cmd = string.format(
    "git diff --unified=3 %s %s -- %s 2>/dev/null",
    parent_hash,
    hash,
    rel_path
  )
  
  local diff_handle = io.popen(diff_cmd)
  if not diff_handle then
    vim.notify("Failed to get diff information", vim.log.levels.ERROR)
    return
  end
  
  local diff_output = diff_handle:read("*a")
  diff_handle:close()
  
  if diff_output == "" then
    vim.notify("No diff available for this commit", vim.log.levels.INFO)
    return
  end
  
  -- Create a new buffer for the diff
  local diff_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(diff_bufnr, "bufhidden", "wipe")
  
  -- Set buffer name
  local buffer_name = string.format("Diff for %s", string.sub(hash, 1, 7))
  vim.api.nvim_buf_set_name(diff_bufnr, buffer_name)
  
  -- Set buffer content
  local diff_lines = {}
  for line in diff_output:gmatch("[^\r\n]+") do
    table.insert(diff_lines, line)
  end
  vim.api.nvim_buf_set_lines(diff_bufnr, 0, -1, false, diff_lines)
  
  -- Set filetype for syntax highlighting
  vim.api.nvim_buf_set_option(diff_bufnr, "filetype", "diff")
  
  -- Calculate window dimensions
  local width = M.config.diff_window_width
  local height = M.config.diff_window_height
  
  if width == 0 then
    width = math.min(#diff_output:match("[^\n]+") or 80, math.floor(vim.o.columns * 0.8))
  end
  
  if height == 0 then
    height = math.min(#diff_lines, math.floor(vim.o.lines * 0.8))
  end
  
  -- Create a floating window
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = M.config.diff_window_border,
    title = buffer_name,
    title_pos = "center"
  }
  
  local win_id = vim.api.nvim_open_win(diff_bufnr, true, win_opts)
  
  -- Add keymaps to close the window
  vim.api.nvim_buf_set_keymap(diff_bufnr, "n", "q", 
    ":lua vim.api.nvim_win_close(" .. win_id .. ", true)<CR>", 
    { noremap = true, silent = true }
  )
  vim.api.nvim_buf_set_keymap(diff_bufnr, "n", "<Esc>", 
    ":lua vim.api.nvim_win_close(" .. win_id .. ", true)<CR>", 
    { noremap = true, silent = true }
  )
end

return M
