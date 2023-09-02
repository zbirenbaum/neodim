local M = {}

local colors = require 'neodim.colors'

local get_bg = function()
  ---@type vim.api.keyset.highlight
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  if normal and normal.bg then
    return colors.rgb_to_hex(normal.bg)
  end
  if vim.o.background == 'light' then
    return '#ffffff'
  else
    return '#000000'
  end
end

---@class neodim.opts
local default_opts = {
  refresh_delay = 75,
  alpha = 0.75,
  blend_color = get_bg(),
  hide = { underline = true, virtual_text = true, signs = true },
  priority = 128,
  disable = {},
  ---@type string[]|table<string, string[]>
  regex = {
    '[uU]nused',
    '[nN]ever [rR]ead',
    '[nN]ot [rR]ead',
  },
}

---@type neodim.opts
M.opts = {}

---@param opts neodim.opts?
M.setup = function(opts)
  M.opts = vim.tbl_extend('force', default_opts, opts or {})

  for _, lang in ipairs(M.opts.disable) do
    M.opts.disable[lang] = true
  end
end

return M
