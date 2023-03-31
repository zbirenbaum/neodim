local defined_hl = {}

M.semanticHighlighter = function (token, ns)
  local hl = { token.type, unpack(token.modifiers or {}) }
  local hl_name = "@" .. table.concat(hl, ".")
  local ret = hl_name

  while #hl > 1 do
    if defined_hl[hl_name] then
      break
    end
    table.remove(hl)
    local hl_base_name = "@" .. table.concat(hl, ".")
    M.getDimHighlight(ns, 'semantic', hl_name, {
      default = true, link = hl_base_name
    })
    defined_hl[hl_name] = true
    hl_name = hl_base_name
  end
  return ret
end

