local M = {}
local messages = {}
local level_hl = {
  trace = 'DiagnosticHint',
  info = 'MoreMsg',
  warn = 'WarningMsg',
  error = 'ErrorMsg',
}

local function noctx_log(level, m)
  local id = #messages + 1
  local m1 = string.format('[ts-enable]: %s', m)
  messages[id] = {m1, level_hl[level]}

  vim.api.nvim_echo({messages[id]}, true, {})
end

function M.log(level, ctx, m, ...)
  local id = #messages + 1
  local hl = level_hl[level]

  local m1 = string.format('[ts-enable/%s]: %s', ctx, m:format(...))
  messages[id] = {m1, level_hl[level]}

  vim.api.nvim_echo({messages[id]}, true, {})
end

function M.trace(m, ...)
  messages[#messages + 1] = {m:format(...), level_hl.trace}
end

function M.error(m, ...)
  noctx_log('error', m:format(...))
end

function M.warn(m, ...)
  noctx_log('warn', m:format(...))
end

function M.info(m, ...)
  noctx_log('info', m:format(...))
end

function M.history()
  for _, m in ipairs(messages) do
    vim.api.nvim_echo({m}, false, {})
  end
end

return M

