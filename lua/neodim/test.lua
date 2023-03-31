-- local util = require('neodim.util')
local colors = require('neodim.colors')

local highlighter = require('neodim.highlights')

local test_string = function ()
end

local bufnr = 0
local parser = vim.treesitter.get_parser(bufnr)
local hl_map = {}



local createExtmark = function (ns, hl_group, range)
  local priority = vim.highlight.priorities.treesitter + 1000
  print(vim.inspect(hl_group))
  return vim.api.nvim_buf_set_extmark(bufnr, ns, range.lnum, range.col, {
    end_line = range.lnum,
    end_col = range.end_col,
    hl_group = hl_group,
    priority = priority,
    end_right_gravity = true,
    strict = true
  })
end

local getDimHighlight = function (ns, hl_group)
  local opts = {
    alpha = .75,
    blend_color = "000000",
  }
  local group =  string.format('%sUnused', hl_group)

  if hl_map[group] then return group end

  local hl = vim.api.nvim_get_hl(0, { name = hl_group, })

  -- if not hl.fg then
  --   hl = vim.split(hl_group, '.')
  --   print(hl[1])
  --   local hl_name = '@' .. hl[1]
  --   local ret = hl_name
  --   hl = vim.api.nvim_get_hl(0, { name = ret, })
  -- end

  local fg = colors.rgb_to_hex(hl.fg)
  local bg = colors.rgb_to_hex(tonumber(opts.blend_color, 16))
  local color = colors.blend(fg, bg, opts.alpha)

  vim.api.nvim_set_hl(ns, group, {
    fg = color,
    undercurl = false,
    underline = false,
  })

  print(color)
  hl_map[group] = true
  return group
end

-- local function recurseRoot(node)
--   local result = {}
--   local function recurse(root)
--     if not root then return end
--     for child, _, _ in root:iter_children() do
--       local lnum, col, end_lnum, end_col = child:start()
--       local captures = vim.treesitter.get_captures_at_pos(bufnr, lnum, col)
--       for _, data in ipairs(captures) do
--         local hl_group = string.format('@%s', data.capture)
--         if not hl_group then hl_group = '@' end
--         for token in string.gmatch(data.capture, "[^%.]+") do
--           local tmp =  hl_group .. token
--           if getDimHighlight(tmp) then
--             hl_group = tmp
--           else
--             vim.api.nvim_set_hl(0, tmp, {
--               link = hl_group, default=true
--             })
--           end
--         end
--
--         result[#result+1] = {
--           hl_group = hl_group,
--           range = { lnum=lnum, col=col, end_lnum=end_lnum, end_col=end_col }
--         }
--       end
--       recurse(child)
--     end
--   end
--   recurse(node)
--   return result
-- end

local function recurseRoot(node)
  local result = {}
  local function recurse(root)
    if not root then return end
    for child, _, _ in root:iter_children() do
      local lnum, col, end_lnum, end_col = child:start()
      local captures = vim.treesitter.get_captures_at_pos(bufnr, lnum, col)
      for _, data in ipairs(captures) do
        local hl_group = string.format('@%s', data.capture)
        result[#result+1] = {
          hl_group = hl_group,
          range = { lnum=lnum, col=col, end_lnum=end_lnum, end_col=end_col }
        }
      end
      recurse(child)
    end
  end
  recurse(node)
  return result
end

local hlDiagnosticTokens = function (ns, diagnostic)
  local d = diagnostic
  local range = { d.lnum, d.col, d.end_lnum, d.end_col }
  local root = parser:named_node_for_range(range)
  if not root then return end
  local tokens = recurseRoot(root) or {}
  for _, token in ipairs(tokens) do
    print(vim.inspect(token))
    local hl = getDimHighlight(ns, token.hl_group)
    createExtmark(ns, hl, token.range)
  end
end


local ns = vim.api.nvim_create_namespace('neodim')
vim.api.nvim_set_hl_ns(ns)
for _, d in ipairs(vim.diagnostic.get(0)) do
  hlDiagnosticTokens(ns, d)
end

