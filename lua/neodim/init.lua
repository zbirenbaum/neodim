local dim = {}
local filter = require 'neodim.filter'
local config = require 'neodim.config'
---@type neodim.TSOverride Initialize in dim.setup()
local ts_override

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

local hide_unused_decorations = function()
  local handlers_copy = vim.tbl_extend('force', {}, require('vim.diagnostic').handlers) -- gets a copy
  local diag = vim.diagnostic -- updates globally
  for d_handler, enable in pairs(config.opts.hide) do
    if enable then
      diag.handlers[d_handler] = create_handler(handlers_copy[d_handler], config.opts.disable)
    end
  end
end

local create_dim_handlers = function()
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
    end, config.opts.refresh_delay)
  end

  return {
    show = show,
    hide = hide,
  }
end

dim.setup = function(opts)
  config.setup(opts)
  hide_unused_decorations()
  vim.diagnostic.handlers['dim/unused'] = create_dim_handlers()
  ts_override = require('neodim.ts_override').init()
end

return dim
