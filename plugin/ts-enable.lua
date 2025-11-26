if vim.g.loaded_ts_enable ~= nil then
  return
end

vim.g.loaded_ts_enable = 1
local valid_commmands = {'start', 'stop', 'toggle', 'attach', 'detach', 'ensure_installed'}

local function cmd_completion(input)
  local result = {}
  for _, name in ipairs(valid_commmands) do
    if vim.startswith(name, input) then
      result[#result + 1] = name
    end
  end

  return result
end

vim.api.nvim_create_user_command('TSEnableExec', function(input)
  local cmd = vim.trim(input.args)
  if not vim.tbl_contains(valid_commmands, cmd) then
    local msg = '[ts-enable] Invalid sub-command "%s"'
    vim.notify(msg:format(cmd), vim.log.levels.WARN)
    return
  end

  local callback = require('ts-enable')[cmd]
  if input.bang then
    callback()
    return
  end

  if not pcall(callback) then
    local msg = '[ts-enable] Command "%s" failed'
    vim.notify(msg:format(cmd), vim.log.levels.ERROR)
  end
end, {nargs = 1, bang = true, complete = cmd_completion})

local group = vim.api.nvim_create_augroup('ts-enable', {clear = true})
vim.g.ts_enable_attach = 1

vim.api.nvim_create_autocmd('FileType', {
  pattern = '*',
  group = group,
  desc = 'Enable treesitter features',
  callback = function(event)
    if vim.g.ts_enable_attach == 1 then
      require('ts-enable').attach(event.buf, event.match)
    end
  end
})

