local M = {}
local opts = {}
local colors = require('neodim.colors')

local hl_map = {
  semantic_tokens = {},
  treesitter = {}
}
local group_map = {
  semantic_tokens = {},
  treesitter = {}
}
local defined_hl = {}

local setUnusedGroup = function (hl_group)
   group_map[type][hl_group] = string.format('%sUnused',hl_group)
   return group_map[type][hl_group]
end

local getDimHighlight = function (hl_group, type)
  local group = group_map[type][hl_group] or setUnusedGroup(hl_group)

  if hl_map[group] then
    return group
  end

  local hl = vim.api.nvim_get_hl(0, { name = hl_group, })
  if not hl.fg then return end
  local bg = colors.rgb_to_hex(tonumber(opts.blend_color, 16))
  local fg = colors.rgb_to_hex(hl.fg)
  local color = colors.blend(fg, bg, opts.alpha)
  vim.api.nvim_set_hl(opts.ns, group, {
    fg = color,
    undercurl = false,
    underline = false,
  })
  return group
end

local semanticHighlighter = function (token)
  local hl = {token.type, unpack(token.modifiers or {})}
  local hl_name = token.type .. '_Unused'
  local ret = hl_name

  while #hl > 1 do
    if defined_hl[hl_name] then
      break
    end
    table.remove(hl)
    local hl_base_name = "@" .. table.concat(hl, ".")
    vim.api.nvim_set_hl(opts.ns, hl_name, {
      default = true, link = hl_base_name
    })
    defined_hl[hl_name] = true
    hl_name = hl_base_name
  end
  vim.api.nvim_set_hl(opts.ns, ret .. '.Unused', {
    default = true, link = ret
  })
  local unused_hl_name = getDimHighlight(ret, 'semantic_tokens')
  vim.api.nvim_set_hl(opts.ns, ret, {
    default = true, link = unused_hl_name
  })
  return ret
end

--setmetatable(results, { __mode = "v" }) -- make values weak
-- create a cache for defined hlgroups


M.highlight = function (bufnr, ns, diagnostic)
  local createExtmark = function (group, type)
    local hl_group = getDimHighlight(group, type)
    local priority = vim.highlight.priorities['type'] + 1000
    return vim.api.nvim_buf_set_extmark(bufnr, 0, diagnostic.lnum, diagnostic.col, {
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
  local semantic = data.semantic_tokens and data.semantic_tokens.hl_groups
  local treesitter = data.treesitter

  for _, token in ipairs(treesitter) do
    createExtmark(token.hl_group, 'treesitter')
  end

  for _, token in ipairs(semantic) do
    local hl = semanticHighlighter(token.hl_groups)
    vim.api.nvim_buf_set_extmark(bufnr, ns, diagnostic.lnum, diagnostic.col, {
      end_line = diagnostic.lnum,
      end_col = diagnostic.end_col,
      hl_group = hl .. 'Unused',
      priority = vim.highlight.priorities.semantic_tokens,
      end_right_gravity = true,
      strict = false
    })
  end
end

M.init = function (config)
  opts = config
  return M
end

return M
