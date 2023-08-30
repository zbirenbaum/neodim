# neodim
Neovim plugin for dimming the highlights of unused functions, variables, parameters, and more

This plugin takes heavy inspiration from https://github.com/NarutoXY/dim.lua. The implementation in NarutoXY/dim.lua was a bit inefficient and I saw room for various improvements, including making the dimming an actual LSP handler, rather than an autocmd. The result is a much more polished experience with greater efficiency.

### Setup:

Neovim 0.10.0 is required for this plugin to work properly.

```lua
{
  "zbirenbaum/neodim",
  event = "LspAttach",
  config = function ()
    require("neodim").setup({
      refresh_delay = 75,
      alpha = 0.75,
      blend_color = '#000000',
      hide = {
        underline = true,
        virtual_text = true,
        signs = true ,
      },
      priority = 128,
      disable = {},
    })
  end
}
```

### Options:

#### Dim Highlight Options

##### alpha

Alpha controls how dim the highlight becomes. A value of 1 means that dimming will do nothing at all, while a value of 0 will make it identical to #000000 or the color set in `blend_color`. Conceptually, if you were to place the text to be dimmed on a background of `blend_color`, and then set the opacity of the text to the value of alpha, you would have the resulting color that the plugin highlights with.


```lua
require("neodim").setup({
  alpha = 0.5 -- make the dimmed text even dimmer
})
```

##### blend_color

`blend_color` controls the color which is used to dim your highlight. Black is the default, but you could set this to your terminal or neovim background color to make it more seamless.

Example:

```lua
require("neodim").setup({
  blend_color = "#10171f"
})
```

#### Decoration Options
All decorations can be hidden for diagnostics pertaining to unused tokens. By default, hiding all of them is enabled, but you can re-enable them by changing the config table passed to neodim. It is important to note that regardless of what you put in this configuration, neodim will always respect settings created with `vim.diagnostic.config`. For example, if all underline decorations are disabled by running `vim.diagnostic.config({ underline=false })`, neodim will ***not*** re-enable them for "unused" diagnostics.

Example:

```lua
-- re-enable only sign decorations for 'unused' diagnostics
require("neodim").setup({
  hide = { signs = false }
})
```

```lua
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
