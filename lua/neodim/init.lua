local dim = {}
local filter = require 'neodim.filter'
---@type neodim.TSOverride
local ts_override

---@class neodim.opts
local default_opts = {
  refresh_delay = 75,
  alpha = 0.75,
  blend_color = '#000000',
  hide = { underline = true, virtual_text = true, signs = true },
  priority = 128,
  disable = {},
}

local create_handler = function(old_handler, disable)
  return {
    show = function(namespace, bufnr, diagnostics, opts)
      local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
      if not disable[ft] then
        diagnostics = filter.get_used(diagnostics)
      end
      old_handler.show(namespace, bufnr, diagnostics, opts)
    end,
    hide = old_handler.hide,
  }
end

---@param opts neodim.opts
local hide_unused_decorations = function(opts)
  local handlers_copy = vim.tbl_extend('force', {}, require('vim.diagnostic').handlers) -- gets a copy
  local diag = vim.diagnostic -- updates globally
  for d_handler, enable in pairs(opts.hide) do
    if enable then
      diag.handlers[d_handler] = create_handler(handlers_copy[d_handler], opts.disable)
    end
  end
end

---@param opts neodim.opts
local create_dim_handlers = function(opts)
  ---@param bufnr integer
  ---@param diagnostics Diagnostic[]
  local show = function(_, bufnr, diagnostics, _)
    local unused_diagnostics = filter.get_unused(diagnostics)
    ts_override:update_unused(unused_diagnostics, bufnr)
  end

  local hide = function(_, bufnr)
    local is_queued = true
    vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChangedP' }, {
      callback = function()
        is_queued = false
      end,
      once = true,
    })

    vim.defer_fn(function()
      if is_queued and vim.api.nvim_buf_is_valid(bufnr) then
        show(_, bufnr, vim.diagnostic.get(bufnr, {}), _)
      end
    end, opts.refresh_delay)
  end

  return {
    show = show,
    hide = hide,
  }
end

---@param opts neodim.opts
dim.setup = function(opts)
  ---@type neodim.opts
  opts = vim.tbl_extend('force', default_opts, opts or {})
  opts.blend_color = opts.blend_color:gsub('#', '')

  for _, language in ipairs(opts.disable or {}) do
    opts.disable[language] = true
  end

  hide_unused_decorations(opts)
  vim.diagnostic.handlers['dim/unused'] = create_dim_handlers(opts)
  ts_override = require('neodim.ts_override').init(opts)
end

return dim
