# neodim

> *Neovim plugin for dimming the highlights of unused functions, variables, parameters, and more*

This plugin takes heavy inspiration from https://github.com/NarutoXY/dim.lua. \
The implementation in NarutoXY/dim.lua was a bit inefficient and I saw room for various improvements,
including making the dimming an actual LSP handler, rather than an autocmd.
The result is a much more polished experience with greater efficiency.

## Setup

### Requirements

- Neovim 0.10.0 or later
- Language server that supports [diagnostic tags](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#diagnosticTag)

### Installation

You can install with builtin packages or your favorite package manager.

The following is an example installation using Lazy.nvim:

```lua
{
  "zbirenbaum/neodim",
  event = "LspAttach",
  config = function()
    require("neodim").setup()
  end,
}
```

## Options

```lua
require("neodim").setup({
  alpha = 0.75,
  blend_color = nil,
  hide = {
    underline = true,
    virtual_text = true,
    signs = true,
  },
  regex = {
    "[uU]nused",
    "[nN]ever [rR]ead",
    "[nN]ot [rR]ead",
  },
  priority = 128,
  disable = {},
})
```

### Dim Highlight Options

#### alpha

`alpha` controls how dim the highlight becomes.
A value of 1 means that dimming will do nothing at all, while a value of 0 will make it identical to the color set in `blend_color`.
Conceptually, if you were to place the text to be dimmed on a background of `blend_color`,
and then set the opacity of the text to the value of alpha, you would have the resulting color that the plugin highlights with.


```lua
require("neodim").setup({
  alpha = 0.5 -- make the dimmed text even dimmer
})
```

#### blend_color

`blend_color` controls the color which is used to dim your highlight.
neodim sets this option automatically, so you don't need to set it if you want to set to the background color of the `Normal` highlight.

Example:

```lua
require("neodim").setup({
  blend_color = "#10171f"
})
```

### regex

If the diagnostic message matches one of these, the code to which the diagnostic refers is dimmed.

You can set up each filetype by entering in a table with the key as the filetype.

Example:
```lua
  require("neodim").setup({
    regex = {
      "[Uu]nused",
      cs = {
        "CS8019",
      },
      -- disable `regex` option when filetype is "rust"
      rust = {},
    }
  })
```

### Decoration Options

All decorations can be hidden for diagnostics pertaining to unused tokens. \
By default, hiding all of them is enabled, but you can re-enable them by changing the config table passed to neodim.

It is important to note that regardless of what you put in this configuration,
neodim will always respect settings created with `vim.diagnostic.config`.
For example, if all underline decorations are disabled by running `vim.diagnostic.config({ underline=false })`,
neodim will ***not*** re-enable them for "unused" diagnostics.

Example:

```lua
-- re-enable only sign decorations for 'unused' diagnostics
require("neodim").setup({
  hide = { signs = false }
})
```

```lua
-- re-enable all decorations for 'unused' diagnostics
require("neodim").setup({
  hide = {
    virtual_text = false,
    signs = false,
    underline = false,
  }
})
```
