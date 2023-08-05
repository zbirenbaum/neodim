local TSHighlighter = require 'vim.treesitter.highlighter'
local treesitter = require 'vim.treesitter'
local colors = require 'neodim.colors'
local api = vim.api
local TSOverride = {}
local linemap = {}
local diagnostic_nodes = {}
local hl_map = setmetatable({}, { __mode = 'v' })

local ns = api.nvim_create_namespace 'treesitter/highlighter'
local function set_override(opts)
  local priority = opts.priority
  local bg = colors.rgb_to_hex(tonumber(opts.blend_color, 16))
  local function on_line_impl(self, buf, line, is_spell_nav)
    self.tree:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end
      local root_node = tstree:root()
      local root_start_row, _, root_end_row, _ = root_node:range()
      -- Only worry about trees within the line range
      if root_start_row > line or root_end_row < line then
        return
      end
      local state = self:get_highlight_state(tstree)
      local lang = tree:lang()
      local highlighter_query = self:get_query(lang)
      -- Some injected languages may not have highlight queries.
      if not highlighter_query:query() then
        return
      end
      if state.iter == nil or state.next_row < line then
        state.iter = highlighter_query:query():iter_captures(root_node, self.bufnr, line, root_end_row + 1)
      end

      while line >= state.next_row do
        local capture, node, metadata = state.iter()
        if capture == nil then
          break
        end
        local range = treesitter.get_range(node, buf, metadata[capture])
        local start_row, start_col, _, end_row, end_col, _ = unpack(range)
        local hl = highlighter_query.hl_cache[capture]
        local capture_name = highlighter_query:query().captures[capture]

        local spell = nil ---@type boolean?
        spell = capture_name == 'spell' and true or capture_name == 'nospell' and false

        -- Give nospell a higher priority so it always overrides spell captures.
        local spell_pri_offset = capture_name == 'nospell' and 1 or 0

        if hl and end_row >= line and (not is_spell_nav or spell ~= nil) then
          if linemap[start_row] and linemap[start_row][start_col] then
            linemap[start_row][start_col] = node
            local cur_hl = vim.api.nvim_get_hl(0, { id = hl, link = false })

            if not hl_map[capture_name] and cur_hl and cur_hl.fg then
              local fg = colors.rgb_to_hex(cur_hl.fg)
              local color = colors.blend(fg, bg, opts.alpha)
              cur_hl.fg = color
              local unused_name = '@' .. capture_name .. 'Unused'
              vim.api.nvim_set_hl(0, unused_name, cur_hl)
              hl_map[capture_name] = unused_name
            end

            diagnostic_nodes[node] = {
              start_row = start_row,
              start_col = start_col,
              hl = hl_map[capture_name],
            }
          end
          local hl_priority = (tonumber(metadata.priority) or 100) + spell_pri_offset -- Low but leaves room below

          if diagnostic_nodes[node] then
            hl = diagnostic_nodes[node].hl
            -- only affect priority when there is a diagnostic node
            hl_priority = priority
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

  local function _on_line(_, _, buf, line, _)
    local self = TSHighlighter.active[buf]
    if not self then
      return
    end

    on_line_impl(self, buf, line, false)
  end

  return _on_line
end

TSOverride.init = function(opts)
  local disable = opts.disable or {}

  TSOverride.updateUnused = function(diagnostics, bufnr)
    linemap = {}
    diagnostic_nodes = {}
    local ft = vim.api.nvim_get_option_value('filetype', {
      buf = bufnr,
    })
    if disable[ft] then
      return
    end
    for _, d in ipairs(diagnostics) do
      linemap[d.lnum] = linemap[d.lnum] or {}
      linemap[d.lnum][d.col] = {}
    end
  end
  -- these are 'private' but technically accessable
  -- if that every changes, we will have to override the whole TSHighlighter
  ---@diagnostic disable: invisible
  api.nvim_set_decoration_provider(ns, {
    on_buf = TSHighlighter._on_buf,
    on_win = TSHighlighter._on_win,
    on_line = set_override(opts),
    _on_spell_nav = TSHighlighter._on_spell_nav,
  })
  ---@diagnostic enable
end

return TSOverride
