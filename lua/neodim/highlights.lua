local M = {}
local opts = {}
local colors = require('neodim.colors')

local hl_map = {}

setmetatable(hl_map, { __mode = "v" }) -- make values weak


local getDimHighlight = function (ns, hl_group)
  local group =  string.format('%sUnused', hl_group)

  if hl_map[group] then
    return group
  end

  local hl = vim.api.nvim_get_hl(0, { name = hl_group, })

  if not hl.fg then return end
  local fg = colors.rgb_to_hex(hl.fg)
  local bg = colors.rgb_to_hex(tonumber(opts.blend_color, 16))
  local color = colors.blend(fg, bg, opts.alpha)

  vim.api.nvim_set_hl(ns, group, {
    fg = color,
    undercurl = false,
    underline = false,
  })
  hl_map[group] = true
  return group
end

-- create a cache for defined hlgroups


M.highlightDiagnostic = function (bufnr, ns, diagnostic)
  local createExtmark = function (hl_group)
    local priority = vim.highlight.priorities.treesitter + 1000
    return vim.api.nvim_buf_set_extmark(bufnr, ns, diagnostic.lnum, diagnostic.col, {
      end_line = diagnostic.lnum,
      end_col = diagnostic.end_col,
      hl_group = hl_group,
      priority = priority,
      end_right_gravity = true,
      strict = false
    })
  end

  local data = vim.inspect_pos(
    diagnostic.bufnr,
    diagnostic.row,
    diagnostic.col
  )
  local treesitter = data.treesitter

  for _, token in ipairs(treesitter) do
    local ts_group = string.format('@%s', token.capture)
    local hl_group = getDimHighlight(ns, ts_group)
    createExtmark(hl_group)
  end

  -- local semantic = data.semantic_tokens and data.semantic_tokens.hl_groups
  -- for _, token in ipairs(semantic) do
  --   local hl = semanticHighlighter(token.hl_groups)
  --   vim.api.nvim_buf_set_extmark(bufnr, ns, diagnostic.lnum, diagnostic.col, {
  --     end_line = diagnostic.lnum,
  --     end_col = diagnostic.end_col,
  --     hl_group = hl .. 'Unused',
  --     priority = vim.highlight.priorities.semantic_tokens,
  --     end_right_gravity = true,
  --     strict = false
  --   })
  -- end
end

-- M.init = function (config)
--   opts = config or {}
--   return M
-- end

return M
