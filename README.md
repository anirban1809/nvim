# Neovim Configuration

A personal Neovim setup built on [lazy.nvim](https://github.com/folke/lazy.nvim),
with LSP, Treesitter, Telescope, completion, formatting, and DAP debugging
(Go, C/C++/Rust, JS/TS) configured out of the box.

## Requirements

- **Neovim ≥ 0.11** (developed on 0.12)
- `git`, `make`, and a C compiler — for building Treesitter parsers and
  `telescope-fzf-native`
- [`ripgrep`](https://github.com/BurntSushi/ripgrep) and
  [`fd`](https://github.com/sharkdp/fd) — used by Telescope
- A [Nerd Font](https://www.nerdfonts.com/) for icons

Language tooling (LSP servers, debug adapters, formatters) is installed
automatically via [Mason](https://github.com/williamboman/mason.nvim).

## Install

Back up any existing configuration first:

```sh
mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null
```

Then clone this repository into place and launch Neovim:

```sh
git clone <repository-url> ~/.config/nvim
nvim
```

On first launch, lazy.nvim bootstraps itself and installs all plugins. The
pinned versions in `lazy-lock.json` are used for a reproducible setup.

## Layout

```
init.lua            -- entry point
lazy-lock.json      -- pinned plugin versions
lua/config/         -- options, keymaps, autocmds, lazy bootstrap
lua/plugins/        -- one spec per concern (lsp, treesitter, telescope, dap, …)
```
