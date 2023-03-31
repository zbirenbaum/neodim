local semanticHighlighter = function (token)
  local hl = {token.type, unpack(token.modifiers or {})}
  local hl_name = token.type .. '_Unused'
  local ret = hl_name

  while #hl > 1 do
    if defined_hl[hl_name] then
      break
    end
    table.remove(hl)
    local hl_base_name = "@" .. table.concat(hl, ".")
    vim.api.nvim_set_hl(opts.ns, hl_name, {
      default = true, link = hl_base_name
    })
    defined_hl[hl_name] = true
    hl_name = hl_base_name
  end
  vim.api.nvim_set_hl(opts.ns, ret .. '.Unused', {
    default = true, link = ret
  })
  local unused_hl_name = getDimHighlight(ret, 'semantic_tokens')
  vim.api.nvim_set_hl(opts.ns, ret, {
    default = true, link = unused_hl_name
  })
  return ret
end

