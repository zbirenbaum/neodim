local handlers = {}
local filter = require("neodim.filter")
local highlighter = require('neodim.highlights')

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

local createDimHandlers = function (opts)
  local update_in_insert = opts.update_in_insert
  local ns = opts.ns
  local hl_opts = {
    blend_color = opts.blend_color,
    alpha = opts.alpha,
    ns = opts.ns
  }

  local refresh = function (bufnr)
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
      local diagnostics = filter.getUnused(vim.diagnostic.get(bufnr, {
        lnum = m[2]
      }))
      vim.api.nvim_buf_clear_namespace(bufnr, ns, m[2], m[2]+1)
      for _, d in ipairs(diagnostics) do
        highlighter.highlightDiagnostic(d, hl_opts)
      end
    end
  end

  local show = function(_, bufnr, diagnostics, _)
    if vim.in_fast_event() then return end
    diagnostics = filter.getUnused(diagnostics)
    for _, d in ipairs(diagnostics) do
      highlighter.highlightDiagnostic(d, hl_opts)
    end
    refresh(bufnr)
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
    hide = update_in_insert.enable and hide or function ()
      refresh(0)
    end
  }
end

handlers.init = function (opts)
  hideUnusedDecorations(opts.hide)
  vim.diagnostic.handlers["dim/unused"] = createDimHandlers(opts)
  return handlers
end

return handlers
