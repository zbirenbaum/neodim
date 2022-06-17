local util = require("neodim.util")
local results = {}
setmetatable(results, { __mode = "v" }) -- make values weak
local dim = {}
local hl_map = {}

local exists_or_init = function (t) return t or {} end

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

local function create_diagnostic_extmark(bufnr, ns, diagnostic)
  local function get_hl_group()
    local ts_group = get_ts_group(bufnr, diagnostic.lnum, diagnostic.col, diagnostic.end_col)
    if not ts_group then return end
    return set_unused_group(ts_group)
  end
  local unused_group = dim.hl or get_hl_group()
  if not unused_group then return end
  return vim.api.nvim_buf_set_extmark(bufnr, ns, diagnostic.lnum, diagnostic.col, {
    end_line = diagnostic.lnum,
    end_col = diagnostic.end_col,
    hl_group = unused_group,
    priority = 200,
    end_right_gravity = true,
    strict = false,
  })
end

local is_unused = function(diagnostic)
  local diag_info = diagnostic.tags or vim.tbl_get(diagnostic, "user_data", "lsp", "tags") or diagnostic.code
  if type(diag_info) == "table" then
    return diag_info and vim.tbl_contains(diag_info, vim.lsp.protocol.DiagnosticTag.Unnecessary)
  elseif type(diag_info) == "string" then
    return string.find(diag_info, ".*[uU]nused.*") ~= nil
  end
end

local detect_unused = function(diagnostics)
  local is_list = vim.tbl_islist(diagnostics)
  return is_list and vim.tbl_filter(is_unused, diagnostics) or is_unused(diagnostics) or {}
end

-- returns a list of all non-unused if invert is false, or all unused decorations if invert is true
local filter_unused = function (diagnostics, invert)
  local is_used = function(d)
    local unused = vim.tbl_islist(d) and not detect_unused(d) or not is_unused(d)
    return unused and d.message or nil
  end

  return vim.tbl_filter(function(d)
    if invert then return not is_used(d) end
    return is_used(d)
  end, diagnostics)
end

local create_handler = function (old_handler)
  return {
    show = function (namespace, bufnr, diagnostics, opts)
      diagnostics = filter_unused(diagnostics)
      old_handler.show(namespace, bufnr, diagnostics, opts)
    end,
    hide = old_handler.hide
  }
end

local hide_unused_decorations = function (decorations)
  local handlers_copy = vim.tbl_extend("force", {}, require("vim.diagnostic").handlers) -- gets a copy
  local diag = vim.diagnostic -- updates globally
  for d_handler, enable in pairs(decorations) do
    diag.handlers[d_handler] = enable and create_handler(handlers_copy[d_handler]) or handlers_copy[d_handler]
  end
end

local create_dim_handler = function (namespace)
  local mark_has_diagnostic = function (diagnostics, mark)
    for _, v in ipairs(diagnostics) do
      if v.lnum == mark[2] then return true end
    end
    return false
  end

  local diagnostic_has_mark = function (diagnostic, marks)
    for _, m in ipairs(marks) do
      if diagnostic.lnum == m[2] then return true end
    end
    return false
  end

  local get_missing_diag = function (diagnostics, marks)
    return vim.tbl_filter(function (diagnostic)
      return not diagnostic_has_mark(diagnostic, marks)
    end, diagnostics)
  end

  local add_new_marks = function (diagnostics, marks)
    marks = exists_or_init(marks)
    diagnostics = exists_or_init(diagnostics)
    vim.tbl_map(function (d)
      create_diagnostic_extmark(d.bufnr, namespace, d)
    end, get_missing_diag(diagnostics, marks))
  end

  local show = function(_, bufnr, diagnostics, _)
    if not diagnostics or vim.tbl_isempty(diagnostics) then return end

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
    diagnostics = filter_unused(diagnostics or {}, true)
    -- remove outdated marks
    for index, mark in ipairs(marks) do
      if not mark_has_diagnostic(diagnostics, mark) then
        marks[index] = nil
        vim.api.nvim_buf_del_extmark(bufnr, namespace, mark[1])
      end
    end
    add_new_marks(diagnostics, marks)
  end
  -- dont need a hide function
  return { show = show }
end

dim.setup = function(params)
  local defaults = { hide = { underline = true, virtual_text = true, signs = true } }
  params = vim.tbl_deep_extend("force", defaults, params or {})
  hide_unused_decorations(params.hide)

  dim.ns = vim.api.nvim_create_namespace("dim")
  if params and params.hl then
    vim.api.nvim_set_hl(0, "Unused", params.hl)
    dim.hl = "Unused"
  end

  vim.diagnostic.handlers["dim/unused"] = create_dim_handler(dim.ns)
end

return dim
