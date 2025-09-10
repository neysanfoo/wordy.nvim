# Wordy.nvim

Wordle for neovim!

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  "neysanfoo/wordy.nvim",
  opts = {},
}
```

[packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use({
  "neysanfoo/wordy.nvim",
  config = function()
    require("wordy").setup()
  end,
})
```


[Vundle](https://github.com/VundleVim/Vundle.vim)
Add to your `.vimrc` or `init.vim`:
```vim
" In your plugin list
Plugin 'neysanfoo/wordy.nvim'

" After :PluginInstall
lua << EOF
require("wordy").setup()
EOF
```

Again, run:
```
:PluginInstall
```

## Commands

Start a new game:

```
:Wordy
```

## Gameplay

* **Normal mode**
  * `i` – switch to insert mode
  * `q` / `<Esc>` – quit the game
  * `<Enter>` – submit guess (also works in insert)

* **Insert mode**
  * Type letters to fill the row
  * `<Enter>` – submit guess
  * `<Esc>` – return to normal mode
  * Arrow keys / `<BS>` / `<Del>` work as expected

The game auto-saves progress and restores it on the next launch.


## How to Override Default Colors
If you want to force your own shades you can pass a `colors` table to
`setup()`. All keys are optional:

```lua
require("wordy").setup({
  colors = {
    border  = { fg = "#00ffff" },
    typed   = { fg = "#ffffff" },
    correct = { bg = "#228b22", fg = "#ffffff" },
    present = { bg = "#b8860b", fg = "#ffffff" },
    absent  = { fg = "#696969" },
  },
})
```
