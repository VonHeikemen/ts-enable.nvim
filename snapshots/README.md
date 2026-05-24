# Snapshots

Each json file in this directory is a valid "parser info" file.

* `nvim-v0.9.json`: Contains a set of 26 parsers for Neovim v0.9 and v0.10. It uses [nvim-treesitter v0.10.0 tag](https://github.com/nvim-treesitter/nvim-treesitter/tree/v0.10.0) as a source for query files.

* `nvim-v0.11.json`: Contains a set of 26 parsers for Neovim v0.11 and v0.12. Parsers should still work on v0.13, the current nightly version, but is not guaranteed. It uses the last commit in [nvim-treesitter's main branch](https://github.com/nvim-treesitter/nvim-treesitter/tree/main) as a source for query files.

* `nvim-treesitter-master.json`: Contains all the parsers in nvim-treesitter's v0.10.0 tag. These parser are compatible with Neovim v0.9 and v0.10.

* `nvim-treesitter-main.json`: Contains all the parsers in the last commit of nvim-treesitter's main branch. These parser are compatible with Neovim v0.11 and v0.12.

## auto_init

When the `auto_init` option is set to `true` one of the files that starts with `nvim-v0` will be used as an initial parser info file. `ts-enable.nvim` will choose the one that is appropiate for your Neovim version. These are the languages included:

| Language   | Parser | Queries |
| ---        | ---    | ---     |
| bash       | ✔      | ✔       |
| c          | ✔      | ✔       |
| c_sharp    | ✔      | ✔       |
| cpp        | ✔      | ✔       |
| css        | ✔      | ✔       |
| ecma       | ✗      | ✔       |
| go         | ✔      | ✔       |
| gomod      | ✔      | ✔       |
| gosum      | ✔      | ✔       |
| html       | ✔      | ✔       |
| html_tags  | ✗      | ✔       |
| java       | ✔      | ✔       |
| javascript | ✔      | ✔       |
| jsx        | ✗      | ✔       |
| lua        | ✔      | ✔       |
| php        | ✔      | ✔       |
| php_only   | ✔      | ✔       |
| powershell | ✔      | ✔       |
| python     | ✔      | ✔       |
| ruby       | ✔      | ✔       |
| rust       | ✔      | ✔       |
| sql        | ✔      | ✔       |
| tsx        | ✔      | ✔       |
| typescript | ✔      | ✔       |
| vim        | ✔      | ✔       |
| vimdoc     | ✔      | ✔       |

Note some languages are "query only" which means there isn't an actual parser that needs to be compiled. Only the query files are installed.

You can add more languages to the parser info file manually. Just copy/paste the necessary data from one of the `nvim-treesitter-*.json` files into your own parser info file.

