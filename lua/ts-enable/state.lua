local M = {}

local compat = require('ts-enable.compat')

local uv = vim.uv or vim.loop
local nvim_data = vim.fn.stdpath('data')
local joinpath = compat.joinpath

M.dir = {
  parser_info = joinpath({nvim_data, 'ts-enable', 'parser-info'}),
  query_fallback = joinpath({nvim_data, 'ts-enable', 'query-fallback'}),
  queries = joinpath({nvim_data, 'site', 'queries'}),
  parsers = joinpath({nvim_data, 'site', 'parser'}),
}

M.cache = {}

function M.create(config)
  local new_state = {filetypes = {}, language_filetypes = {}, builtin = {}}

  if not uv.fs_stat(config.parser_info) then
    new_state.err = string.format('Could not find "%s"', config.parser_info)
    return new_state
  end

  local ok, data = pcall(M.read_file, config.parser_info)
  if not data then
    new_state.err = string.format('Could not read "%s"', config.parser_info)
    return new_state
  end

  ---
  -- register builtin parsers
  ---
  local queries = 'queries/*/highlights.scm'
  new_state.builtin = {}
  for _, q in ipairs(vim.fn.globpath(vim.env.VIMRUNTIME, queries, 0, 1)) do
    local name = vim.fn.fnamemodify(q, ':h:t')
    new_state.builtin[name] = true
  end

  ---
  -- register language filetypes
  ---
  if type(data.parsers) == 'table' then
    for name, item in pairs(data.parsers) do
      local fts = compat.ts_filetypes(name)
      if item.language_filetypes then
        new_state.language_filetypes[name] = item.language_filetypes
        vim.list_extend(fts, item.language_filetypes)
      end

      for _, ft in ipairs(fts) do
        new_state.filetypes[ft] = 0
      end
    end
  end

  return new_state
end

function M.copy_snapshot(config)
  if uv.fs_stat(config.parser_info) then
    return
  end

  local dir = 'lua/ts-enable/init.lua'
  dir = vim.api.nvim_get_runtime_file(dir, false)[1]
  dir = vim.fn.fnamemodify(dir, ':h:h:h')

  local name = vim.fn.has('nvim-0.11') == 1 and 'nvim-v0.11.json' or 'nvim-v0.9.json'

  local src = joinpath({dir, 'snapshots', name})
  uv.fs_copyfile(src, config.parser_info)
end

function M.read_snapshot(config)
  local ok, data = pcall(M.read_file, config.parser_info)

  if not ok or data == false then
    local empty = {parsers = {}, meta = {}}
    return empty
  end

  return data
end

function M.read_file(path)
  local fd = uv.fs_open(path, 'r', 438)
  if fd then
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))
    return vim.json.decode(data)
  end

  return false
end

function M.write_file(path, data, format)
  local opts = {sort_keys = true}
  if format then
    opts.indent = '  '
  end

  local content = compat.json_encode(data, opts)

  local fd = assert(uv.fs_open(path, 'w', 438))
  assert(uv.fs_write(fd, content .. '\n'))
  assert(uv.fs_close(fd))

  return true
end

return M

