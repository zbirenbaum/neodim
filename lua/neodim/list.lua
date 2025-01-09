local M = {}

M.new = function()
  return { [0] = 0 }
end

---@generic T: table
---@param list T
---@return T
M.from_raw = function(list)
  list[0] = #list
  return list
end

---@param list table
---@return integer
M.len = function(list)
  return list[0]
end

---@generic T
---@param list T[]
---@param item T
M.insert = function(list, item)
  local new_len = list[0] + 1
  list[0] = new_len
  list[new_len] = item
end

---@generic T
---@param list T[]
---@param src T[]
M.extend = function(list, src)
  local list_len = list[0]
  local src_len = src[0]
  list[0] = list_len + src_len
  for i = 1, src_len do
    list[list_len + i] = src[i]
  end
end

---@generic T
---@param list T[]
---@return fun(): integer, T
M.iter = function(list)
  local len = list[0]
  local i = 0
  return function()
    i = i + 1
    if i <= len then
      return i, list[i]
    end
  end
end

return M
