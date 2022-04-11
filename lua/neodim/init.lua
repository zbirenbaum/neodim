local util = require("neodim.util")
local results = {}
setmetatable(results, { __mode = "v" }) -- make values weak
local dim = {}
local hl_map = {}

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

local format_loc_ext = function (diagnostic)
  return { diagnostic.lnum, diagnostic.col }
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
  return is_list and vim.tbl_filter(unused, diagnostics) or unused(diagnostics) or {}
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
    priority = 300,
    end_right_gravity = true,
    strict = false,
  })
end

local mark_in_diagnostics = function (mark, diagnostic_locs)
  for _, v in ipairs(diagnostic_locs) do
    if v[1] == mark[2] and v[2] == mark[3] then return true end
  end
  return false
end

local clear_extmarks = function(bufnr, diagnostics, buf_marks)
  local diagnostic_locs = vim.tbl_map(format_loc_ext, diagnostics)
  local new_marks = vim.tbl_filter(function(mark)
    if mark_in_diagnostics(mark, diagnostic_locs) then return true
    else
      vim.api.nvim_buf_del_extmark(bufnr, dim.ns, mark[1])
      return false
    end
  end, buf_marks)
  return new_marks
end

local update = function (bufnr, filtered, buf_marks)
  local marks_in_diagnostics = clear_extmarks(bufnr, filtered, buf_marks)
  for _, diagnostic in ipairs(filtered) do
    local marks_in_diagnostics_locs = vim.tbl_map(function(mark) return { mark[2], mark[3] } end, marks_in_diagnostics)
    if not vim.tbl_contains(marks_in_diagnostics_locs, { diagnostic.lnum, diagnostic.col }) then
      create_diagnostic_extmark(bufnr, dim.ns, diagnostic)
    end
  end
end

local create_autocmds_and_timer_start = function (timer_debounce)
  vim.api.nvim_create_autocmd({"TextYankPost"}, {
    callback = function ()
      vim.lsp.buf_notify(dim.bufnr, 'textDocument/didChange')
    end,
    once = false
  })
  if vim.bo.filetype ~= "python" then
    vim.api.nvim_create_autocmd({"InsertLeave"}, {
      callback = vim.schedule_wrap(function ()
        dim.timer:start(0, timer_debounce, vim.schedule_wrap(function()
          local diagnostics = vim.diagnostic.get(0, {})
          local buf_marks = vim.api.nvim_buf_get_extmarks(0, dim.ns, 0, -1, {})
          clear_extmarks(vim.api.nvim_get_current_buf(), diagnostics, buf_marks)
          vim.lsp.buf_notify(dim.bufnr, 'textDocument/didChange')
        end))
      end),
      once = false
    })
  end
  vim.api.nvim_create_autocmd({"InsertEnter"}, {
    callback = vim.schedule_wrap(function ()
      dim.timer:stop()
    end),
    once = false
  })
end

dim.setup = function(params)
  dim.ns = vim.api.nvim_create_namespace("dim")
  if params and params.hl then
    vim.api.nvim_set_hl(0, "Unused", params.hl)
    dim.hl = "Unused"
  end
  local timer_debounce = params and params.timer_debounce or 200
  dim.timer = vim.loop.new_timer()
  dim.marks = {}
  create_autocmds_and_timer_start(timer_debounce)
  vim.diagnostic.handlers["dim/unused"] = {
    show = function(_, bufnr, diagnostics, _)
      dim.marks[bufnr] = dim.marks[bufnr] or {}
      dim.marks[bufnr] = vim.api.nvim_buf_get_extmarks(bufnr, dim.ns, 0, -1, {})
      local filtered = dim.detect_unused(diagnostics)
      vim.schedule(function() update(bufnr, filtered, dim.marks[bufnr]) end)
    end
  }
end

return dim
