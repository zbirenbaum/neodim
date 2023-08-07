local filter = {}

---@param str string
---@return boolean
local unusedString = function(str)
  return str and string.find(str, '.*[uU]nused.*') ~= nil
end

---@param tags table
---@return boolean
local unusedTags = function(tags)
  local target = vim.lsp.protocol.DiagnosticTag.Unnecessary
  return tags and vim.tbl_contains(tags, target)
end

---@param diagnostic Diagnostic
---@return table
local getUserData = function(diagnostic)
  return vim.tbl_get(diagnostic, 'user_data', 'lsp') or {}
end

---@param diagnostic Diagnostic
---@return boolean
local hasUnusedTags = function(diagnostic)
  local userdata = getUserData(diagnostic)
  -- FIXME: `tags` is an undefined field
  return unusedTags(diagnostic.tags) or unusedTags(userdata.tags)
end

---@param diagnostic Diagnostic
---@return boolean
local hasUnusedString = function(diagnostic)
  local userdata = getUserData(diagnostic)
  -- FIXME: `msg` is an undefined field
  return unusedString(diagnostic.msg) or unusedString(userdata.code)
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
