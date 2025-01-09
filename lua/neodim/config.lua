local M = {}

local colors = require 'neodim.colors'

local get_bg = function()
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

---@class neodim.Options
---@field alpha number
---@field blend_color string
---@field hide { underline: boolean?, virtual_text: boolean?, signs: boolean? }
---@field priority integer
---@field disable table<string, true>
---@field regex string[] | table<string, string[]>

---@class neodim.SetupOptions
---@field alpha? number
---@field blend_color? string
---@field hide? { underline: boolean?, virtual_text: boolean?, signs: boolean? }
---@field priority? integer
---@field disable? string[]
---@field regex? string[] | table<string, string[]>

---@type neodim.SetupOptions
local default_opts = {
  alpha = 0.75,
  blend_color = get_bg(),
  hide = { underline = true, virtual_text = true, signs = true },
  priority = 128,
  disable = {},
  regex = {
    '[uU]nused',
    '[nN]ever [rR]ead',
    '[nN]ot [rR]ead',
  },
}

---@type neodim.Options
M.opts = default_opts --[[@as table]]

---@param opts neodim.SetupOptions?
M.setup = function(opts)
  M.opts = vim.tbl_extend('force', default_opts, opts or {})

  for _, lang in ipairs(M.opts.disable) do
    M.opts.disable[lang] = true
  end
end

return M
