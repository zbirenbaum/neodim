local handlers = {}

local highlight
local filter = require("neodim.filter")

local create_handler = function (old_handler)
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
    diag.handlers[d_handler] = enable and create_handler(handlers_copy[d_handler]) or handlers_copy[d_handler]
  end
end

local createDimHandlers = function ()
  local refresh = function (bufnr)
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, handlers.ns, 0, -1, {})) do
      local diagnostics = vim.diagnostic.get(bufnr, { lnum = m[2] })
      diagnostics = filter.getUnused(diagnostics)
      vim.api.nvim_buf_clear_namespace(bufnr, handlers.ns, m[2], m[2]+1)
      for _, d in ipairs(diagnostics) do
        highlight.create_diagnostic_extmark(bufnr, handlers.ns, d)
      end
    end
  end

  local show = function(_, bufnr, diagnostics, _)
    if vim.in_fast_event() then return end
    diagnostics = filter.getUnused(diagnostics)
    pcall(refresh, bufnr)
    for _, d in ipairs(diagnostics) do
      pcall(highlight.create_diagnostic_extmark, bufnr, handlers.ns, d)
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
      if is_queued and vim.api.nvim_buf_is_valid(bufnr) then
        show(_, bufnr, vim.diagnostic.get(bufnr, {}), _)
      end
    end, handlers.update_in_insert.delay or 75)
  end

  return {
    show = show,
    hide = handlers.update_in_insert.enable and hide or function (_, bufnr)
      refresh(bufnr)
    end
  }
end

handlers.setNamespace = function (name)
  handlers.ns = vim.api.nvim_create_namespace(name or 'dim')
end

handlers.init = function (opts)
  -- handlers.opts = vim.tbl_extend("force", default_opts, opts or {})
  hideUnusedDecorations(opts.hide)
  handlers.opts.blend_color = handlers.opts.blend_color:gsub('#', '')
  handlers.setNamespace(opts.namespace)
  vim.diagnostic.handlers["dim/unused"] = createDimHandlers()
  return handlers
end

return handlers