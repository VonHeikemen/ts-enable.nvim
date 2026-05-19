# TS-enable

This plugin will help you enable features that depend on [treesitter](#what-is-treesitter).

The idea here is to be able to use treesitter by setting a few variables. For example:

```vim
" This is vimscript, by the way
let g:ts_enable = {
\ 'auto_init': v:true,
\ 'auto_install': v:true,
\ 'highlights': v:true
\}
```

That's it. `ts-enable.nvim` will [take care of the details](#ts-enablenvim-is-not-strictly-needed). Treesitter parsers and queries can be installed automatically. And it can also enable the opt-in builtin features, like syntax highlight and folds.

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
\ 'regex_syntax': v:false,
\ 'folds': v:false,
\ 'parser_info': stdpath('config') . '/treesitter-parsers.json',
\ 'parser_settings': {},
\}
```

In a lua file, to create a vim global use `vim.g`. In this case assign a lua table with the settings you want.

```lua
-- These are the default values. Change them as you see fit.
vim.g.ts_enable = {
  auto_init = false,
  auto_install = false,
  highlights = false,
  regex_syntax = false,
  folds = false,
  parser_info = vim.fn.stdpath('config') .. '/treesitter-parsers.json',
  parser_settings = {},
}
```

* `auto_init`: Boolean. Generate a "parser info" file if it's missing.

* `auto_install`: Boolean. If enabled install a missing parser from the "parser info" file.

* `highlights`: Boolean. If enabled use `vim.treesitter.start()` to enable treesitter based syntax highlight. Note this will switch off regex based syntax which some old plugins may still use.

* `regex_syntax`: Boolean. If enabled switch on regex based syntax after executing `vim.treesitter.start()`.

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

The `auto_init` option will generate an initial "parser info" file with a list of 26 treesitter parsers. This will be a json file located in Neovim's configuration directory. By default it'll be called `treesitter-parsers.json`. Since `auto_install` is set to `true` a parser will be installed if you open a file that needs it. To know more about the parser info file see [the help page](https://github.com/VonHeikemen/ts-enable.nvim/blob/v2.x/doc/ts-enable.txt), or execute the command `:help ts-enable-parser-info` inside Neovim.

You can add or remove parsers from the parser info file if you want. You can find more parsers in the [snapshots directory](https://github.com/VonHeikemen/ts-enable.nvim/tree/v2.x/snapshots) of this plugin. Note that removing a parser from `treesitter-parsers.json` does not delete it, it'll just be ignored.

You can remove all the installed files using the command `:TSEnableRemove {name}`, where `{name}` must be a valid parser.

When it comes to updating parsers I would advice you to adopt the philosophy "if it ain't broke, don't fix it." If things are working just fine, keep it that way. If you are using a stable version of Neovim there is no need to update parsers until the next stable version is released. And even then, installed parsers could still work on that future stable version.

To update a parser you can use the command `:TSEnableUpdate {name}`. If `{name}` is omitted all installed parsers will be updated. Note `treesitter-parsers.json` would not be updated automatically with the new version. That file is yours, you control when it should be updated. That is to ensure you can rollback to a previous version if an update goes wrong.

If you are sure the updated parsers work just fine and want to update `treesitter-parsers.json` to reflect the new state, use the command `:TSEnableSync`.

## Notes

### What is treesitter?

Here I'll give you a summary. For more details you can read this: [Treesitter in Neovim](https://vonheikemen.github.io/learn-nvim/feature/treesitter.html).

The main purpose of treesitter is to read the source code of a file and turn that into a data structure. Why? Because it's easier to extract information from structured data than plain text. And what do **we** do with this data thing? Us, casual Neovim users, we do nothing. Neovim maintainers and plugin authors are the ones who use it to implement the features **we** will interact with.

Language support is where things get interesting. Treesitter is not a miracle silver bullet that supports every programming language. We add support for a language by installing the appropiate "treesitter parser," which is the component that deals with the specific syntax of a language.

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

## ts-enable.nvim is not strictly needed

If you choose to live a plugin-free life and still want to use treesitter, you need to know how things work. I'll show you an example.

Before you start, make sure you have the [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter) available in your system. And also a C compiler.

Now find the git repository of a parser. I'll use the [bash parser](https://github.com/tree-sitter/tree-sitter-bash) as an example. So, download it somehow. A simple `git clone` would work just fine.

```sh
git clone https://github.com/tree-sitter/tree-sitter-bash
```

Navigate to the directory you just downloaded.

```sh
cd tree-sitter-bash
```

Here you can compile the treesitter parser. Usually this command is enough.

```sh
tree-sitter build -o parser.so
```

You'll want to put `parser.so` somewhere in Neovim's runtime path. Your configuration directory can be an option.

```sh
cp parser.so ~/.config/nvim/parser/bash.so
```

For brevity, I will assume a you are using a linux system. Remember this is just an example. If your system is different, adjust accordingly.

Anyway, the parser must be in a directory called `parser`. And the name of the file becomes the name of the parser.

In most cases the name of the parser is used to determine the filetype where is going to be used. But because `bash` is not an actual name of a filetype we must "register" the filetype of the parser. So, in your Neovim configuration you can add this.

```lua
vim.treesitter.language.register('bash', {'sh'})
```

Here we tell Neovim to use the `bash` parser whenever we open a file with filetype `sh`.

Next you need the treesitter queries for the feature you want to use. The bash parser only has highlight queries builtin. See the [queries directory](https://github.com/tree-sitter/tree-sitter-bash/tree/a06c2e4415e9bc0346c6b86d401879ffb44058f7/queries) in the github repository. That lonely `highlights.scm` file should also be in Neovim's runtime path. So, copy it.

```sh
cp ./queries/highlights.scm ~/.config/nvim/queries/bash/highlights.scm
```

Treesitter queries need to be in a directory called `queries`. The query files for a parser must be in a sub-directory that has the same name as the parser.

Now you need to enable the feature in Neovim itself. The bash parser only has queries highlights so that's the one you can enable. Do this in your personal configuration.

```lua
-- NOTE: It is important that you install treesitter parsers and queries.
-- Otherwise none of this will work.

-- Neovim filetypes where you want to enable treesitter
local ts_filetypes = {'sh'}

vim.api.nvim_create_autocmd('FileType', {
  desc = 'Enable treesitter features',
  pattern = ts_filetypes,
  callback = function()
    -- enable syntax highlight
    vim.treesitter.start()
  end
})
```

One last thing... treesitter parsers can be incompatible with your Neovim version. If the parser is too new and your Neovim is too old, that could be a problem.

Now you have all the knowledge needed to use treesitter without plugins.

## Support

If you find this useful and want to support my efforts, you can donate in [ko-fi.com/vonheikemen](https://ko-fi.com/vonheikemen).

[![buy me a coffee](https://res.cloudinary.com/vonheikemen/image/upload/v1726766343/gzu1l1mx3ou7jmp0tkvt.webp)](https://ko-fi.com/vonheikemen)

