# GitLens.nvim

A Neovim plugin that shows git blame information for the current line, similar to GitLens in VSCode.

## Installation

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'pradhyu/gitlens.nvim',
  requires = { 'nvim-lua/plenary.nvim' }
}
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'pradhyu/gitlens.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('gitlens').setup()
  end
}
```

### Manual Installation

```bash
# Create plugin directory if it doesn't exist
mkdir -p ~/.config/nvim/pack/plugins/start/

# Clone the repository
git clone https://github.com/pradhyu/gitlens.nvim ~/.config/nvim/pack/plugins/start/gitlens.nvim

# Optional: Clone dependency
git clone https://github.com/nvim-lua/plenary.nvim ~/.config/nvim/pack/plugins/start/plenary.nvim
```

Then add this to your `init.lua`:

```lua
require('gitlens').setup()
```

## Configuration

Add this to your `init.lua` or relevant configuration file:

```lua
require('gitlens').setup({
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
})
```

## Commands

The plugin provides the following commands:

- `:GitLensShow` - Manually show git blame information for the current line
- `:GitLensShowDiff` - Show a diff of changes made in the commit that last modified the current line
- `:lua require('gitlens').toggle_auto_show()` - Toggle automatic display of blame information when the cursor stays on a line

## Features

- Shows git blame information inline as virtual text
- Automatically shows blame info when cursor rests on a line (configurable)
- Shows diff of changes made in the commit that last modified the current line
- Customizable format for blame information
- Works with any git repository

## Requirements

- Neovim 0.7+
- Git installed and accessible in your PATH
