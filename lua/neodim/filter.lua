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

--- @param diagnostic table
--  @param isused boolean

function filter.used (diagnostic, isused)
  local result = function (unused)
    if isused then
      return not unused
    end
    return unused
  end

  local userData = vim.tbl_get(
    diagnostic,
    "user_data",
    "lsp"
  ) or {}

  local checkTags = hasUnusedTags(diagnostic.tags) or hasUnusedTags(userData.tags)
  if checkTags then return result(checkTags) end

  local checkMsg = unusedInString(diagnostic.msg) or unusedInString(userData.code)
  if checkMsg then return result(checkMsg) end
end

filter.getUnused = function (diagnostics)
  return vim.tbl_filter(function (d)
    return filter.used(d, false)
  end, diagnostics)
end

filter.getUsed = function (diagnostics)
  return vim.tbl_filter(function (d)
    return filter.used(d, true)
  end, diagnostics)
end

return filter
