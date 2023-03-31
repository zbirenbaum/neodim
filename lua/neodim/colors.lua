local colors = {}

colors.hex_to_rgb = function(hex_str)
  local hex = "[abcdef0-9][abcdef0-9]"
  local pat = "^#(" .. hex .. ")(" .. hex .. ")(" .. hex .. ")$"
  hex_str = string.lower(hex_str)
  assert(string.find(hex_str, pat) ~= nil, "hex_to_rgb: invalid hex_str: " .. tostring(hex_str))
  local red, green, blue = string.match(hex_str, pat)
  return { tonumber(red, 16), tonumber(green, 16), tonumber(blue, 16) }
end

colors.rgb_to_hex = function (rgb)
  local val = string.format("%02X", bit.band(rgb, 0xFFFFFF))
  if #val < 6 then
    val = string.rep("0", 6 - #val) .. val
  end
  return string.format("#%s", val)
end

colors.format_rgb = function (value)
  return colors.hex_to_rgb()
end

colors.blend = function(fg, bg, alpha)
  fg = colors.hex_to_rgb(fg)
  bg = colors.hex_to_rgb(bg)
  local blendChannel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end
  local res = string.format("#%02X%02X%02X", blendChannel(1), blendChannel(2), blendChannel(3))
  return res
end

return colors
