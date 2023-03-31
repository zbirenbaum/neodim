local config = {
  opts = {
    update_in_insert = true,
    delay = 75,
    alpha = .75,
    blend_color = "000000",
    hide = { underline = true, virtual_text = true, signs = true },
    prefer_semantic = true,
    ns = vim.api.nvim_create_namespace('dim'),
  }
}

config.get = function ()
  return config.opts
end

config.init = function (opts)
  config.opts = vim.tbl_extend("force", config.opts, opts or {})
  config.opts.blend_color = config.opts.blend_color:gsub('#', '')
  config.opts.namespace = vim.api.nvim_create_namespace('dim')
  vim.api.nvim_set_hl_ns(config.opts.ns)
  return config.get()
end

return config
