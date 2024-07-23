local api = vim.api

local lsp = {}

---@alias extmark_data { priority: integer, hl_name: string, hl_opts: table }?

---@class extmark
---@field [1] integer mark ID
---@field [2] integer row
---@field [3] integer column
---@field [4] extmark_details

---@class extmark_details
---@field hl_group string
---@field priority integer
---@field end_col integer
---@field end_row integer

---@param buf buffer
---@param token_range STTokenRange
---@return extmark[]
local function get_sttoken_extmarks(buf, token_range)
  -- NOTE: vim.lsp.get_active_clients() was renamed to get_clients() and deprecated on Neovim v0.10
  ---@diagnostic disable-next-line: deprecated
  local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
  ---@type integer[]
  local client_ids = vim.tbl_map(
    ---@param client vim.lsp.Client
    function(client)
      return client.id
    end,
    get_clients { bufnr = buf }
  )

  ---@type extmark[]
  local extmarks = {}
  for name, ns_id in pairs(vim.api.nvim_get_namespaces()) do
    local client_id = name:match 'vim_lsp_semantic_tokens:(%d+)'
    if client_id and vim.tbl_contains(client_ids, tonumber(client_id)) then
      ---@type extmark[]
      local marks = api.nvim_buf_get_extmarks(
        buf,
        ns_id,
        { token_range.line, token_range.start_col },
        { token_range.line, token_range.end_col },
        { type = 'highlight', details = true }
      )
      vim.list_extend(extmarks, marks)
    end
  end

  return extmarks
end

---@param extmarks extmark[]
---@return extmark_data
local function get_max_pri_extmark(extmarks)
  local priority = 0
  local hl_name
  local hl_opts

  for _, extmark in ipairs(extmarks) do
    local details = extmark[4]
    local _hl_opts = api.nvim_get_hl(0, { name = details.hl_group, link = false })
    if details.priority > priority and not vim.tbl_isempty(_hl_opts) then
      hl_opts = _hl_opts
      priority = details.priority
      hl_name = details.hl_group
    end
  end

  if hl_name then
    return {
      priority = priority,
      hl_name = hl_name,
      hl_opts = hl_opts,
    }
  end
end

---@param buf buffer
---@param row integer
---@param col integer
---@return extmark_data?
function lsp.get_sttoken_mark_data(buf, row, col)
  local max_priority = 0
  ---@type extmark_data?
  local mark_data

  ---@type STTokenRange[]?
  local token_ranges = vim.lsp.semantic_tokens.get_at_pos(buf, row, col)
  for _, token_range in ipairs(token_ranges or {}) do
    local extmarks = get_sttoken_extmarks(buf, token_range)
    local info = get_max_pri_extmark(extmarks)
    if info and info.priority > max_priority then
      mark_data = info
    end
  end

  return mark_data
end

return lsp
