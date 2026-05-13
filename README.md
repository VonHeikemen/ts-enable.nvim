# TS-enable

This plugin will help you enable features that depend on [treesitter](#what-is-treesitter).

>[!IMPORTANT]
> The v2.x branch is a work in progress. It should be in a functional state but it still needs some testing.

The idea here is to be able to use treesitter by setting a few variables. For example:

```vim
" This is vimscript, by the way
let g:ts_enable = {
\ 'auto_init': v:true,
\ 'auto_install': v:true,
\ 'highlights': v:true
\}
```

That's it. `ts-enable.nvim` will [take care of the details](#ts-enablenvim-is-not-strictly-needed).

If you prefer lua, don't worry. You can use `vim.g.ts_enable` in your configuration. I also added a thing to make it compatible with `lazy.nvim`'s option API.

## Requirements

* Neovim v0.9.5 or greater
  * v0.12 is recommended
* git
* [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter)
* A C compiler
  * Needed by the [tree-sitter build](https://tree-sitter.github.io/tree-sitter/cli/build.html) command.

## Installation

Use your favorite plugin manager to install `ts-enable.nvim`.

* vim-plug

  ```vim
  Plug 'VonHeikemen/ts-enable.nvim', { 'branch': 'v2.x' }
  ```

* mini.deps

  ```lua
  MiniDeps.add({
    source = 'VonHeikemen/ts-enable.nvim',
    checkout = 'v2.x',
  })
  ```

* vim.pack

  ```lua
  vim.pack.add({
    {
      src = 'https://github.com/VonHeikemen/ts-enable.nvim',
      version = 'v2.x',
    },
  })
  ```

## Configuration

This plugin should be configured using a **vim global variable** called `ts_enable`. You can create that variable anywhere you want. `init.lua`, `init.vim` or any random script that Neovim can pick up during the startup process.

Here's example using all the default values as reference.

```vim
" These are the default values. Change them as you see fit.
let g:ts_enable = {
\ 'auto_init': v:false,
\ 'auto_install': v:false,
\ 'highlights': v:false,
\ 'folds': v:false,
\ 'parser_info': stdpath('config') . '/treesitter-parsers.json',
\ 'parser_settings': {},
\}
```

In a lua file to create a vim global use `vim.g`. In this case assign a lua table with the settings you want.

```lua
-- These are the default values. Change them as you see fit.
vim.g.ts_enable = {
  auto_init = false,
  auto_install = false,
  highlights = false,
  folds = false,
  parser_info = vim.fn.stdpath('config') .. '/treesitter-parsers.json',
  parser_settings = {},
}
```

* `auto_init`: Boolean. Generate a "parser info" file if it's missing.

* `auto_install`: Boolean. If enabled install a missing parser from the "parser info" file.

* `highlights`: Boolean. If enabled use `vim.treesitter.start()` to enable treesitter based syntax highlight.

* `folds`: Boolean. If enabled set the option `foldexpr` to use treesitter.

* `parser_info`: String. Absolute path to the parser info file.

* `parser_settings`: Table. Override global config for a specific parser.

## Usage

For the casual Neovim enjoyer I would recommend this configuration.

```lua
-- This is lua, by the way
vim.g.ts_enable = {
  auto_init = true,
  auto_install = true,
  highlights = true,
}
```

The `auto_init` option will generate an initial "parser info" file with a list of 26 treesitter parsers. This will be a json file located in Neovim's configuration directory. By default it'll be called `treesitter-parsers.json`. Since `auto_install` is set to `true` the parsers will be installed when needed, meaning that a parser would only be installed if you open a file that needs it. To know more about the parser info file see [the help page](https://github.com/VonHeikemen/ts-enable.nvim/blob/v2.x/doc/ts-enable.txt), or execute the command `:help ts-enable-parser-info` inside Neovim.

You can add or remove parsers from the parser info file if you want. You can find more parsers in the [snapshots directory](https://github.com/VonHeikemen/ts-enable.nvim/tree/v2.x/snapshots) of this plugin. Note that removing a parser from `treesitter-parsers.json` does not delete it, it'll just be ignored.

You can remove all the installed files using the command `:TSEnableRemove {name}`, where `{name}` must be a valid parser.

When it comes to updating parsers I would advice you to adopt the philosophy "if it ain't broke, don't fix it." If things are working just fine, keep it that way. If you are using a stable version of Neovim there is no need to update parsers until the next stable version is released. And even then, installed parsers could still work on that future stable version.

To update a parser you can use the command `:TSEnableUpdate {name}`. If `{name}` is omitted all installed parsers will be updated. Note `treesitter-parsers.json` would not be updated automatically with the new version. That file is yours, you control when it should be updated. That is to ensure you can rollback to a previous version if an update goes wrong.

If you are sure the updated parsers work just fine and want to update `treesitter-parsers.json` to reflect the new state, use the command `:TSEnableSync`.

## Notes

### What is treesitter?

Here I'll give you a summary. For more details you can read this: [Treesitter in Neovim](https://vonheikemen.github.io/learn-nvim/feature/treesitter.html).

The main purpose of treesitter is to read the source code of a file and turn that into a data structure. Why? Because it's easier to extract information from structured data than plain text. And what do **we** do with this data thing? Us, casual Neovim users, we do nothing. Neovim mantainers and plugin authors are the ones who use it to implement the features **we** will interact with.

Language support is where things get interesting. Treesitter is not a miracle silver bullet that supports every programming language. We add support for a language by installing the appropiate "treesitter parser," which is the component that deals with the specific syntax of a language.

### ts-enable.nvim is not strictly needed

If you don't mind having a bit of code in your personal configuration, you could skip `ts-enable.nvim` entirely. Just install treesitter parsers (and queries) ahead of time and mantain your own autocommand with the features you want to enable.

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
    vim.wo[0][0].foldmethod = 'expr'
    vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  end
})
```

## Disable a parser

You can override the configuration for a parser using `parser_settings`.

In the following example all the features are enable on the global config, but for the zimbu parser everything will be disabled.

```lua
vim.g.ts_enable = {
  auto_init = true,
  auto_install = true,
  highlights = true,
  folds = true,
  parser_settings = {
    zimbu = {}
  },
}
```

The options in `parser_settings` take complete control over the features you want to enable. So an empty table (or vimscript object) will make `ts-enable.nvim` ignore the parser completely.

If you still want to use one feature of the parser but not others, then enable the ones you want.

```lua
vim.g.ts_enable = {
  auto_init = true,
  auto_install = true,
  highlights = true,
  folds = true,
  parser_settings = {
    zimbu = {auto_install = true, highlights = true},
  },
}
```

By the way, zimbu is not an actual parser available, is just a silly example.

## lazy.nvim configuration?

Sure. You can even use the `opts` table field if you like:

```lua
return {
  'VonHeikemen/ts-enable.nvim',
  lazy = false,
  opts = {
    auto_init = true,
    auto_install = true,
    highlights = true,
    folds = false,
  },
}
```

Fun fact: lazy.nvim's `opts` field will pass the data to `require('ts-enable').setup()` after the plugin is loaded. And this `.setup()` function just creates `vim.g.ts_enable` under the hood.

## Does it support lazy loading?

Yes. Internally. So **you** don't have to do anything.

Can this be lazy loaded with `lazy.nvim`? Technically yes. But is not worth it. Just let the plugin create its own autocommand during the startup process.

## About `vim.g`

There is a funny thing about this mechanism: when you access a table field Neovim returns a copy. You can't just modify a nested table in-place.

To modify a value you have to replace the entire thing.

```lua
vim.g.ts_enable = {
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

