local M = {}
local uv = vim.uv or vim.loop
local iswin = vim.fn.has('win32') == 1

function M.joinpath(segments)
  local path = table.concat(segments, '/')
  return (path:gsub(iswin and '[/\\][/\\]*' or '//+', '/'))
end

function M.co_thread(fn, ...)
  return coroutine.resume(coroutine.create(fn), ...)
end

function M.co_join(max_jobs, fns, resolve)
  max_jobs = math.min(max_jobs, #fns)

  local remaining = {select(max_jobs + 1, unpack(fns))}
  local to_go = #fns

  local cb
  cb = function()
    to_go = to_go - 1
    if to_go == 0 and type(resolve) == 'function' then
      resolve()
    elseif #remaining > 0 then
      local next_fn = table.remove(remaining)

      local co = coroutine.running()
      if co ~= nil then
        next_fn()
        cb()
        return
      end

      local ok = M.co_thread(function()
        next_fn()
        cb()
      end)
      if not ok then
        cb()
      end
    end
  end

  for i = 1, max_jobs do
    local fn = fns[i]
    M.co_thread(function()
      fn()
      cb()
    end)
  end
end

function M.uv_spawn(cmd, opts, on_exit)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local stdout_data = {}
  local stderr_data = {}
  local proc

  local spawn_opts = {
    args = vim.list_slice(cmd, 2),
    hide = true,
    cwd = opts.cwd,
    stdio = {nil, stdout, stderr}
  }

  if type(opts.env) == 'table' then
    local env = vim.tbl_extend('force', vim.fn.environ(), opts.env)
    local proc_env = {}

    for k, v in pairs(env) do
      proc_env[#proc_env + 1] = string.format('%s=%s', k, tostring(v))
    end

    spawn_opts.env = proc_env
  end

  local exit_handler = function(code, signal)
    if proc and not proc:is_closing() then
      proc:close()
    end

    local check = uv.new_check()
    check:start(function()
      for _, h in ipairs({stdout, stderr}) do
        if not h:is_closing() then
          return
        end
      end
      check:stop()
      check:close()
      
      on_exit({
        code = code,
        signal = signal,
        stdout = table.concat(stdout_data),
        stderr = table.concat(stderr_data)
      })
    end)
  end

  local error_handler = function()
    local handles = {proc, stdout, stderr}
    for _, h in ipairs(handles) do
      if h and not h:is_closing() then
        h:close()
      end
    end
  end

  proc = uv.spawn(cmd[1], spawn_opts, exit_handler, error_handler)

  stdout:read_start(function(err, chunk)
    if err then
      error(err)
    end

    if chunk == nil then
      stdout:read_stop()
      stdout:close()
      return
    end

    stdout_data[#stdout_data + 1] = chunk:gsub('\r\n', '\n')
  end)

  stderr:read_start(function(err, chunk)
    if err then
      error(err)
    end

    if chunk == nil then
      stderr:read_stop()
      stderr:close()
      return
    end

    stderr_data[#stderr_data + 1] = chunk:gsub('\r\n', '\n')
  end)
end

function M.json_encode(data, opts)
  return vim.json.encode(data, opts)
end

function M.ts_filetypes(lang)
  return vim.treesitter.language.get_filetypes(lang)
end

function M.get_lang(ft)
  return vim.treesitter.language.get_lang(ft)
end

function M.parser_installed(name)
  local State = require('ts-enable.state')
  local parser_path = M.joinpath({State.dir.parsers, name .. '.so'})

  return type(uv.fs_stat(parser_path)) == 'table'
end

function M.parser_available(name)
  return vim.treesitter.language.add(name) == true
end

if vim.fn.has('nvim-0.11') == 0 then
  M.json_encode = function(data, _)
    return vim.json.encode(data)
  end

  M.parser_available = function(name)
    return pcall(vim.treesitter.language.add, name)
  end

  M.ts_filetypes = function(name)
    local fts = vim.treesitter.language.get_filetypes(name)
    if fts[1] == nil then
      return {name}
    end

    table.insert(fts, name)
    return fts
  end
end

if vim.fn.has('nvim-0.10') == 0 then
  M.get_lang = function(ft)
    local lang = vim.treesitter.language.get_lang(ft)
    if lang then
      return lang
    end

    ft = vim.split(ft, ".", {plain = true})[1]
    return vim.treesitter.language.get_lang(ft) or ft
  end
end

return M

