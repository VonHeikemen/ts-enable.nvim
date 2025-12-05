# TS-enable

This plugin complements nvim-treesitter's new version, the one in [the main branch](https://github.com/nvim-treesitter/nvim-treesitter/tree/main). It implements the boilerplate code needed to enable features based on treesitter.

The idea here is to be able to use treesitter by setting a few variables. For example:

```vim
" This is vimscript, by the way
let g:ts_enable = {
\ 'parsers': ['json', 'gleam', 'python'],
\ 'auto_install': v:true,
\ 'highlights': v:true,
\ 'folds': v:true,
\ 'indents': v:true,
\}
```

That's it. You don't have to learn new things to make this work. As long as you have the correct version of `nvim-treesitter` installed, `ts-enable.nvim` will take care of the rest.

If you prefer lua, don't worry. You can use `vim.g.ts_enable` in your configuration. I also added a thing to make it compatible with `lazy.nvim`'s option API.

## Installation

Use your favorite plugin manager to install `ts-enable.nvim` and `nvim-treesitter`.

* vim-plug

  ```vim
  Plug 'VonHeikemen/ts-enable.nvim'
  Plug 'nvim-treesitter/nvim-treesitter', { 'branch': 'main' }
  ```

* mini.deps

  ```lua
  MiniDeps.add('VonHeikemen/ts-enable.nvim')
  MiniDeps.add({
    source = 'nvim-treesitter/nvim-treesitter',
    checkout = 'main',
  })
  ```

* vim.pack

  ```lua
  vim.pack.add({
    'https://github.com/VonHeikemen/ts-enable.nvim',
    {
      src = 'https://github.com/nvim-treesitter/nvim-treesitter',
      version = 'main',
    },
  })
  ```

## Configuration

This plugin should be configured using a **vim global variable** called `ts_enable`. You can create that variable anywhere you want. `init.lua`, `init.vim` or any random script that Neovim can pick up during the startup process.

Here's example using all the default values as reference.

```vim
" These are the default values. Change them as you see fit.
let g:ts_enable = {
\ 'parsers': [],
\ 'auto_install': v:false,
\ 'highlights': v:false,
\ 'folds': v:false,
\ 'indents': v:false,
\ 'parser_settings': {},
\}
```

In a lua file to create a vim global use `vim.g`. In this case assign a lua table with the settings you want.

```lua
-- These are the default values. Change them as you see fit.
vim.g.ts_enable = {
  parsers = {},
  auto_install = false,
  highlights = false,
  folds = false,
  indents = false,
  parser_settings = {},
}
```

* `parsers`: list of strings. Treesitter parsers that you want to use. If `auto_install` is enabled and `nvim-treesitter` is installed, the parser will be downloaded if needed.

* `auto_install`: boolean. If enabled use `nvim-treesitter` to install a missing parser.

* `highlights`: boolean. If enabled use `vim.treesitter.start()` to enable treesitter based syntax highlight.

* `folds`: boolean. If enabled set the option `foldexpr` to use treesitter.

* `indents`: boolean. If enabled set the option `indentexpr` to use an experimental function from `nvim-treesitter`.

* `parser_settings`: table. Override global config for a specific parser.

## Notes

### ts-enable.nvim is not strictly needed

If you don't mind having a bit of code in your personal configuration, you could skip `ts-enable.nvim` entirely. Just install treesitter parsers ahead of time and mantain your own autocommand with the features you want to enable.

```lua
-- NOTE: It is important that you install treesitter parsers and queries.
-- Otherwise none of this will work.

-- Neovim filetypes where you want to enable treesitter
local ts_filetypes = {'json', 'gleam', 'python'}

vim.api.nvim_create_autocmd('FileType', {
  desc = 'Enable treesitter features',
  pattern = ts_filetypes,
  callback = function()
    -- enable syntax highlight
    vim.treesitter.start()

    -- enable folds
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

    -- enable indents
    -- NOTE: this feature depends on 'nvim-treesitter'
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
})
```

### Download everything and the kitchen sink

`ts-enable.nvim` can download missing parsers on demand, meaning it'll only try to get the parsers for the files you open. So I don't think is such a terrible idea to list all the available parsers in `nvim-treesitter`. If you happen to find a parser that has performance issues, disable it using the `parser_settings` property.

```lua
vim.g.ts_enable = {
  parsers = require('nvim-treesitter').get_available(),
  auto_install = true,
  highlights = true,
}
```

On vimscript:

```vim
let g:ts_enable = {
\ 'parsers': v:lua.require'nvim-treesitter'.get_available(),
\ 'auto_install': v:true,
\ 'highlights': v:true,
\}
```

## Disable a parser

You can override the configuration for a parser using `parser_settings`.

In the following example all the features are enable on the global config, but for the zimbu parser everything will be disabled.

```lua
vim.g.ts_enable = {
  parsers = require('nvim-treesitter').get_available(),
  auto_install = true,
  highlights = true,
  folds = true,
  indents = true,
  parser_settings = {
    zimbu = {}
  },
}
```

The options in `parser_settings` take complete control over the features you want to enable. So an empty table (or vimscript object) will make `ts-enable.nvim` ignore the parser completely.

If you still want to use one feature of the parser but not others, then enable the ones you want.

```lua
vim.g.ts_enable = {
  parsers = require('nvim-treesitter').get_available(),
  auto_install = true,
  highlights = true,
  folds = true,
  indents = true,
  parser_settings = {
    zimbu = {auto_install = true, highlights = true},
  },
}
```

By the way, zimbu is not an actual parser available in nvim-treesitter. Is just a silly example.

## lazy.nvim configuration?

Sure. You can even use the `opts` table field if you like:

```lua
return {
  'VonHeikemen/ts-enable.nvim',
  lazy = false,
  dependencies = {
    {'nvim-treesitter/nvim-treesitter', branch = 'main'},
  },
  opts = {
    parsers = {'json', 'gleam', 'python'},
    auto_install = true,
    highlights = true,
    folds = false,
    indents = false,
  },
}
```

Fun fact: lazy.nvim's `opts` field will pass the data to `require('ts-enable').setup()` after the plugin is loaded. And this `.setup()` function just creates `vim.g.ts_enable` under the hood.

If you need to use `nvim-treesitter` to get the list of parsers use `opts` as a function.

```lua
opts = function()
  return {
    parsers = require('nvim-treesitter').get_available(),
    auto_install = true,
    highlights = true,
    folds = false,
    indents = false,
  }
end
```

## Does it support lazy loading?

Yes. Internally. So **you** don't have to do anything.

Can this be lazy loaded with `lazy.nvim`? Technically yes. But is not worth it. Just let the plugin create its own autocommand during the startup process.

## About `vim.g`

There is a funny thing about this mechanism: when you access a table field Neovim returns a copy. You can't just modify a nested table in-place.

To modify a value you have to replace the entire thing.

```lua
vim.g.ts_enable = {
  parsers = {'json', 'gleam', 'python'},
  auto_install = true,
  highlights = true,
}

-- Get a copy, modify it
local ts_enable = vim.g.ts_enable
ts_enable.auto_install = false

-- Replace the entire thing
vim.g.ts_enable = ts_enable
```

## Support

If you find this useful and want to support my efforts, you can donate in [ko-fi.com/vonheikemen](https://ko-fi.com/vonheikemen).

[![buy me a coffee](https://res.cloudinary.com/vonheikemen/image/upload/v1726766343/gzu1l1mx3ou7jmp0tkvt.webp)](https://ko-fi.com/vonheikemen)

