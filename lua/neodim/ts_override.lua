local TSHighlighter = vim.treesitter.highlighter
local Range = vim.treesitter._range

local colors = require 'neodim.colors'
local lsp = require 'neodim.lsp'
local opts = require('neodim.config').opts

local NAMESPACE = vim.api.nvim_create_namespace 'treesitter/highlighter'

---@class neodim.ColumnRange
---@field start_col integer
---@field end_col integer

---@class neodim.TSOverride
---@field diagnostics_map table<buffer, table<integer, neodim.ColumnRange[]>>
---@field hl_map table<string, string>
local TSOverride = {}
---@private
TSOverride.__index = TSOverride

---@return self
TSOverride.init = function()
  ---@type neodim.TSOverride
  local self = {
    diagnostics_map = {},
    hl_map = setmetatable({}, { __mode = 'v' }),
  }
  setmetatable(self, TSOverride)

  -- these are 'private' but technically accessible
  -- if that every changes, we will have to override the whole TSHighlighter
  vim.api.nvim_set_decoration_provider(NAMESPACE, {
    on_win = TSHighlighter._on_win, ---@diagnostic disable-line: invisible
    on_line = self:set_override(),
    _on_spell_nav = TSHighlighter._on_spell_nav, ---@diagnostic disable-line: invisible
  })

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

---@param diagnostics vim.Diagnostic[]
---@param bufnr integer
TSOverride.update_unused = function(self, diagnostics, bufnr)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    self.diagnostics_map[bufnr] = nil
    return
  end
  local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  if opts.disable[ft] then
    self.diagnostics_map[bufnr] = nil
    return
  end

  self.diagnostics_map[bufnr] = {}

  for _, diagnostic in ipairs(diagnostics) do
    local start_row, start_col = diagnostic.lnum, diagnostic.col
    local end_row = diagnostic.end_lnum or start_row
    local end_col = diagnostic.end_col or start_col

    for row = start_row, end_row do
      local range ---@type neodim.ColumnRange
      if start_row == end_row then
        range = { start_col = start_col, end_col = end_col }
      elseif row == start_row then
        range = { start_col = start_col, end_col = math.huge }
      elseif row == end_row then
        range = { start_col = 0, end_col = end_col }
      else
        range = { start_col = 0, end_col = math.huge }
      end

      self.diagnostics_map[bufnr][row] = self.diagnostics_map[bufnr][row] or {}
      table.insert(self.diagnostics_map[bufnr][row], range)
    end
  end
end

---@param row integer
---@param col integer
---@return boolean
TSOverride.is_unused = function(self, bufnr, row, col)
  if not self.diagnostics_map[bufnr] or not self.diagnostics_map[bufnr][row] then
    return false
  end
  for _, range in ipairs(self.diagnostics_map[bufnr][row]) do
    if range.start_col <= col and col <= range.end_col then
      return true
    end
  end
  return false
end

---@param hl vim.api.keyset.highlight
---@param hl_name string
---@return string
TSOverride.get_dim_color = function(self, hl, hl_name)
  if not self.hl_map[hl_name] and hl and hl.fg then
    local fg = colors.rgb_to_hex(hl.fg)
    local color = colors.blend(fg, opts.blend_color, opts.alpha)
    hl.fg = color
    local unused_name = hl_name .. 'Unused'
    vim.api.nvim_set_hl(0, unused_name, hl)
    self.hl_map[hl_name] = unused_name
  end

  return self.hl_map[hl_name]
end

---@param mark vim.api.keyset.set_extmark
---@param buf integer
---@param start_row integer
---@param start_col integer
---@return boolean
TSOverride.override_mark_with_lsp = function(self, mark, buf, start_row, start_col)
  local sttoken_mark_data = lsp.get_sttoken_mark_data(buf, start_row, start_col)
  if sttoken_mark_data and self:is_unused(buf, start_row, start_col) then
    mark.hl_group = self:get_dim_color(sttoken_mark_data.hl_opts, sttoken_mark_data.hl_name)
    mark.priority = opts.priority
    return true
  end
  return false
end

---@param mark vim.api.keyset.set_extmark
---@param buf integer
---@param start_row integer
---@param start_col integer
---@param hl_query vim.treesitter.highlighter.Query
---@param capture integer
---@param metadata vim.treesitter.query.TSMetadata
---@return boolean
TSOverride.override_mark_with_ts = function(self, mark, buf, start_row, start_col, hl_query, capture, metadata)
  ---@diagnostic disable-next-line: invisible
  local hl = hl_query:get_hl_from_capture(capture)
  if not hl or hl == 0 then
    return false
  end
  ---@diagnostic disable-next-line: invisible
  local capture_name = hl_query:query().captures[capture]

  if self:is_unused(buf, start_row, start_col) then
    mark.hl_group = self:get_dim_color(
      vim.api.nvim_get_hl(0, { id = hl, link = false }) --[[@as vim.api.keyset.highlight]],
      '@' .. capture_name
    )
    mark.priority = opts.priority
  else
    mark.hl_group = hl
    mark.priority = (tonumber(metadata.priority) or vim.highlight.priorities.treesitter)
      + (capture_name == 'nospell' and 1 or 0)
  end

  if capture_name == 'spell' then
    mark.spell = true
  elseif capture_name == 'nospell' then
    mark.spell = false
  end

  return true
end

---@param highlighter vim.treesitter.highlighter
---@param buf integer
---@param line integer
TSOverride.on_line_impl = function(self, highlighter, buf, line)
  ---@diagnostic disable-next-line: invisible
  highlighter:for_each_highlight_state(function(state)
    local root_node = state.tstree:root()

    local root_start_row, _, root_end_row, _ = root_node:range()
    if line < root_start_row or root_end_row < line then
      return
    end

    if state.iter == nil or state.next_row < line then
      ---@diagnostic disable-next-line: invisible
      state.iter = state.highlighter_query:query():iter_captures(root_node, highlighter.bufnr, line, root_end_row + 1)
    end

    while state.next_row <= line do
      local capture, node, metadata = state.iter()

      if capture == nil then
        break
      end

      local range = vim.treesitter.get_range(node, buf, metadata[capture])
      ---@type integer, integer, integer, integer
      local start_row, start_col, end_row, end_col = Range.unpack4(range)

      if line <= end_row then
        ---@type vim.api.keyset.set_extmark
        local mark = {
          end_line = end_row,
          end_col = end_col,
          ephemeral = true,
          conceal = metadata.conceal,
        }
        if
          self:override_mark_with_lsp(mark, buf, start_row, start_col)
          or self:override_mark_with_ts(mark, buf, start_row, start_col, state.highlighter_query, capture, metadata)
        then
          vim.api.nvim_buf_set_extmark(buf, NAMESPACE, start_row, start_col, mark)
        end
      end

      if line < start_row then
        state.next_row = start_row
      end
    end
  end)
end

return TSOverride
