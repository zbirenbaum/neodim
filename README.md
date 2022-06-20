# neodim
Neovim plugin for dimming the highlights of unused functions, variables, parameters, and more

This plugin takes heavy inspiration from https://github.com/NarutoXY/dim.lua. The implementation in NarutoXY/dim.lua was a bit inefficient and I saw room for various improvements, including making the dimming an actual LSP handler, rather than an autocmd. The result is a much more polished experience with greater efficiency.

### Setup:

Install the plugin like any other:

```
use {
  "zbirenbaum/neodim",
  event = "LspAttach",
  config = function ()
    require("neodim").setup({
      alpha = 0.75
      blend_color = "#000000"
      update_in_insert = {
        enable = true,
        delay = 100,
      },
      hide = {
        virtual_text = true,
        signs = true,
        underline = true,
      }
    })
  end
}
```

### Options:

#### Dim Highlight Options

##### alpha

Alpha controls how dim the highlight becomes. A value of 1 means that dimming will do nothing at all, while a value of 0 will make it identical to #000000 or the color set in `blend_color`. Conceptually, if you were to place the text to be dimmed on a background of `blend_color`, and then set the opacity of the text to the value of alpha, you would have the resulting color that the plugin highlights with.


```
require("neodim").setup({
  alpha = 0.5 -- make the dimmed text even dimmer
})
```

##### blend_color

`blend_color` controls the color which is used to dim your highlight. Black is the default, but you could set this to your terminal or neovim background color to make it more seamless.

Example:

```
require("neodim").setup({
  blend_color = "#10171f"
})
```

##### update_in_insert:
**Important: This option should **NOT** be used if update_in_insert is set to true in your diagnostic config. Previously, that was how it was recommended to get live updates, but now this is a much better option.**

Update in insert mode from the diagnostic config causes all diagnostic handlers to update in insert mode, causing visual flashes and is a general annoyance fairly often. However, the update_in_insert feature implemented in neodim functions very differently. neodim will be the only diagnostic handler to update in insert mode. Additionally, this functionality was implemented via the hide callback, which is triggered while typing by the diagnostics automatically, and rather than call a function with a TextChanged autocmd, it cancels one instead. Thus, only after you have not typed for a very short amount of time will things refresh, greatly reducing visual flashing but allowing updates without going into normal mode. The delay field allows you to customize how long this period is, but be warned that lower delays will lead to higher cpu usage.

Example:
```
require("neodim").setup({
  update_in_insert = {
    enable = false, -- disable updates in insert mode
  },
})
```

```
require("neodim").setup({
  update_in_insert = {
    delay = 200, -- increase the delay for updates to 200ms between insertions
  },
})
```

#### Decoration Options
All decorations can be hidden for diagnostics pertaining to unused tokens. By default, hiding all of them is enabled, but you can re-enable them by changing the config table passed to neodim. It is important to note that regardless of what you put in this configuration, neodim will always respect settings created with `vim.diagnostic.config`. For example, if all underline decorations are disabled by running `vim.diagnostic.config({ underline=false })`, neodim will ***not*** re-enable them for "unused" diagnostics.

Example:

```
-- re-enable only sign decorations for 'unused' diagnostics
require("neodim").setup({
  hide = {signs = false }
})
```

```
-- renable all decorations for 'unused' diagnostics
require("neodim").setup({
  hide = {
    virtual_text = false,
    signs = false,
    underline = false,
  }
})
```

<!-- ### How to get live dim updates as you type -->
<!---->
<!-- The vim.diagnostic.config function provides hooks which allow you to affect the behavior of this plugin. Setting `update_in_insert` to true will cause the plugin to update as fast as your LSP can supply diagnostic info. I personally find it preferable to keep this value at false, but the option is there and I recommend trying both out to see which you prefer. -->
<!---->
<!-- Example: -->
<!-- ``` -->
<!-- vim.diagnostic.config({ -->
<!--   ... -->
<!--   update_in_insert = true, -- Set this to true for live dim updates as you type -->
<!--   ... -->
<!-- }) -->
<!-- ``` -->
