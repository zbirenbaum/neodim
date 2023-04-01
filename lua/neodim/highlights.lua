local M = {}
local colors = require('neodim.colors')
local ts = vim.treesitter
local parsers = require "nvim-treesitter.parsers"
local opts = {
  blend_color = '000000',
  alpha = 0.75,
}

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

local createExtmark = function (bufnr, ns, hl_group, range)
  local priority = vim.highlight.priorities.treesitter + 1000
  hl_group = getDimHighlight(ns, hl_group)
  return vim.api.nvim_buf_set_extmark(bufnr, ns, range.lnum, range.col, {
    end_line = range.lnum,
    end_col = range.end_col,
    hl_group = hl_group,
    priority = priority,
    end_right_gravity = true,
    strict = false
  })
end

local function get_node_for_range(bufnr, range)
  local root_lang_tree = parsers.get_parser(bufnr)
  if not root_lang_tree then
    return
  end

  local root ---@type TSNode|nil
  for _, tree in ipairs(root_lang_tree:trees()) do
    local tree_root = tree:root()
    if tree_root and ts.is_in_node_range(tree_root, range[1], range[2]) then
      root = tree_root
      break
    end
  end

  -- local root = ts_util.get_root_for_position(range[1], range[2], root_lang_tree)
  if not root then
    return
  end
  return root:named_descendant_for_range(range[1], range[2], range[3], range[4])
end

--- @param diagnostic table
local getDiagnosticNodes = function (diagnostic)
  local compareBoundary = function (node, row, col)
    if not node then return end
    local nrow, ncol = node:end_()
    return row <= nrow and ncol <= col
  end

  local getChildrenInBoundary = function (node, row, col)
    local matches = {}
    while(node and compareBoundary(node, row, col)) do
      matches[#matches+1] = node
      node = node:child()
    end
    return matches
  end

  local d = diagnostic
  local range = { d.lnum, d.col, d.end_lnum, d.end_col }
  local root = get_node_for_range(d.bufnr, range)
  local children = getChildrenInBoundary(root, d.end_lnum, d.end_col)
  return children
end

M.highlightDiagnostic = function (ns, diagnostic)
  local d = diagnostic
  local children = getDiagnosticNodes(d)
  for _, child in ipairs(children) do
    local row, col, end_row, end_col = child:range()
    local info = vim.inspect_pos(d.bufnr, row, col, {
      treesitter = true
    })
    for _, text in ipairs(info.treesitter) do
      local hl_group = text.hl_group_link or text.hl_group
      local node_range = {
        lnum = row,
        col = col,
        end_lnum = end_row,
        end_col = end_col
      }
      createExtmark(d.bufnr, ns, hl_group, node_range)
    end
  end
end

M.init = function (params)
  opts = vim.tbl_extend('force', opts, params or {})
  return M
end

return M
