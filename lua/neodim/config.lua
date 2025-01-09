local M = {}

local Color = require 'neodim.Color'

---@return neodim.Color
local get_bg = function()
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  if normal and normal.bg then
    return Color.from_int(normal.bg)
  elseif vim.o.background == 'light' then
    return Color.new(0xFF, 0xFF, 0xFF)
  else
    return Color.new(0x00, 0x00, 0x00)
  end
end

---@class neodim.Options
---@field alpha number
---@field blend_color neodim.Color
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

---@type neodim.Options
M.opts = {
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

---@generic T
---@param val T?
---@param default T
---@return T
local function r(val, default)
  if val == nil then
    return default
  else
    return val
  end
end

local raw = {} ---@type neodim.SetupOptions

---@param opts neodim.SetupOptions?
M.setup = function(opts)
  ---@type neodim.SetupOptions
  raw = vim.tbl_extend('force', raw, opts or {})
  raw.hide = raw.hide or {}
  M.opts = {
    alpha = r(raw.alpha, M.opts.alpha),
    blend_color = r(raw.blend_color and Color.from_str(raw.blend_color), M.opts.blend_color),
    hide = {
      underline = r(raw.hide.underline, M.opts.hide.underline),
      virtual_text = r(raw.hide.virtual_text, M.opts.hide.virtual_text),
      signs = r(raw.hide.signs, M.opts.hide.signs),
    },
    priority = r(raw.priority, M.opts.priority),
    disable = r(raw.disable, M.opts.disable),
    regex = r(raw.regex, M.opts.regex),
  }

  for _, lang in ipairs(M.opts.disable) do
    M.opts.disable[lang] = true
  end
end

vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function()
    if not raw.blend_color then
      M.opts.blend_color = get_bg()
    end
  end,
})

return M
