# neodim
Neovim plugin for dimming the highlights of unused functions, variables, parameters, and more

This plugin takes heavy inspiration from https://github.com/NarutoXY/dim.lua. The implementation in NarutoXY/dim.lua was a bit inefficient and I saw room for various improvements, including making the dimming an actual LSP handler, rather than an autocmd. The result is a much more polished experience with greater efficiency.

The plugin is finally out of early alpha, and I appear to have it stable. Getting things to not be dimmed on pressing 'jk' for escape was quite the adventure, but it finally works without any autocmd hacks that cause some LSPs issues! As far as I can tell it is perfectly stable.

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
