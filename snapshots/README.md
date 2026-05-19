# Snapshots

Each json file in this directory is a valid "parser info" file.

* `nvim-v0.9.json`: Contains a set of 26 parsers for Neovim v0.9 and v0.10. It uses [nvim-treesitter v0.10.0](https://github.com/nvim-treesitter/nvim-treesitter/tree/v0.10.0) as a source for query files.

* `nvim-v0.11.json`: Contains a set of 26 parsers for Neovim v0.11 and v0.12. Parsers should still work on v0.13, the current nightly version, but is not guaranteed. It uses the last commit in [nvim-treesitter's main branch](https://github.com/nvim-treesitter/nvim-treesitter/tree/main) as a source for query files.

* `nvim-treesitter-master.json`: Contains all the parsers in nvim-treesitter's v0.10.0. These parser are compatible with Neovim v0.9 and v0.10.

* `nvim-treesitter-main.json`: Contains all the parsers in the last commit of nvim-treesitter's main branch. These parser are compatible with Neovim v0.11 and v0.12.

