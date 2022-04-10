local util = require("neodim.util")
local results = {}
setmetatable(results, { __mode = "v" }) -- make values weak
local dim = {}
local hl_map = {}
dim.hl = nil
dim.timer = vim.loop.new_timer()

dim.marks = {}
dim.diag = {}
dim.diagnostics = nil
dim.bufnr = nil

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

local clear_extmarks = function()
  for _, mark in ipairs(dim.marks[dim.bufnr]) do
    vim.api.nvim_buf_del_extmark(dim.bufnr, dim.ns, mark)
  end
  dim.marks[dim.bufnr] = {}
end
local update = function ()
  if not dim.diagnostics or not dim.bufnr then return end
  local filtered = dim.detect_unused(dim.diagnostics)
  dim.diag = filtered
  if not dim.marks[dim.bufnr] then dim.marks[dim.bufnr] = {} end
  local locs = {}
  clear_extmarks()
  for _, diagnostic in ipairs(dim.diag) do
    local ext = create_diagnostic_extmark(dim.bufnr, dim.ns, diagnostic)
    if ext then
      table.insert(locs, format_loc(diagnostic))
      table.insert(dim.marks[dim.bufnr], ext)
    end
  end
end

local create_autocmds_and_timer_start = function ()
  vim.api.nvim_create_autocmd({"TextYankPost"}, {
    callback = function ()
      local current_diag = dim.detect_unused(vim.diagnostic.get(dim.bufnr, {severity = vim.diagnostic.severity.HINT}))
      vim.lsp.buf_notify(dim.bufnr, 'textDocument/didChange')
    end,
    once = false
  })
  vim.api.nvim_create_autocmd({"InsertLeave"}, {
    callback = function ()
      dim.diagnostics= dim.detect_unused(vim.diagnostic.get(dim.bufnr, {severity = vim.diagnostic.severity.HINT}))
      dim.timer:start(0, 100, vim.schedule_wrap(function()
        if not vim.tbl_isempty(dim.diagnostics) then
          update()
        end
      end))
    end,
    once = false
  })
  vim.api.nvim_create_autocmd({"InsertEnter"}, {
    callback = function ()
      dim.diagnostics= dim.detect_unused(vim.diagnostic.get(dim.bufnr, {severity = vim.diagnostic.severity.HINT}))
      vim.schedule(function()
        dim.timer:stop()
      end)
    end,
    once = false
  })
end

dim.setup = function(params)
  dim.ns = vim.api.nvim_create_namespace("dim")
  if params and params.hl then
    vim.api.nvim_set_hl(0, "Unused", params.hl)
    dim.hl = "Unused"
  end
  create_autocmds_and_timer_start()
  vim.diagnostic.handlers["dim/unused"] = {
    show = function(_, bufnr, diagnostics, _)
      dim.diagnostics = diagnostics
      dim.bufnr = bufnr
      vim.schedule(function() update() end)
    end
  }
end

return dim
