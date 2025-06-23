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
        border = { fg = "#565758" },
        typed = { fg = "#ffffff" },
        correct = { bg = "#538d4e", fg = "#ffffff" },
        present = { bg = "#b59f3b", fg = "#ffffff" },
        absent = { fg = "#777777" },
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
        border = { fg = "#565758" },
        typed = { fg = "#ffffff" },
        correct = { bg = "#538d4e", fg = "#ffffff" },
        present = { bg = "#b59f3b", fg = "#ffffff" },
        absent = { fg = "#777777" },
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

## Note

It will probably look bad with most color schemes except gruvbox.
