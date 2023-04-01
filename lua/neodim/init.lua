local handlers = require('neodim.handlers')

local dim = {
  update_in_insert = {
    enable = true,
    delay = 75,
  },
  alpha = .75,
  blend_color = "#000000",
  hide = { underline = true, virtual_text = true, signs = true },
  prefer_semantic = true,
  ns = vim.api.nvim_create_namespace('dim'),
}

function dim.setup(opts)
  dim = vim.tbl_extend("force", dim, opts or {})
  dim.blend_color = dim.blend_color:gsub('#', '')
  vim.api.nvim_set_hl_ns(dim.ns)
  handlers.init(dim)
end

return dim
