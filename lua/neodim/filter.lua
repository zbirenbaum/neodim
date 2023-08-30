local filter = {}

local unused_regexes = {
  '.*[uU]nused.*',
  '.*[nN]ever [rR]ead.*',
  '.*[nN]ot [rR]ead.*',
}

---@param tbl table
---@param fn function
---@return boolean
local any = function(tbl, fn)
  for _, v in ipairs(tbl) do
    if fn(v) then return true end
  end
  return false
end

---@param str string
---@return boolean
local unused_string = function(str)
  return str and any(unused_regexes, function(regex)
    return string.find(str, regex) ~= nil
  end)
end

---@param diagnostic Diagnostic
---@return boolean
local has_unused_tags = function(diagnostic)
  -- NOTE: `_tags` is available as of Neovim 0.10.0
  return diagnostic._tags and diagnostic._tags.unnecessary
end

---@param diagnostic Diagnostic
---@return boolean
local has_unused_string = function(diagnostic)
  return unused_string(diagnostic.message) or unused_string(diagnostic.code)
end

filter.checks = {
  has_unused_tags,
  has_unused_string,
}

---@param diagnostics Diagnostic[]
---@return Diagnostic[]
filter.get_unused = function(diagnostics)
  -- if any check returns true diagnoistic is unused
  local unused_filter = function(d)
    return #vim.tbl_filter(function(check)
      return check(d)
    end, filter.checks) > 0
  end

  return vim.tbl_filter(function(d)
    return unused_filter(d)
  end, diagnostics)
end

---@param diagnostics Diagnostic[]
---@return Diagnostic[]
filter.get_used = function(diagnostics)
  -- if all checks return false diagnoistic is used
  local used_filter = function(d)
    return #vim.tbl_filter(function(check)
      return check(d)
    end, filter.checks) == 0
  end

  return vim.tbl_filter(function(d)
    return used_filter(d)
  end, diagnostics)
end

return filter
