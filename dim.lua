local util = require("neodim.dim_hl")

local results = {}
setmetatable(results, { __mode = "v" }) -- make values weak
local dim = {}
local hl_map = {}

local bufnr_and_namespace_cacher_mt = {
  __index = function(t, bufnr)
    assert(bufnr > 0, "Invalid buffer number")
    t[bufnr] = {}
    return t[bufnr]
  end,
}
local dimmed_cache_extmarks = setmetatable({}, bufnr_and_namespace_cacher_mt)
local diagnostic_attached_buffers = {}

local function restore_extmarks(bufnr, last)
  for ns, extmarks in pairs(dimmed_cache_extmarks[bufnr]) do
    local extmarks_current = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    local found = {}
    for _, extmark in ipairs(extmarks_current) do
      if extmark[2] ~= last + 1 then
        found[extmark[1]] = true
      end
    end
    for _, extmark in ipairs(extmarks) do
      if not found[extmark[1]] then
        local opts = extmark[4]
        opts.id = extmark[1]
        pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, extmark[2], extmark[3], opts)
      end
    end
  end
end

local function save_extmarks(namespace, bufnr)
  if not diagnostic_attached_buffers[bufnr] then
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, _, _, _, _, last)
        restore_extmarks(bufnr, last - 1)
      end,
      on_detach = function()
        dimmed_cache_extmarks[bufnr] = nil
      end,
    })
    diagnostic_attached_buffers[bufnr] = true
  end
  dimmed_cache_extmarks[bufnr][namespace] = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
end

local function get_ts_group(bufnr, ns, lnum, col, end_col)
  local ts_group = util.get_treesitter_nodes(bufnr, ns, lnum, col, end_col)
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
    return
  end
  local hl = vim.api.nvim_get_hl_by_name(ts_group, true)
  local color = string.format("#%x", hl["foreground"] or 0)
  if #color ~= 7 then
    color = "#ffffff"
  end
  hl_map[unused_group] = { fg = darkened(color), undercurl = false, underline = false }
end

dim.highlight_diagnostics = function(bufnr, ns, filtered)
  for _, diagnostic in ipairs(filtered) do
    local ts_group = get_ts_group(bufnr, ns, diagnostic.lnum, diagnostic.col, diagnostic.end_col)
    if ts_group == nil then
      return
    end
    set_unused_group(ts_group)
  end
  for unused_group, hl in pairs(hl_map) do
    vim.schedule_wrap(vim.api.nvim_set_hl(ns, unused_group, hl))
  end
end

dim.ignore_vtext = function(diagnostic)
  return not dim.detect_unused(diagnostic) and diagnostic.message or nil
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

dim.setup = function()
  local ns = vim.api.nvim_create_namespace("dim")
  vim.diagnostic.handlers["dim/unused"] = {
    show = function(_, bufnr, diagnostics, _)
      vim.api.nvim__set_hl_ns(ns)
      local filtered = dim.detect_unused(diagnostics)
      if type(filtered) ~= "table" then
        return
      end --buffer lsp not supported
      dim.highlight_diagnostics(bufnr, ns, filtered)
      save_extmarks(ns, bufnr)
    end,
    hide = function(_, bufnr, _, _)
      dimmed_cache_extmarks[bufnr][ns] = {}
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end,
  }
end

return dim
