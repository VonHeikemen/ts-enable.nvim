local M = {}
local uv = vim.uv or vim.loop

local global_config = {}
local global_state = {}
local initialized = false
local compat

---@class TSEnable.Config
---@inlinedoc
---
---Generate "parser info" file if missing
---@field auto_init? boolean
---
---Install missing parsers
---@field auto_install? boolean
---
---Enable vim.treesitter based syntax highlight
---@field highlights? boolean
---
---Re-enable regex syntax files if highlights is enabled
---@field regex_syntax? boolean
---
---Set vim.treesitter fold expression
---@field folds? boolean
---
---Override global config for a specific parser
---@field parser_settings? table<string, any>

function M._init()
  if initialized then
    return
  end

  initialized = true
  global_config = vim.g.ts_enable or {}
  compat = require('ts-enable.compat')

  if global_config.parser_info == nil then
    global_config.parser_info = compat.joinpath({
      vim.fn.stdpath('config'),
      'treesitter-parsers.json'
    })
  end

  local State = require('ts-enable.state')
  if global_config.auto_init then
    State.copy_snapshot(global_config)
  end

  global_state = State.create(global_config)

  State.cache.global_state = global_state
  State.cache.global_config = global_config

  for name, ft in pairs(global_state.language_filetypes) do
    vim.treesitter.language.register(name, ft)
  end
end

local function parser_installed(lang, ft)
  local available = compat.parser_available(lang)

  if available and global_state.builtin[lang] then
    if compat.parser_installed(lang) then
      global_state.builtin[lang] = false
      return true
    end

    -- return false to force the install function
    return false
  end

  if not available and compat.parser_installed(lang) then
    -- parser installed is not compatible with the current nvim version
    global_state.filetypes[ft] = -2
    return false
  end

  return available
end

local function ts_install(buffer, lang, ft)
  local parser_config = vim.tbl_get(global_config, 'parser_settings', lang) or false
  local config = parser_config or global_config

  if not config.auto_install then
    return false
  end

  local has_treesitter_cli = global_state.has_treesitter_cli
  if not has_treesitter_cli then
    if has_treesitter_cli == nil then
      has_treesitter_cli = vim.fn.executable('tree-sitter') == 1
      global_state.has_treesitter_cli = has_treesitter_cli
    end

    if has_treesitter_cli == false then
      global_config.auto_install = false
      local ps = global_config.parser_settings or {}
      for _, s in pairs(ps) do
        if s.auto_install then
          s.auto_install = false
        end
      end

      local msg = '[ts-enable/auto_install]: tree-sitter CLI was not found'
      vim.notify_once(msg, vim.log.levels.WARN)
      return false
    end
  end

  local available = global_state.filetypes[ft]
  if available == -2 then
    global_state.filetypes[ft] = -1
    return true
  end

  require('ts-enable.install').install_parser(lang, function()
    local installed = compat.parser_available(lang)
    global_state.filetypes[ft] = installed and 1 or -1

    if installed and vim.api.nvim_buf_is_valid(buffer) then
      M.start(buffer, lang)
    end
  end)

  return true
end

---Enable treesitter features
---@param buffer? number
---@param lang? string
---@param config? TSEnable.Config
function M.start(buffer, lang, config)
  local ts = vim.treesitter

  if buffer == nil then
    buffer = vim.api.nvim_get_current_buf()
  end

  if lang == nil then
    lang = vim.bo[buffer].filetype
  end

  if config == nil then
    if not initialized then
      M._init()
    end

    local parser_config = vim.tbl_get(global_config, 'parser_settings', lang) or false
    config = parser_config or global_config
  end

  local buf = vim.b[buffer]
  buf.ts_enable_active = true

  if config.highlights then
    local ok, hl = pcall(ts.query.get, lang, 'highlights')
    if ok and hl then
      ts.start(buffer, lang)
      if config.regex_syntax then
        vim.api.nvim_set_option_value('syntax', 'ON', {scope = 'local', buf = buffer})
      end
    end
  end

  if config.folds then
    local ok, fld = pcall(ts.query.get, lang, 'folds')
    if ok and fld then
      local winid = vim.api.nvim_get_current_win()
      local win = vim.w[winid]
      local old_method = vim.api.nvim_get_option_value('foldmethod', {scope = 'local', win = winid})
      local old_expr = vim.api.nvim_get_option_value('foldexpr', {scope = 'local', win = winid})

      local new_method = 'expr'
      local new_expr = 'v:lua.vim.treesitter.foldexpr()'

      if old_method ~= new_method then
        vim.api.nvim_set_option_value('foldmethod', new_method, {scope = 'local', win = winid})
        win.ts_enable_wo_foldmethod = old_method
      end

      if old_expr ~= new_expr then
        vim.api.nvim_set_option_value('foldexpr', new_expr, {scope = 'local', win = winid})
        win.ts_enable_wo_foldexpr = old_expr
      end
    end
  end
end

---Disable treesitter highlights and restore previous options
---@param buffer? number
function M.stop(buffer)
  if buffer == nil then
    buffer = vim.api.nvim_get_current_buf()
  end

  local set_option = vim.api.nvim_set_option_value
  local winid = vim.api.nvim_get_current_win()
  local win = vim.w[winid]
  local buf = vim.b[buffer]

  if buf.ts_highlight then
    vim.treesitter.stop(buffer)
  end

  buf.ts_enable_active = false

  if win.ts_enable_wo_foldmethod then
    set_option('foldmethod', win.ts_enable_wo_foldmethod, {scope = 'local', win = winid})
  end

  if win.ts_enable_wo_foldexpr then
    set_option('foldexpr', win.ts_enable_wo_foldexpr, {scope = 'local', win = winid})
  end
end

---Start or stop treesitter
function M.toggle()
  if vim.b.ts_enable_active then
    M.stop()
    vim.notify('ts-enable stopped')
  else
    M.start()
    vim.notify('ts-enable started')
  end
end

---Set configuration options. This function is here only to comply with lazy.nvim options api
---@param opts? TSEnable.Config
function M.setup(opts)
  if type(opts) == 'table' then
    vim.g.ts_enable = opts
  end
end

---Stop treesitter and set g:ts_enable_attach to 0
function M.detach()
  vim.g.ts_enable_attach = 0
  M.stop()
end

---Enable treesitter features and, if needed, install missing parsers
---@param buffer? number
---@param ft? string
function M.attach(buffer, ft)
  if not initialized then
    M._init()
  end

  if buffer == nil then
    buffer = vim.api.nvim_get_current_buf()
  end

  if ft == nil then
    ft = vim.bo.filetype
  end

  local available = global_state.filetypes[ft]
  if available == nil then
    return
  end

  local lang = compat.get_lang(ft)
  if lang == nil or lang == '' then
    return
  end

  if available == 0 and parser_installed(lang, ft) then
    available = 1
    global_state.filetypes[ft] = 1
  end

  if available == 1 then
    M.start(buffer, lang)
    return
  end
  
  if available == -1 then
    return
  end

  if ts_install(buffer, lang, ft) then
    return
  end

  if global_state.builtin[lang] then
    global_state.filetypes[ft] = 1
    M.start(buffer, lang)
  end
end

return M

