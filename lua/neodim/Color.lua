---@class neodim.Color
---@field r number
---@field g number
---@field b number
local Color = {}
---@private
Color.__index = Color

---@private
---@return string
Color.__tostring = function(self)
  return ('#%02x%02x%02x'):format(self.r, self.g, self.b)
end

---@param min number
---@param n number
---@param max number
---@return number
local clamp = function(min, n, max)
  if n < min then
    return min
  elseif max < n then
    return max
  else
    return n
  end
end

---@param r number
---@param g number
---@param b number
---@return self
Color.new = function(r, g, b)
  return setmetatable({
    r = clamp(0, r, 0xFF),
    g = clamp(0, g, 0xFF),
    b = clamp(0, b, 0xFF),
  }, Color)
end

if bit then
  ---@param int number
  ---@return self
  Color.from_int = function(int)
    int = clamp(0, int, 0xFFFFFF)
    return Color.new(bit.rshift(int, 16), bit.band(bit.rshift(int, 8), 0xFF), bit.band(int, 0xFF))
  end
else
  ---@param int number
  ---@return self
  Color.from_int = function(int)
    int = clamp(0, int, 0xFFFFFF)
    return Color.new(math.floor(int / 0x10000), math.floor(int / 0x100) % 0x100, int % 0x100)
  end
end

---@param str string
---@return self
Color.from_str = function(str)
  assert(#str == 7)
  return Color.new(
    assert(tonumber(str:sub(2, 3), 16)),
    assert(tonumber(str:sub(4, 5), 16)),
    assert(tonumber(str:sub(6, 7), 16))
  )
end

---@param x number
---@param y number
---@param a number
---@return number
local blend_channel = function(x, y, a)
  return x * a + y * (1 - a)
end

---@param other neodim.Color
---@param alpha number
---@return self
Color.blend = function(self, other, alpha)
  alpha = clamp(0, alpha, 1)
  return Color.new(
    blend_channel(self.r, other.r, alpha),
    blend_channel(self.g, other.g, alpha),
    blend_channel(self.b, other.b, alpha)
  )
end

return Color
