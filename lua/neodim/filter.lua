local filter = {}

---@param str string
---@return boolean
local unusedString = function(str)
  return str and string.find(str, '.*[uU]nused.*') ~= nil
end

---@param diagnostic Diagnostic
---@return boolean
local hasUnusedTags = function(diagnostic)
  -- NOTE: `_tags` is available as of Neovim 0.10.0
  return diagnostic._tags and diagnostic._tags.unnecessary
end

---@param diagnostic Diagnostic
---@return boolean
local hasUnusedString = function(diagnostic)
  return unusedString(diagnostic.message) or unusedString(diagnostic.code)
end

filter.checks = {
  hasUnusedTags,
  hasUnusedString,
}

---@param diagnostics Diagnostic[]
---@return Diagnostic[]
filter.getUnused = function(diagnostics)
  -- if any check returns true diagnoistic is unused
  local unusedFilter = function(d)
    return #vim.tbl_filter(function(check)
      return check(d)
    end, filter.checks) > 0
  end

  return vim.tbl_filter(function(d)
    return unusedFilter(d)
  end, diagnostics)
end

---@param diagnostics Diagnostic[]
---@return Diagnostic[]
filter.getUsed = function(diagnostics)
  -- if all checks return false diagnoistic is used
  local usedFilter = function(d)
    return #vim.tbl_filter(function(check)
      return check(d)
    end, filter.checks) == 0
  end

  return vim.tbl_filter(function(d)
    return usedFilter(d)
  end, diagnostics)
end

return filter
