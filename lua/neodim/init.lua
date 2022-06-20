local util = require("neodim.util")
local results = {}

setmetatable(results, { __mode = "v" }) -- make values weak
local dim = {
  marks = {},
  hl_map = {},
  opts = {
    blend_color = "#000000",
    alpha = .75,
    hide = { underline = true, virtual_text = true, signs = true }
  }
}

local exists_or_init = function (t) return t or {} end

local function get_ts_group(bufnr, lnum, col, end_col)
  local ts_group = util.get_treesitter_nodes(bufnr, lnum, col, end_col)
  ts_group = type(ts_group) == "string" and ts_group or nil
  return ts_group
end

dim.get_unused_group = function(ts_group)
  local darkened = function(color)
    if not results[color] then
      results[color] = util.darken(color, dim.opts.alpha, dim.opts.blend_color)
    end
    return results[color]
  end
  local unused_group = string.format("%sUnused", ts_group)
  if dim.hl_map[unused_group] then
    return unused_group
  end
  local hl = vim.api.nvim_get_hl_by_name(ts_group, true)
  local color = string.format("#%x", hl["foreground"] or 0)
  if #color ~= 7 then
    color = "#ffffff"
  end
  dim.hl_map[unused_group] = { fg = darkened(color), undercurl = false, underline = false }
  vim.api.nvim_set_hl(0, unused_group, dim.hl_map[unused_group])
  return unused_group
end

dim.get_hl = function (diagnostic)
  local ts_group = get_ts_group(diagnostic.bufnr, diagnostic.lnum, diagnostic.col, diagnostic.end_col)
  if not ts_group then return end
  return dim.get_unused_group(ts_group)
end

dim.create_diagnostic_extmark = function (bufnr, ns, diagnostic)
  local hl = dim.get_hl(diagnostic)
  if not hl then return end
  return vim.api.nvim_buf_set_extmark(bufnr, ns, diagnostic.lnum, diagnostic.col, {
    end_line = diagnostic.lnum,
    end_col = diagnostic.end_col,
    hl_group = hl,
    priority = 200,
    end_right_gravity = true,
    strict = false,
  })
end

dim.move_diagnostic_extmark = function (bufnr, ns, diagnostic, mark)
  local hl = dim.get_hl(diagnostic)
  if not hl then return end
  return vim.api.nvim_buf_set_extmark(bufnr, ns, diagnostic.lnum, diagnostic.col, {
    id = mark.id,
    end_line = diagnostic.lnum,
    end_col = diagnostic.end_col,
    hl_group = hl,
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

dim.create_dim_handler = function (namespace)
  local mark_has_diagnostic = function (diagnostics, mark)
    for _, v in ipairs(diagnostics) do
      if v.lnum == mark[2] and math.abs(v.end_col - mark[3]) <= 1 then
        return true
      end
    end
    return false
  end

  local diagnostic_has_mark = function (diagnostic, marks)
    for _, m in ipairs(marks) do
      if diagnostic.lnum == m[2] and math.abs(diagnostic.end_col - m[3]) <= 1 then
        return true
      end
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
    return vim.tbl_map(function (d)
      return dim.create_diagnostic_extmark(d.bufnr, namespace, d)
    end, get_missing_diag(diagnostics, marks))
  end

  local refresh = function (bufnr)
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, {})) do
      local diagnostics = filter_unused(vim.diagnostic.get(bufnr, {
        lnum = m[2]
      }), true)
      vim.api.nvim_buf_clear_namespace(bufnr, namespace, m[2], m[2]+1)
      for _, d in ipairs(diagnostics) do
        dim.create_diagnostic_extmark(bufnr, namespace, d)
      end
    end
  end

  local show = function(_, bufnr, diagnostics, _)
    if vim.in_fast_event() then return end
    diagnostics = filter_unused(diagnostics, true)
    refresh(bufnr)
    for _, d in ipairs(diagnostics) do
      dim.create_diagnostic_extmark(bufnr, namespace, d)
    end
  end

  local hide = function(_, bufnr)
    local is_queued = true
    vim.api.nvim_create_autocmd({"TextChangedI", "TextChangedP"}, {
      callback = function ()
        is_queued = false
      end,
      once = true,
    })
    vim.defer_fn(function ()
      if is_queued then
        show(_, bufnr, vim.diagnostic.get(bufnr, {}), _)
      end
    end, 100)
  end

  return { show = show, hide = hide}
end

dim.setup = function(params)
  dim.opts = vim.tbl_deep_extend("force", dim.opts, params or {})
  hide_unused_decorations(dim.opts.hide)

  dim.ns = vim.api.nvim_create_namespace("dim")
  vim.diagnostic.handlers["dim/unused"] = dim.create_dim_handler(dim.ns)
end

return dim
