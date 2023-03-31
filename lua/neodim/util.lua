local M = {}
local ts_utils = require "nvim-treesitter.ts_utils"
local highlighter = require "vim.treesitter.highlighter"

-- Refactor:
-- First find the ranges which need to be dimmed from diagnostics
-- find all the nodes in those ranges
-- highlight those nodes with the dimmed color

local compareBoundary = function (node, row, col)
  print(node:end_())
  print(node:type())
  local nrow, ncol, _ node:end_()
  return row == nrow and col >= ncol-1
end

local getChildrenInBoundary = function (node, row, col)
  local matches = {}
  node = node:child()
  while(node and compareBoundary(node, row, col)) do
    matches[#matches+1] = node
    node = node:child()
  end
  return matches
end

local getNodesInBoundary = function (node, row, col)
  local matches = {}
  while node and compareBoundary(node, row, col) do
    matches[#matches+1] = node
    for _, child in ipairs(getChildrenInBoundary(node, row, col)) do
      matches[#matches+1] = child
    end
    node = node:next_named_sibling()
  end
  return matches
end

M.matches = function ()
  for pattern, match, metadata in cquery:iter_matches(tree:root(), bufnr, first, last) do
    for id, node in pairs(match) do
      local name = query.captures[id]
      -- `node` was captured by the `name` capture in the match
      local node_data = metadata[id] -- Node level metadata
      -- ... use the info here ...
    end
  end
end
M.getNodesInRange = function (bufnr, range)
  local node = vim.treesitter.get_node({bufnr = bufnr, row = range.startrow, col = range.startcol})
  if not node then return {} end
  return getNodesInBoundary(node, range.endrow, range.endcol)
  -- while(not x) do
  --   local nchildren = node:child_count()
  --   local lastchild = node:child(nchildren)
  --   if not vim.treesitter.is_in_node_range(lastchild, row, col) then
  --   while(nchildren > 0) do
  --     table.insert(matches, child)
  --     if vim.treesitter.is_in_node_range(child, row, col) then
  --       node = child
  --       break
  --     end
  --     nchildren = nchildren - 1
  --     node = node:child()
  --   end
  --   table.insert(matches, node)
  --   print(vim.inspect(node))
  -- end
  -- table.insert(matches, node)
end

local to_hl_group = function (inputstr, sep)
  if not inputstr then return end
  sep = sep or '%.'
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str:sub(1, 1):upper() .. str:sub(2))
  end
  return 'TS' .. table.concat(t)
end

local to_ts_hl_group = function (str)
  local is_updated, _ = pcall(vim.api.nvim_get_hl, 0, {name="@warning"});
  if not is_updated then
    return
  end
  return "@"..str
end

M.get_treesitter_nodes = function(bufnr, row, col)
  local capture_fn = vim.treesitter.get_captures_at_pos
  if capture_fn ~= nil then
    local nodes = capture_fn(bufnr, row, col)
    local matches = vim.tbl_map(function(match)
      return match.capture
    end, nodes)

    if #matches == 0 then
      return
    end

    local hl_group = to_ts_hl_group(matches[#matches]) or to_hl_group(matches[#matches])

    return hl_group
  else
  -- fallback for older neovim versions
    local buf_highlighter = highlighter.active[bufnr]
    if not buf_highlighter then return {} end
    local matches = {}
    buf_highlighter.tree:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end
      local root = tstree:root()
      local root_start_row, _, root_end_row, _ = root:range()
      if root_start_row > row or root_end_row < row then
        return
      end
      local query = buf_highlighter:get_query(tree:lang())
      if not query:query() then
        return
      end
      local iter = query:query():iter_captures(root, buf_highlighter.bufnr, row, row + 1)
      for capture, node, _ in iter do
        local hl = query.hl_cache[capture]
        if hl and ts_utils.is_in_node_range(node, row, col) then
          local c = query._query.captures[capture]
          if c ~= nil then
            local general_hl = query:_get_hl_from_capture(capture)
            table.insert(matches, { ts_group = general_hl, node = node })
          end
        end
      end
    end, true)
    local final = #matches >= 1 and matches[#matches] or nil
    if not final then
      return
    end
    local unused_group = final.ts_group
    return unused_group
  end
end

local hex_to_rgb = function(hex_str)
  local hex = "[abcdef0-9][abcdef0-9]"
  local pat = "^#(" .. hex .. ")(" .. hex .. ")(" .. hex .. ")$"
  hex_str = string.lower(hex_str)
  assert(string.find(hex_str, pat) ~= nil, "hex_to_rgb: invalid hex_str: " .. tostring(hex_str))
  local red, green, blue = string.match(hex_str, pat)
  return { tonumber(red, 16), tonumber(green, 16), tonumber(blue, 16) }
end

local blend = function(fg, bg, alpha)
  bg = hex_to_rgb(bg)
  fg = hex_to_rgb(fg)
  local blendChannel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end
  return string.format("#%02X%02X%02X", blendChannel(1), blendChannel(2), blendChannel(3))
end

M.darken = function(hex, amount, bg)
  return blend(hex, bg, math.abs(amount))
end

return M
