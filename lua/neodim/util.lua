local M = {}

local ts_utils = require "nvim-treesitter.ts_utils"
local highlighter = require "vim.treesitter.highlighter"

local to_hl_group = function (inputstr, sep)
  if not inputstr then return end
  sep = sep or '%.'
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str:sub(1, 1):upper() .. str:sub(2))
  end
  return 'TS' .. table.concat(t)
end

M.get_treesitter_nodes = function(bufnr, row, col)
  local capture_fn = vim.treesitter.get_captures_at_pos or vim.treesitter.get_captures_at_position
  if capture_fn ~= nil then
    local nodes = capture_fn(bufnr, row, col)
    local matches = vim.tbl_map(function(match)
      return match.capture
    end, nodes)

    if #matches == 0 then
      return
    end

    local hl_group = to_hl_group(matches[#matches])

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
