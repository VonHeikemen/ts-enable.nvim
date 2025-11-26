local M = {}

local parsers = (vim.g.ts_enable or {}).parsers
local filetypes = vim.iter(parsers or {})
  :map(vim.treesitter.language.get_filetypes)
  :flatten()
  :fold({}, function(tbl, v)
    tbl[v] = 0
    return tbl
  end)

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
---Create autocommand during Neovim's startup process
---@field create_autocmd? boolean

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
    config = vim.g.ts_enable or {}
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

  if available == 0 and vim.treesitter.language.add(lang) then
    available = 1
    filetypes[ft] = 1
  end

  if available == 1 then
    M.start(buffer, lang, config)
    return
  end

  local config = vim.g.ts_enable or {}
  if config.auto_install ~= true or available == -1 then
    return
  end

  local ok, nvim_ts = pcall(require, 'nvim-treesitter')
  if not ok then
    return
  end

  nvim_ts.install(lang):await(function()
    local parser_installed = vim.treesitter.language.add(lang) == true
    filetypes[ft] = parser_installed and 1 or -1

    if parser_installed then
      M.start(buffer, lang, config)
    end
  end)
end

---Ensure parsers specified in g:ts_enable are installed. Installation is handled by nvim-treesitter.
function M.ensure_installed()
  local config = vim.g.ts_enable or {}
  local parsers = config.parsers or {}

  local ok, nvim_ts = pcall(require, 'nvim-treesitter')
  if not ok then
    return
  end

  nvim_ts.install(parsers)
end

return M

