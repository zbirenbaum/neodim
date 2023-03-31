local highlights = require('neodim.rewrite.highlights')
local filter = require('neodim.rewrite.filter')

local dim = {
  ns = vim.api.nvim_create_namespace("dim"),
}

dim.opts = {
  alpha = 0.75,
  blend_color = "#000000",
  update_in_insert = {
    enable = true,
    delay = 100,
  },
  hide = {
    virtual_text = true,
    signs = true,
    underline = true,
  }
}

local diag = vim.diagnostic

-- @private
local copy_handlers = function ()
  return vim.tbl_extend("force", {}, require("vim.diagnostic").handlers)
end

local create_diagnostic_extmark = function (bufnr, ns, diagnostic)
  return highlights.dimHighlight(bufnr, ns, diagnostic)
end

local extend_handler_by_name = function (handler_name)
  local handler = copy_handlers()[handler_name]
  local current_handler = require('vim.diagnostic').handlers[handler_name]
  handler = {
    show = function (namespace, bufnr, diagnostics, opts)
      diagnostics = filter.getUsed(diagnostics)
      current_handler.show(namespace, bufnr, diagnostics, opts)
    end,
    hide = handler.hide
  }
  return handler
end


dim.create_dim_handler = function (namespace, opts)
  local refresh = function (bufnr)
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, {})) do
      local diagnostics = filter.getUnused(
        diag.get(bufnr, { lnum = m[2] })
      )

      vim.api.nvim_buf_clear_namespace(bufnr, namespace, m[2], m[2]+1)
      for _, d in ipairs(diagnostics) do
        create_diagnostic_extmark(bufnr, namespace, d)
      end

    end
  end

  local show = function(_, bufnr, diagnostics, _)
    if vim.in_fast_event() then return end
    diagnostics = filter.getUnused(diagnostics)
    pcall(refresh, bufnr)
    for _, d in ipairs(diagnostics) do
      pcall(create_diagnostic_extmark, bufnr, namespace, d)
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
        show(_, bufnr, diag.get(bufnr, {}), _)
      end
    end, opts.update_in_insert.delay or 75)
  end

  return {
    show = show,
    hide = opts.update_in_insert.enable and hide or function (_, bufnr)
      refresh(bufnr)
    end
  }
end

dim.setup = function(params)
  params = params or {}
  dim.ns = vim.api.nvim_create_namespace("dim")
  dim.opts = vim.tbl_deep_extend("force", dim.opts, params or {})

  local diag_handlers = diag.handlers

  for handler_name, enable in pairs(dim.opts.hide) do
    if enable then
      diag_handlers[handler_name] = extend_handler_by_name(handler_name)
    end
  end

  vim.diagnostic.handlers["dim/unused"] = dim.create_dim_handler(dim.ns, dim.opts)
end

return dim
