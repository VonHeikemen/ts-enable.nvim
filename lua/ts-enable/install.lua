local M = {}
local H = {}

local logger = require('ts-enable.logger')
local compat = require('ts-enable.compat')

local log = logger.log
local uv = vim.uv or vim.loop
local joinpath = compat.joinpath
local uv_spawn = vim.system or compat.uv_spawn
local n_threads = 2 * (uv.available_parallelism() or 1)

local schedule_resume = vim.schedule_wrap(function(co, ...)
  local ok, res = coroutine.resume(co, ...)
  if not ok then
    logger.error(res)
  end
end)

local function co_system(cmd, opts)
  local co = coroutine.running()
  if co == nil then
    local err = 'co_system is not running in a coroutine'
    return {code = -1, stderr = err}
  end

  local cwd = opts.cwd or uv.cwd()
  logger.trace('running job (cwd=%s): %s', cwd, table.concat(cmd, ' '))

  local ok, err = pcall(uv_spawn, cmd, opts, function(result)
    schedule_resume(co, result)
  end)

  if not ok then
    return {code = -1, stderr = err}
  end

  return coroutine.yield()
end

function H.fetch_revision(args)
  local ok = true
  local cmd_opts = {cwd = args.download_dir}
  local revision = args.revision

  vim.fn.mkdir(args.download_dir, 'p')

  log('info', args.ctx, 'Downloading %s', args.url)

  if revision == nil then
    local result = co_system({'git', 'ls-remote', args.url, 'HEAD'})
    ok = result.code == 0
    if not ok then
      log('error', args.ctx, 'Could not get revision')
      return false
    end

    revision = vim.split(result.stdout, '\t')[1]

    if type(revision) ~= 'string' then
      log('error', args.ctx, 'Failed to get latest revision')
      return false
    end
  end

  local commands = {
    {'git', 'init'},
    {'git', 'remote', 'add', 'origin', args.url},
    {'git', 'fetch', 'origin', revision, '--depth=1'},
    {'git', 'checkout', 'FETCH_HEAD'}
  }

  for _, cmd in ipairs(commands) do
    if ok then
      local result = co_system(cmd, cmd_opts)
      ok = result.code == 0

      if not ok then
        log('error', args.ctx, 'Error during download: %s', result.stderr)
      end
    end
  end

  return ok
end

function H.generate_parser(args)
  local lang_version = vim.treesitter.language_version

  local cmd = {'tree-sitter', 'generate', '--abi', tostring(lang_version)}
  if args.from_json then
    table.insert(cmd, joinpath({'src', 'grammar.json'}))
  end

  local file = from_json and 'grammar.json' or 'grammar.js'
  log('info', args.ctx, 'Generating parser.c from %s', file)

  local cmd_opts = {cwd = args.source_dir, env = {TREE_SITTER_JS_RUNTIME = 'native'}}
  local result = co_system(cmd, cmd_opts)

  local ok = result.code == 0
  if not ok then
    log('error', args.ctx, 'Error during "tree-sitter generate": %s', result.stderr)
  end

  return ok
end

function H.compile_parser(args)
  local State = require('ts-enable.state')
  local output = joinpath({State.dir.parsers, args.name .. '.so'})

  log('info', args.ctx, 'Compiling parser')

  local cmd = {'tree-sitter', 'build', '-o', output}
  local result = co_system(cmd, {cwd = args.source_dir})

  local ok = result.code == 0
  if not ok then
    log('error', args.ctx, 'Error during "tree-sitter build": %s', result.stderr)
  end

  return ok
end

function H.save_state(args)
  local now = os.date('%Y-%m-%d %H:%M:%S')
  local install_info = args.install_info or {}
  local queries_info = args.queries_info or {}

  local parser_state = {
    name = args.name,
    install_date = now,
    last_updated = now
  }

  if install_info.url then
    parser_state.url = install_info.url
    parser_state.revision = install_info.revision
  end

  local query_source = queries_info.copy_from
  if query_source == 'query_fallback' then
    parser_state.queries = {
      source = 'query_fallback',
      repo = queries_info.repo,
      revision = queries_info.revision
    }
  elseif query_source == 'parser_queries' then
    parser_state.queries = {source = 'parser_queries'}
  end

  if queries_info.url then
    parser_state.queries = {
      source = 'external',
      repo = args.queries_info.url,
      revision = args.queries_info.revision
    }
  end

  local State = require('ts-enable.state')
  local path = joinpath({State.dir.parser_info, args.name .. '.json'})

  State.write_file(path, parser_state, true)
end

function H.update_state(args)
  local State = require('ts-enable.state')
  local path = joinpath({State.dir.parser_info, args.name .. '.json'})
  local install_info = args.install_info or {}
  local queries_info = args.queries_info or {}

  local parser_state = State.read_file(path)
  parser_state.last_updated = os.date('%Y-%m-%d %H:%M:%S')

  if install_info.url then
    parser_state.revision = args.install_info.revision
  end

  if queries_info.url and queries_info.revision then
    parser_state.queries = {
      source = 'external',
      repo = queries_info.url,
      revision = queries_info.revision
    }
  end

  State.write_file(path, parser_state, true)
end

function H.try_install(args)
  local ok = true
  local name = args.name
  local install_info = args.install_info or {skip = true}

  if install_info.skip then
    return true
  end

  local source_dir = ''
  if install_info.location then
    source_dir = joinpath({args.download_dir, install_info.location})
  else
    source_dir = args.download_dir
  end

  if install_info.generate then
    local from_json = install_info.generate_from_json
    if from_json == nil then
      from_json = true
    end

    ok = H.generate_parser({
      ctx = args.ctx,
      source_dir = source_dir,
      from_json = from_json
    })
    if not ok then
      return false
    end
  end

  ok = H.compile_parser({
    name = name,
    ctx = args.ctx,
    source_dir = source_dir,
  })
  if not ok then
    return false
  end

  return true
end

function H.copy_queries(args)
  local query = args.queries_info or {skip = true}
  if query.skip then
    return true
  end

  local State = require('ts-enable.state')
  local output = joinpath({State.dir.queries, args.name})
  local source = false

  if vim.startswith(args.ctx, 'install') then
    if uv.fs_stat(output) then
      log('info', ctx, 'queries already installed')
      return true
    end
  end

  if query.copy_from == 'query_fallback' then
    if query.location then
      source = joinpath({State.dir.query_fallback, query.location, args.name})
    else
      source = joinpath({State.dir.query_fallback, args.name})
    end

    if not uv.fs_stat(source) then
      log('warn', args.ctx, 'Could not find queries directory')
      return false
    end

    log('info', args.ctx, 'Copying queries')

    return H.copy_dir({ctx = args.ctx, source = source, output = output})
  end

  local location = ''
  if query.location then
    location = query.location
  else
    location = 'queries'
  end

  if type(query.url) == 'string' and query.download_dir then
    source = joinpath({query.download_dir, location})
  end

  if query.copy_from == 'parser_queries' then
    source = joinpath({args.download_dir, location})
  end

  if not source then
    log('warn', args.ctx, 'Could not get queries directory')
    return false
  end

  if not uv.fs_stat(source) then
    log('warn', args.ctx, 'Could not find queries directory')
    return false
  end

  log('info', args.ctx, 'Copying queries')

  return H.copy_dir({ctx = args.ctx, source = source, output = output})
end

function H.copy_dir(args)
  local src = args.source
  local output = args.output

  vim.fn.delete(output, 'rf')
  vim.fn.mkdir(output, 'p')

  for _, path in ipairs(vim.fn.globpath(src, '*.scm', 0, 1)) do
    local file = vim.fn.fnamemodify(path, ':t')

    local ok, e = pcall(uv.fs_copyfile, joinpath({src, file}), joinpath({output, file}))
    if not ok then
      log('error', args.ctx, 'Error during "copy dir": %s', e)
      return false
    end
  end

  return true
end

function H.prepare(context, lang)
  local data = context.parser_info.parsers[lang]
  if context.repos[lang] or data == nil then
    return
  end

  local fmt = string.format
  local State = require('ts-enable.state')
  local is_update = context.action == 'update'
  local is_install = context.action == 'install'
  local ctx = fmt('%s/%s', context.action, lang)

  local url = vim.tbl_get(data, 'install_info', 'url')
  local revision = vim.tbl_get(data, 'install_info', 'revision')

  if is_install and url then
    local parser_path = joinpath({State.dir.parsers, lang .. '.so'})
    if uv.fs_stat(parser_path) then
      log('info', ctx, 'parser already installed')
      return
    end
  end

  if is_update then
    local info = joinpath({State.dir.parser_info, lang .. '.json'})
    if not uv.fs_stat(info) then
      log('info', ctx, 'parser is not installed')
      return
    end
  end

  context.index = context.index + 1

  local new_repo = {
    name = lang,
    ctx = ctx,
    install_info = data.install_info or {skip = true},
    queries_info = data.queries_info or {skip = true},
  }

  if url then
    new_repo.download_dir = joinpath({
      context.temp_dir,
      fmt('%s-%s', context.prefix, url:match('[^/]+$'))
    })

    local parser_seen = context.urls[url]
    if not parser_seen then
      context.urls[url] = {
        name = lang,
        url = url,
        ctx = ctx,
        kind = 'parser',
        revision = revision,
        download_dir = new_repo.download_dir,
      }
    end

    if parser_seen and parser_seen.revision ~= revision then
      new_repo.download_dir = fmt('%s-%s', new_repo.download_dir, context.index)
      context.urls[url .. context.index] = {
        name = lang,
        url = url,
        ctx = ctx,
        kind = 'parser',
        revision = new_repo.install_info.revision,
        download_dir = new_repo.download_dir,
      }
    end
  end

  local query_source = new_repo.queries_info.copy_from
  if query_source == 'query_fallback' then
    if is_install then
      new_repo.queries_info = {
        copy_from = 'query_fallback',
        repo = context.query_fallback.url,
        revision = context.query_fallback.revision,
        location = context.query_fallback.location
      }
    end

    if is_update then
      new_repo.queries_info = {skip = true}
    end
  elseif query_source == 'parser_queries' then
    new_repo.queries_info.url = nil
  end

  local query_url = new_repo.queries_info.url
  if query_url then
    new_repo.queries_info.download_dir = joinpath({
      context.temp_dir,
      fmt('%s-%s', context.prefix, query_url:match('[^/]+$'))
    })

    local query_seen = context.urls[query_url]
    local query_revision = new_repo.queries_info.revision
    if not query_seen then
      context.urls[query_url] = {
        name = lang,
        url = query_url,
        ctx = ctx,
        kind = 'query',
        revision = query_revision,
        download_dir = new_repo.queries_info.download_dir,
      }
    end

    if query_seen and query_seen.revision ~= query_revision then
      new_repo.queries_info.download_dir = fmt(
        '%s-%s',
        new_repo.queries_info.download_dir,
        context.index
      )
      context.urls[query_url .. context.index] = {
        url = query_url,
        ctx = ctx,
        kind = 'query',
        revision = query_revision,
        download_dir = new_repo.queries_info.download_dir,
      }
    end
  end

  context.repos[lang] = new_repo

  if type(data.requires) == 'table' then
    for _, l in ipairs(data.requires) do
      H.prepare(context, l)
    end
  end
end

function H.get_latest_revision(url)
  local result = co_system({'git', 'ls-remote', url, 'HEAD'}, {})
  local ok = result.code == 0
  if not ok then
    return false, 'Could not fetch latest revision'
  end

  local revision = vim.split(result.stdout, '\t')[1]
  return true, revision
end

function M.install_parser(langs, on_install)
  if type(langs) == 'string' then
    langs = {langs}
  end

  if type(langs) ~= 'table' then
    return
  end

  if langs[1] == nil then
    vim.notify('[ts-enable/install]: Must provide at least one argument')
    return
  end

  require('ts-enable')._init()
  local State = require('ts-enable.state')
  local query_fallback_dir = State.dir.query_fallback
  local parser_info = State.read_snapshot(State.cache.global_config)

  vim.fn.mkdir(State.dir.parser_info, 'p')
  vim.fn.mkdir(State.dir.parsers, 'p')

  local cb = {}
  local context = {
    repos = {},
    urls = {},
    index = 0,
    action = 'install',
    parser_info = parser_info,
    temp_dir = vim.fs.dirname(vim.fn.tempname()),
    prefix = 'tsei' .. os.date('%H%M%S'),
    query_fallback = vim.tbl_get(parser_info, 'meta', 'query_fallback') or {}
  }

  for _, lang in ipairs(langs) do
    H.prepare(context, lang)
  end

  local downloads = {}
  for _, data in pairs(context.urls) do
    table.insert(downloads, function() H.fetch_revision(data) end)
  end

  local do_compile = {}
  local completed = 0
  for _, data in pairs(context.repos) do
    table.insert(do_compile, function()
      local ok1, step1 = pcall(H.try_install, data)
      local ok2, step2 = pcall(H.copy_queries, data)

      if not ok1 then
        log('error', data.ctx, 'Error during "try install": %e', step1)
      end

      if not ok2 then
        log('error', data.ctx, 'Error during "copy queries": %e', step2)
      end

      local save = step1 or step2
      if save then
        local ok3, err = pcall(H.save_state, data)
        if ok3 then
          completed = completed + 1
          log('info', data.ctx, 'Completed')
        else
          log('error', data.ctx, 'Error during "save state": %s', err)
        end
      end

      if type(on_install) == 'function' then
        on_install()
      end
    end)
  end

  if #do_compile == 0 then
    return
  end

  cb.get_query_fallback = function()
    if uv.fs_stat(query_fallback_dir) then
      return
    end

    H.fetch_revision({
      url = context.query_fallback.url,
      ctx = 'install/query_fallback',
      revision = context.query_fallback.revision,
      download_dir = query_fallback_dir,
    })
  end

  cb.download = function()
    compat.co_join(n_threads, downloads, cb.compile)
  end

  cb.compile = function()
    compat.co_join(n_threads, do_compile, cb.finish)
  end

  cb.finish = function()
    vim.g.ts_enable_lock_install = nil
    logger.info('Installed %d/%d languages', completed, #do_compile)
  end

  vim.g.ts_enable_lock_install = true
  if type(context.query_fallback.url) == 'string' then
    compat.co_join(n_threads, {cb.get_query_fallback}, cb.download)
  else
    cb.download()
  end
end

function M.update_parser(langs, on_update)
  if type(langs) == 'string' then
    langs = {langs}
  end

  if type(langs) ~= 'table' then
    return
  end

  require('ts-enable')._init()
  local State = require('ts-enable.state')
  if langs[1] == nil then
    local parsers = vim.fn.globpath(State.dir.parser_info, '*.json', 0 , 1)
    for _, path in ipairs(parsers) do
      table.insert(langs, vim.fn.fnamemodify(path, ':t:r'))
    end
  end

  local query_fallback_dir = State.dir.query_fallback
  local parser_info = State.read_snapshot(State.cache.global_config)

  local cb = {}
  local context = {
    repos = {},
    urls = {},
    index = 0,
    action = 'update',
    parser_info = parser_info,
    temp_dir = vim.fs.dirname(vim.fn.tempname()),
    prefix = 'tseu' .. os.date('%H%M%S'),
    query_fallback = vim.tbl_get(parser_info, 'meta', 'query_fallback') or {}
  }

  for _, lang in ipairs(langs) do
    H.prepare(context, lang)
  end

  local downloads = {}
  local updates = {parsers = {}, queries = {}}
  for _, data in pairs(context.urls) do
    table.insert(downloads, function()
      local ok, result = H.get_latest_revision(data.url)
      if not ok then
        log('error', data.ctx, 'Could not fetch %s latest revision', data.kind)
        return
      end

      data.revision = result
      if data.kind == 'parser' then
        updates.parsers[data.name] = result
      end

      if data.kind == 'query' then
        updates.queries[data.name] = result
      end

      H.fetch_revision(data) 
    end)
  end

  local do_compile = {}
  local completed = 0
  for _, data in pairs(context.repos) do
    table.insert(do_compile, function()
      if not uv.fs_stat(data.download_dir) then
        return
      end

      local name = data.name
      local new_name = '_' .. name
      local url = data.install_info.url

      data.name = new_name
      local ok1, step1 = pcall(H.try_install, data)
      local new_parser = joinpath({State.dir.parsers, new_name .. '.so'})

      if not ok1 then
        log('error', data.ctx, 'Error during "try install": %e', step1)
      end

      if url and uv.fs_stat(new_parser) then
        local parser_path = joinpath({State.dir.parsers, name .. '.so'})
        local removed, err_removed = os.remove(parser_path)
        if removed then
          local renamed, err_renamed = os.rename(new_parser, parser_path)
          if not renamed then
            log('error', data.ctx, err_renamed)
            return
          end
        else
          log('error', data.ctx, err_removed)
          return
        end

        local new_revision = updates.parsers[name]
        if new_revision then
          data.install_info.revision = new_revision
        end
      end

      data.name = name
      local ok2, step2 = pcall(H.copy_queries, data)
      if not ok2 then
        log('error', data.ctx, 'Error during "copy queries": %e', step2)
      end

      local save = step1 or step2
      if save then
        local new_query = updates.queries[name]
        if new_query 
          and data.queries_info 
          and data.queries_info.url
          and data.queries_info.revision
        then
          data.queries_info.revision = new_query
        end

        local ok3, err = pcall(H.update_state, data)
        if ok3 then
          completed = completed + 1
          log('info', data.ctx, 'Completed')
        else
          log('error', data.ctx, 'Error during "save state": %s', err)
        end
      end

      if type(on_update) == 'function' then
        on_update()
      end
    end)
  end

  if #do_compile == 0 then
    return
  end

  cb.download = function()
    compat.co_join(n_threads, downloads, cb.compile)
  end

  cb.compile = function()
    compat.co_join(n_threads, do_compile, cb.finish)
  end

  cb.finish = function()
    vim.g.ts_enable_lock_update = nil
    logger.info('Updated %d/%d languages', completed, #do_compile)
  end

  vim.g.ts_enable_lock_update = true
  cb.download()
end

function M.remove_parser(langs)
  if type(langs) == 'string' then
    langs = {langs}
  end

  if type(langs) ~= 'table' then
    return
  end

  require('ts-enable')._init()
  local State = require('ts-enable.state')
  for _, lang in pairs(langs) do
    local info_path = joinpath({State.dir.parser_info, lang .. '.json'})
    local parser_path = joinpath({State.dir.parsers, lang .. '.so'})
    local queries_path = joinpath({State.dir.queries, lang})

    if uv.fs_stat(parser_path) then
      os.remove(parser_path)
    end

    if uv.fs_stat(info_path) then
      os.remove(info_path)
    end

    if uv.fs_stat(queries_path) then
      vim.fn.delete(queries_path, 'rf')
    end
  end

  log('info', 'delete', 'Completed')
end

function M.sync()
  require('ts-enable')._init()

  local State = require('ts-enable.state')
  local snapshot = State.read_snapshot(State.cache.global_config)
  local parsers = vim.fn.globpath(State.dir.parser_info, '*.json', 0 , 1)
  local changed = false
  for _, path in ipairs(parsers) do
    local name = vim.fn.fnamemodify(path, ':t:r')
    local current_state = snapshot.parsers[name]

    if current_state then
      local installed = State.read_file(path)
      local snapshot_revision = vim.tbl_get(current_state, 'install_info', 'revision') or false
      if snapshot_revision and installed.revision then
        changed = true
        snapshot.parsers[name].install_info.revision = installed.revision
      end

      local queries_info = current_state.queries_info
      if queries_info.copy_from == nil
        and queries_info.url 
        and queries_info.revision 
        and installed.queries
        and installed.queries.source == 'external'
      then
        changed = true
        snapshot.parsers[name].queries_info.revision = installed.queries.revision
      end
    end
  end

  if changed then
    local path = State.cache.global_config.parser_info
    State.write_file(path, snapshot, true)
    vim.notify('[ts-enable/sync]: Complete')
  else
    vim.notify('[ts-enable/sync]: Already up-to-date')
  end
end

return M

