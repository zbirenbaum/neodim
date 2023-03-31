local M = {}
local colors = require('neodim.rewrite.colors')

local results = {
  semantic = {},
  treesitter = {}
}

--setmetatable(results, { __mode = "v" }) -- make values weak
-- create a cache for defined hlgroups
M.params = {
  bg = colors.hex_to_rgb("#000000"),
  alpha = 0.75
}

M.getDimHighlight = function (ns, type, group, opts)
  if not results[type][group] then
    local rgb = vim.api.nvim_get_hl_by_name(group, true)
    local hl_opts = opts or {}
    for def, v in pairs(rgb) do
      hl_opts[def] = colors.blend(colors.format_rgb(v), M.params.bg, M.alpha)
      print(hl_opts)
    end
    results[type][group] = hl_opts
    vim.api.nvim_set_hl(0, group, hl_opts)
  end
  results[type][group] = true
end

M.dimHighlight = function (bufnr, ns, diagnostic)

  local createExtmark = function (type, group)
    M.getDimHighlight(ns, type, group)
    return vim.api.nvim_buf_set_extmark(bufnr, 0, diagnostic.lnum, diagnostic.col, {
      end_line = diagnostic.lnum,
      end_col = diagnostic.end_col,
      hl_group = group,
      priority = 1000,
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
    M.getDimHighlight(ns, 'treesitter', token.hl_group)
    createExtmark('treesitter', token.hl_group)
  end

  for _, token in ipairs(semantic) do
    local hl = M.semanticHighlighter(token.hl_groups, ns)
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

return M
