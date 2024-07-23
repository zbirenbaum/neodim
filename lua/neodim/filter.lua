local filter = {}

local config = require 'neodim.config'

---@param str string
---@return boolean
local unused_string = function(str)
  local unused_regexes = config.opts.regex

  if not str then
    return false
  end

  str = tostring(str)

  local regexes

  local ft = vim.api.nvim_get_option_value('filetype', { buf = 0 })
  if unused_regexes[ft] then
    ---@cast unused_regexes table<string, string[]>
    -- don't merge global regexes because there is no way to modify global regexes
    regexes = unused_regexes[ft]
  else
    ---@cast unused_regexes string[]
    regexes = unused_regexes
  end

  for _, regex in ipairs(regexes) do
    if str:find(regex) ~= nil then
      return true
    end
  end

  return false
end

---@param diagnostic vim.Diagnostic
---@return boolean
local has_unused_tags = function(diagnostic)
  -- NOTE: `_tags` is available as of Neovim 0.10.0
  return diagnostic._tags and diagnostic._tags.unnecessary or false
end

---@param diagnostic vim.Diagnostic
---@return boolean
local has_unused_string = function(diagnostic)
  return unused_string(diagnostic.message) or diagnostic.code and unused_string(tostring(diagnostic.code)) or false
end

filter.checks = {
  has_unused_tags,
  has_unused_string,
}

---@param diagnostics vim.Diagnostic[]
---@return vim.Diagnostic[]
filter.get_unused = function(diagnostics)
  -- if any check returns true diagnoistic is unused
  local unused_filter = function(d)
    return #vim.tbl_filter(function(check)
      return check(d)
    end, filter.checks) > 0
  end

  return vim.tbl_filter(unused_filter, diagnostics)
end

---@param diagnostics vim.Diagnostic[]
---@return vim.Diagnostic[]
filter.get_used = function(diagnostics)
  -- if all checks return false diagnoistic is used
  local used_filter = function(d)
    return #vim.tbl_filter(function(check)
      return check(d)
    end, filter.checks) == 0
  end

  return vim.tbl_filter(used_filter, diagnostics)
end

return filter
