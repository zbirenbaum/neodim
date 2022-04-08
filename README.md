# neodim
Neovim plugin for dimming the highlights of unused functions, variables, parameters, and more

This plugin takes heavy inspiration from https://github.com/NarutoXY/dim.lua. The implementation in NarutoXY/dim.lua was a bit inefficient and I saw room for various improvements, including making the dimming an actual LSP handler, rather than an autocmd. The result is a much more polished experience with greater efficiency.

### Setup:

- Install the plugin like any other:
```
use {
  "zbirenbaum/neodim",
  config = function ()
    require("dim").setup()
  end
}
```
### How to remove vtext from dimmed diagnostics: 
- Add the following to your diagnostic config:

`require("dim").ignore_vtext(diagnostic)`

- For example:

```
vim.diagnostic.config({
  virtual_text = {
    prefix = "",
    format = function(diagnostic)
      return require("dim").ignore_vtext(diagnostic)
    end,
  },
  signs = true,
  underline = false,
  update_in_insert = false,
})
```
