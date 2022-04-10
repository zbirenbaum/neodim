local util = require("dim.util")
local results = {}
setmetatable(results, { __mode = "v" }) -- make values weak
local dim = {}
local hl_map = {}

dim.marks = {}

local function get_ts_group(bufnr, lnum, col, end_col)
  local ts_group = util.get_treesitter_nodes(bufnr, lnum, col, end_col)
  ts_group = type(ts_group) == "string" and ts_group or nil
  return ts_group
end

local function set_unused_group(ts_group)
  local darkened = function(color)
    if not results[color] then
      results[color] = util.darken(color, 0.75)
    end
    return results[color]
  end
  local unused_group = string.format("%sUnused", ts_group)
  if hl_map[unused_group] then
    return unused_group
  end
  local hl = vim.api.nvim_get_hl_by_name(ts_group, true)
  local color = string.format("#%x", hl["foreground"] or 0)
  if #color ~= 7 then
    color = "#ffffff"
  end
  hl_map[unused_group] = { fg = darkened(color), undercurl = false, underline = false }
  vim.api.nvim_set_hl(0, unused_group, hl_map[unused_group])
  return unused_group
end

dim.ignore_vtext = function(diagnostic)
  return not dim.detect_unused(diagnostic) and diagnostic.message or nil
end

local format_loc = function (diagnostic)
  return {
    start = { diagnostic.lnum, diagnostic.col },
    ["end"] = { diagnostic.lnum, diagnostic.end_col },
  }
end

dim.detect_unused = function(diagnostics)
  local is_list = vim.tbl_islist(diagnostics)
  local unused = function(diagnostic)
    if diagnostic.severity == vim.diagnostic.severity.HINT then
      local tags = diagnostic.tags or diagnostic.user_data.lsp.tags
      return tags and vim.tbl_contains(tags, vim.lsp.protocol.DiagnosticTag.Unnecessary)
    end
    return false
  end
  return is_list and vim.tbl_filter(unused, diagnostics) or unused(diagnostics)
end

local function create_diagnostic_extmark(bufnr, ns, diagnostic, hl)
  local function get_hl_group()
    if not hl then
      local ts_group = get_ts_group(bufnr, diagnostic.lnum, diagnostic.col, diagnostic.end_col)
      if not ts_group then return end
      return set_unused_group(ts_group)
    end
  end
  local unused_group = hl or get_hl_group()
  if not unused_group then return end
  return vim.api.nvim_buf_set_extmark(bufnr, ns, diagnostic.lnum, diagnostic.col, {
    end_line = diagnostic.lnum,
    end_col = diagnostic.end_col,
    hl_group = unused_group,
    priority = 300,
    end_right_gravity = true,
    strict = false,
  })
end

dim.setup = function(opts)
  dim.ns = vim.api.nvim_create_namespace("dim")
  if opts and opts.hl then
    vim.api.nvim_set_hl(0, "Unused", opts.hl)
  end
  vim.diagnostic.handlers["dim/unused"] = {
    show = function(_, bufnr, diagnostics, _)
      if not dim.marks[bufnr] then dim.marks[bufnr] = {} end
      local locs = {}
      local filtered = dim.detect_unused(diagnostics)
      for _, mark in ipairs(dim.marks[bufnr]) do
        vim.api.nvim_buf_del_extmark(bufnr, dim.ns, mark)
      end
      dim.marks[bufnr] = {}
      for _, diagnostic in ipairs(filtered) do
        local ext = create_diagnostic_extmark(bufnr, dim.ns, diagnostic)
        if ext then
          table.insert(locs, format_loc(diagnostic))
          table.insert(dim.marks[bufnr], ext)
        end
      end
    end
  }
end

return dim
