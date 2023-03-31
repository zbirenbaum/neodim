local dim = {}

local config = require("neodim.config")
local handlers = require('neodim.handlers')

dim.setup = function (params)
  config.init()
  -- handlers.init(config.get())
end

return dim
