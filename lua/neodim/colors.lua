local colors = {}

---@param hex_str string
---@return { [1]: integer, [2]: integer, [3]: integer }
colors.hex_to_rgb = function(hex_str)
  local pat = '^#' .. ('(%x%x)'):rep(3) .. '$'
  hex_str = string.lower(hex_str)
  assert(string.find(hex_str, pat) ~= nil, 'hex_to_rgb: invalid hex_str: ' .. tostring(hex_str))
  local red, green, blue = string.match(hex_str, pat)
  return { tonumber(red, 16), tonumber(green, 16), tonumber(blue, 16) }
end

---@param rgb integer
---@return string
colors.rgb_to_hex = function(rgb)
  return ('#%06x'):format(rgb)
end

---@param fg string
---@param bg string
---@param alpha number
---@return string
colors.blend = function(fg, bg, alpha)
  fg = colors.hex_to_rgb(fg) ---@diagnostic disable-line: cast-local-type
  bg = colors.hex_to_rgb(bg) ---@diagnostic disable-line: cast-local-type
  local blend_channel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end
  local res = string.format('#%02X%02X%02X', blend_channel(1), blend_channel(2), blend_channel(3))
  return res
end

return colors
