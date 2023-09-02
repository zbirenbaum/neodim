# neodim

Neovim plugin for dimming the highlights of unused functions, variables, parameters, and more


## Requirements

- **Neovim** ≧ 0.10.0
- **Treesitter**
- **Language server** supporting [DiagnosticTag](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#diagnosticTag)

## Installation

The following is an example of using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
require("lazy").setup(
  -- ...
  {
    "zbirenbaum/neodim",
    event = "LspAttach",  -- remove this if you don't want to lazy loading
    config = function()
      require("neodim").setup()
    end,
  },
  -- ...
)
```

## Options

You can pass options to the `setup()` function.

Example (**not a default value**):

```lua
require("neodim").setup({
  alpha = 0.75,
  blend_color = "#000000",
  
  hide = {
    signs = false,
    -- disable underline in dimmed text
    underline = true,
    virtual_text = false,
  },
  
  disable = {
    -- disable when filetype is "python" or "swift"
    "python",
    "swift",
  },

  -- don't need to be set if you have all the `Requirements`
  regex = {
    "[Uu]nused",
    cs = {
      "CS8019",
    },
    rust = {},
  },

  -- priority of extmarks used for highlight
  priority = 128,
  
  refresh_delay = 75,
})
```

Please see [`:help neodim-options`](./doc/neodim.txt) for more details.

## Documentation

```vim
:help neodim
```
