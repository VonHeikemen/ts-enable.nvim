local M = {}

local filetypes = {}
local global_config = {}
local initialized = false
local skip_nvim_ts = false

---@class TSEnable.Config
---@inlinedoc
---
---Treesitter parsers available in Neovim's runtime
---@field parsers? string[]
---
---Install missing parsers using nvim-treesitter
---@field auto_install? boolean
---
---Enable vim.treesitter based syntax highlight
---@field highlights? boolean
---
---Set vim.treesitter fold expression
---@field folds? boolean
---
---Set nvim-treesitter indent expression
---@field indents? boolean
---
---Override global config for a specific parser
---@field parser_settings? table<string, any>

local function init()
  if initialized then
    return
  end

  initialized = true
  global_config = vim.g.ts_enable or {}

  filetypes = vim.iter(global_config.parsers or {})
    :map(vim.treesitter.language.get_filetypes)
    :flatten()
    :fold({}, function(tbl, v)
      tbl[v] = 0
      return tbl
    end)

  -- check if nvim-treesitter is installed without trying to load it
  local nvim_ts_path = 'lua/nvim-treesitter/init.lua'
  local nvim_ts = vim.api.nvim_get_runtime_file(nvim_ts_path, false)[1]
  skip_nvim_ts = nvim_ts == nil

  -- register builtin parsers
  local queries = 'queries/*/highlights.scm'
  local builtin = vim.iter(vim.fn.globpath(vim.env.VIMRUNTIME, queries, 0, 1))
    :map(function(q) return vim.fn.fnamemodify(q, ':h:t') end)
    :fold({}, function(t, v) t[v] = true; return t end)

  global_config._builtin_parsers = builtin
end

local function parser_installed(lang)
  local installed = vim.treesitter.language.add(lang) == true

  if skip_nvim_ts then
    return installed
  end

  if installed and global_config._builtin_parsers[lang] then
    -- return false to force nvim-treesitter's install function
    return false
  end

  return installed
end

local function ts_install(buffer, lang, ft)
  if skip_nvim_ts then
    return false
  end

  local parser_config = vim.tbl_get(global_config, 'parser_settings', lang) or false
  local config = parser_config or global_config

  if not config.auto_install then
    return false
  end

  local ok, nvim_ts = pcall(require, 'nvim-treesitter')
  if not ok then
    local msg = '[ts-enable] module "nvim-treesitter" not found'
    vim.notify_once(msg, vim.log.levels.WARN)
    return false
  end

  nvim_ts.install(lang):await(function()
    local installed = vim.treesitter.language.add(lang) == true
    filetypes[ft] = installed and 1 or -1

    if installed then
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
      init()
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
    end
  end

  if config.folds then
    local ok, fld = pcall(ts.query.get, lang, 'folds')
    if ok and fld then
      local old_method = vim.wo.foldmethod
      local old_expr = vim.wo.foldexpr

      local new_method = 'expr'
      local new_expr = 'v:lua.vim.treesitter.foldexpr()'

      if old_method ~= new_method then
        vim.wo.foldmethod = new_method
        vim.w.ts_enable_wo_foldmethod = old_method
      end

      if old_expr ~= new_expr then
        vim.wo.foldexpr = new_expr
        vim.w.ts_enable_wo_foldexpr = old_expr
      end
    end
  end

  if config.indents then
    local ok, idt = pcall(ts.query.get, lang, 'indents')
    if ok and idt then
      local old_expr = buf.indentexpr
      local new_expr = "v:lua.require'nvim-treesitter'.indentexpr()"

      if old_expr ~= new_expr then
        vim.bo[buffer].indentexpr = new_expr
        buf.ts_enable_bo_indentexpr = old_expr
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

  local buf = vim.b[buffer]

  if buf.ts_highlight then
    vim.treesitter.stop(buffer)
  end

  buf.ts_enable_active = false

  if vim.w.ts_enable_wo_foldmethod then
    vim.wo.foldmethod = vim.w.ts_enable_wo_foldmethod
  end

  if vim.w.ts_enable_wo_foldexpr then
    vim.wo.foldexpr = vim.w.ts_enable_wo_foldexpr
  end

  if buf.ts_enable_bo_indentexpr then
    vim.bo[buffer].indentexpr = buf.ts_enable_bo_indentexpr
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
    init()
  end

  if buffer == nil then
    buffer = vim.api.nvim_get_current_buf()
  end

  if ft == nil then
    ft = vim.bo.filetype
  end

  local available = filetypes[ft]
  if available == nil then
    return
  end

  local lang = vim.treesitter.language.get_lang(ft)
  if lang == nil or lang == '' then
    return
  end

  if available == 0 and parser_installed(lang) then
    available = 1
    filetypes[ft] = 1
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

  if global_config._builtin_parsers[lang] then
    filetypes[ft] = 1
    M.start(buffer, lang)
  end
end

---Ensure parsers specified in g:ts_enable are installed. Installation is handled by nvim-treesitter.
function M.ensure_installed()
  local ok, nvim_ts = pcall(require, 'nvim-treesitter')
  if not ok then
    local msg = '[ts-enable] module "nvim-treesitter" not found'
    vim.notify(msg, vim.log.levels.WARN)
    return
  end

  local config = vim.g.ts_enable or {}
  nvim_ts.install(config.parsers or {})
end

return M

