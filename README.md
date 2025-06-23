# Wordy.nvim

Wordle for neovim!

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  "neysanfoo/wordy.nvim",
  config = function()
    require("wordy").setup({
      colors = {
        typed   = { fg = "#cdd6f4" },
        empty   = { bg = "#1e1e2e", fg = "#bac2de" },
        correct = { bg = "#a6e3a1", fg = "#11111b" },
        present = { bg = "#f9e2af", fg = "#11111b" },
      },
    })
  end,
}
```

[packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
  config = function()
    require("wordy").setup({
      colors = {
        empty   = { bg = "#1e1e2e", fg = "#bac2de" },
        typed   = { fg = "#cdd6f4" },
        correct = { bg = "#a6e3a1", fg = "#11111b" },
        present = { bg = "#f9e2af", fg = "#11111b" },
      },
    })
  end,
})
```

## Commands

Start a new game:

```
:Wordy
```
