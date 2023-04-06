local dim = {}
local filter = require('neodim.filter')
local ts_override = require('neodim.ts_override')

local default_opts = {
  refresh_delay = 75,
  alpha = .75,
  blend_color = "#000000",
  hide = { underline = true, virtual_text = true, signs = true },
  disable = {},
}

local hideUnusedDecorations = function (dim_opts)

  local createHandler = function (old_handler)
    return {
      show = function (namespace, bufnr, diagnostics, opts)
        local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
        if not dim_opts.disable[ft] then return end

        diagnostics = filter.getUsed(diagnostics)
        old_handler.show(namespace, bufnr, diagnostics, opts)
      end,
      hide = old_handler.hide
    }
  end

  local handlers_copy = vim.tbl_extend("force", {}, require("vim.diagnostic").handlers) -- gets a copy
  local diag = vim.diagnostic -- updates globally
  for d_handler, enable in pairs(dim_opts.hide) do
    diag.handlers[d_handler] = enable and createHandler(handlers_copy[d_handler]) or handlers_copy[d_handler]
  end
end

local createDimHandlers = function (opts)
  local show = function(_, bufnr, diagnostics, _)
    local unused_diagnostics = filter.getUnused(diagnostics)
    ts_override.updateUnused(unused_diagnostics, bufnr)
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
      if is_queued and vim.api.nvim_buf_is_valid(bufnr) then
        show(_, bufnr, vim.diagnostic.get(bufnr, {}), _)
      end
    end, opts.refresh_delay)
  end

  return {
    show = show,
    hide = hide
  }
end

dim.setup = function (opts)
  opts = vim.tbl_extend("force", default_opts, opts or {})
  opts.blend_color = opts.blend_color:gsub('#', '')
  for _, language in ipairs(opts.disable or {}) do
    opts.disable[language] = true
  end

  hideUnusedDecorations(opts)
  vim.diagnostic.handlers["dim/unused"] = createDimHandlers(opts)
  ts_override.init(opts)
end

return dim
