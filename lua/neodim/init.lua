local dim = {}
local filter = require('neodim.filter')
local ts_override = require('neodim.ts_override')

local default_opts = {
  update_in_insert = {
    enable = true,
    delay = 75,
  },
  alpha = .75,
  blend_color = "#000000",
  hide = { underline = true, virtual_text = true, signs = true },
  prefer_semantic = true,
}

local createHandler = function (old_handler)
  return {
    show = function (namespace, bufnr, diagnostics, opts)
      diagnostics = filter.getUsed(diagnostics)
      old_handler.show(namespace, bufnr, diagnostics, opts)
    end,
    hide = old_handler.hide
  }
end

local hideUnusedDecorations = function (decorations)
  local handlers_copy = vim.tbl_extend("force", {}, require("vim.diagnostic").handlers) -- gets a copy
  local diag = vim.diagnostic -- updates globally
  for d_handler, enable in pairs(decorations) do
    diag.handlers[d_handler] = enable and createHandler(handlers_copy[d_handler]) or handlers_copy[d_handler]
  end
end

local createDimHandlers = function (opts)
  local update_in_insert = opts.update_in_insert

  local show = function(_, _, diagnostics, _)
    local unused_diagnostics = filter.getUnused(diagnostics)
    ts_override.updateUnused(unused_diagnostics)
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
    end, update_in_insert.delay or 75)
  end

  return {
    show = show,
    hide = hide
  }
end

dim.setup = function (opts)
  opts = vim.tbl_extend("force", default_opts, opts or {})
  opts.blend_color = opts.blend_color:gsub('#', '')
  hideUnusedDecorations(opts.hide)
  vim.diagnostic.handlers["dim/unused"] = createDimHandlers(opts)
  ts_override.init(opts)
end

return dim
