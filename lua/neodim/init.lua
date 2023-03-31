local dim = {}

dim.setup = function (params)
  local config = require("neodim.opts").init(params)
  config.colors = require("neodim.colors")
  local highlights = require("neodim.highlights").init(config)
  local handlers = require('neodim.handlers').init(config, highlights)
end

return dim
