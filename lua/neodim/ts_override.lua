local TSHighlighter = require 'vim.treesitter.highlighter'
local treesitter = require 'vim.treesitter'
local colors = require 'neodim.colors'
local api = vim.api

local ns = api.nvim_create_namespace 'treesitter/highlighter'

---@class neodim.TSOverride
---@field opts neodim.opts
---@field diagnostics_map (true?)[][]
---@field hl_map table<string, string>
---@field bg string
local TSOverride = {}

---@param opts neodim.opts
---@return neodim.TSOverride
TSOverride.init = function(opts)
  local self = setmetatable({}, {
    __index = TSOverride,
  })

  self.opts = opts
  self.opts.disable = self.opts.disable or {}

  self.diagnostics_map = {}
  self.hl_map = setmetatable({}, { __mode = 'v' })

  self.bg = colors.rgb_to_hex(tonumber(self.opts.blend_color, 16))

  -- these are 'private' but technically accessable
  -- if that every changes, we will have to override the whole TSHighlighter
  ---@diagnostic disable: invisible
  api.nvim_set_decoration_provider(ns, {
    on_buf = TSHighlighter._on_buf,
    on_win = TSHighlighter._on_win,
    on_line = self:set_override(),
    _on_spell_nav = TSHighlighter._on_spell_nav,
  })
  ---@diagnostic enable

  return self
end

---@return function
TSOverride.set_override = function(self)
  ---@param buf integer
  ---@param line integer
  local function on_line(_, _, buf, line)
    local highlighter = TSHighlighter.active[buf]
    if not highlighter then
      return
    end

    self:on_line_impl(highlighter, buf, line)
  end

  return on_line
end

---@param diagnostics Diagnostic[]
---@param bufnr integer
TSOverride.update_unused = function(self, diagnostics, bufnr)
  local ft = api.nvim_get_option_value('filetype', { buf = bufnr })
  if self.opts.disable[ft] then
    return
  end
  self.diagnostics_map = {}
  for _, d in ipairs(diagnostics) do
    self.diagnostics_map[d.lnum] = self.diagnostics_map[d.lnum] or {}
    self.diagnostics_map[d.lnum][d.col] = true
  end
end

---@param self neodim.TSOverride
---@param start_row integer
---@param start_col integer
---@return true?
TSOverride.is_unused = function(self, start_row, start_col)
  return self.diagnostics_map[start_row] and self.diagnostics_map[start_row][start_col]
end

---@param hl vim.api.keyset.highlight
---@param capture_name string
---@return string
TSOverride.get_dim_color = function(self, hl, capture_name)
  if not self.hl_map[capture_name] and hl and hl.fg then
    local fg = colors.rgb_to_hex(hl.fg)
    local color = colors.blend(fg, self.bg, self.opts.alpha)
    hl.fg = color
    local unused_name = '@' .. capture_name .. 'Unused'
    api.nvim_set_hl(0, unused_name, hl)
    self.hl_map[capture_name] = unused_name
  end

  return self.hl_map[capture_name]
end

---@param highlighter TSHighlighter
---@param buf integer
---@param line integer
TSOverride.on_line_impl = function(self, highlighter, buf, line)
  highlighter.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end

    local root_node = tstree:root()
    local root_start_row, _, root_end_row, _ = root_node:range()
    -- Only worry about trees within the line range
    if root_start_row > line or root_end_row < line then
      return
    end
    local state = highlighter:get_highlight_state(tstree)
    local lang = tree:lang()
    local highlighter_query = highlighter:get_query(lang)
    -- Some injected languages may not have highlight queries.
    if not highlighter_query:query() then
      return
    end
    if state.iter == nil or state.next_row < line then
      state.iter = highlighter_query:query():iter_captures(root_node, highlighter.bufnr, line, root_end_row + 1)
    end

    while line >= state.next_row do
      local capture, node, metadata = state.iter()

      if capture == nil then
        break
      end

      local range = treesitter.get_range(node, buf, metadata[capture])
      ---@type integer, integer, integer, integer, integer, integer
      local start_row, start_col, _, end_row, end_col, _ = unpack(range)

      local capture_name = highlighter_query:query().captures[capture]
      local spell = nil ---@type boolean?
      if capture_name == 'spell' then
        spell = true
      elseif capture_name == 'nospell' then
        spell = false
      end

      ---@type integer|string highlight id or highlight name
      local hl = highlighter_query.hl_cache[capture]

      if hl and end_row >= line then
        -- Give nospell a higher priority so it always overrides spell captures.
        local spell_pri_offset = capture_name == 'nospell' and 1 or 0
        local hl_priority = (tonumber(metadata.priority) or vim.highlight.priorities.treesitter) + spell_pri_offset -- Low but leaves room below

        if self:is_unused(start_row, start_col) then
          hl = self:get_dim_color(api.nvim_get_hl(0, { id = hl, link = false }), capture_name)
          hl_priority = self.opts.priority
        end

        api.nvim_buf_set_extmark(buf, ns, start_row, start_col, {
          end_line = end_row,
          end_col = end_col,
          hl_group = hl,
          ephemeral = true,
          priority = hl_priority,
          conceal = metadata.conceal,
          spell = spell,
        })
      end

      if start_row > line then
        state.next_row = start_row
      end
    end
  end)
end

return TSOverride
