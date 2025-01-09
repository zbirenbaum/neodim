local dim = {}

local TSOverride = require 'neodim.TSOverride'
local filter = require 'neodim.filter'
local config = require 'neodim.config'

---@param old_handler vim.diagnostic.Handler
---@param disable table<string, true>
---@return vim.diagnostic.Handler
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

---@param opts neodim.SetupOptions
dim.setup = function(opts)
  config.setup(opts)
  for d_handler, enable in pairs(config.opts.hide) do
    if enable then
      vim.diagnostic.handlers[d_handler] = create_handler(vim.diagnostic.handlers[d_handler], config.opts.disable)
    end
  end
  local ts_override = TSOverride.init()
  vim.diagnostic.handlers['dim/unused'] = {
    show = function(_, bufnr, diagnostics, _)
      ts_override:update_unused(filter.get_unused(diagnostics), bufnr)
    end,
    hide = function(_, bufnr)
      ts_override:update_unused({}, bufnr)
    end,
  }
end

return dim
