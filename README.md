# neodim
Neovim plugin for dimming the highlights of unused functions, variables, parameters, and more

This plugin takes heavy inspiration from https://github.com/NarutoXY/dim.lua. The implementation in NarutoXY/dim.lua was a bit inefficient and I saw room for various improvements, including making the dimming an actual LSP handler, rather than an autocmd. The result is a much more polished experience with greater efficiency.

The plugin is finally out of early alpha, and I appear to have it stable. Getting things to not be dimmed on pressing 'jk' for escape was quite the adventure, but it finally works without any autocmd hacks that cause some LSPs issues! As far as I can tell it is perfectly stable.

### Setup:

Install the plugin like any other:

```
use {
  "zbirenbaum/neodim",
  config = function ()
    require("neodim").setup()
  end
}
```

### How to get live dim updates as you type

The vim.diagnostic.config function provides hooks which allow you to affect the behavior of this plugin. Setting `update_in_insert` to true will cause the plugin to update as fast as your LSP can supply diagnostic info. I personally find it preferable to keep this value at false, but the option is there and I recommend trying both out to see which you prefer.

Example:
```
vim.diagnostic.config({
  ...
  update_in_insert = true, -- Set this to true for live dim updates as you type
  ...
})
```

### How to remove vtext from dimmed diagnostics: 

Add the following to your diagnostic config:

`require("neodim").ignore_vtext(diagnostic)`

Example:

```
vim.diagnostic.config({
  virtual_text = {
    ...
    format = function(diagnostic)
      return require("neodim").ignore_vtext(diagnostic)
    end,
    ...
  },
})
```
