local filter = {}

local unusedInString = function (str)
  return str and string.find(
    str,
    ".*[uU]nused.*"
  ) ~= nil
end

local hasUnusedTags = function (tags)
  local target = vim.lsp.protocol.DiagnosticTag.Unnecessary
  return tags and vim.tbl_contains(tags, target)
end

local isUnused = function (diagnostic)
  local userData = vim.tbl_get(
    diagnostic,
    "user_data",
    "lsp"
  ) or {}
  local checkTags = hasUnusedTags(diagnostic.tags) or hasUnusedTags(userData.tags)
  local checkMsg = unusedInString(diagnostic.msg) or unusedInString(userData.code)
  return checkTags or checkMsg
end

local isUsed = function (diagnostic)
  return not isUnused(diagnostic)
end

-- takes a function that returns a boolean
local excludeMatching = function (fn, tbl)
  if vim.tbl_islist(tbl) then
    return vim.tbl_filter(function(d)
      return not fn(d)
    end, tbl)
  end
  return not fn(tbl) and tbl or nil
end


filter.getUsed = function (diagnostics)
  return excludeMatching(isUnused, diagnostics) or {}
end

filter.getUnused = function (diagnostics)
  return excludeMatching(isUsed, diagnostics) or {}
end

return filter
