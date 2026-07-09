# Portable Neovim Configuration for macOS

This repository contains the complete Neovim configuration, including all
keymaps, plugins, LSP settings, formatting, persistent breakpoints, restored
buffers, ThemeHub, Trouble, Blink completion, and DAP support for Go, C/C++,
Rust, Zig, and JavaScript/TypeScript.

Plugin revisions are pinned in `lazy-lock.json`. Host dependencies are declared
in `Brewfile`; LSP servers, formatters, debug adapters, and Tree-sitter parsers
are installed by the bootstrap script.

## Install on another Mac

The bootstrap supports Apple Silicon and Intel Macs. It does not overwrite an
existing `~/.config/nvim`.

```sh
git clone https://github.com/anirban1809/nvim.git ~/src/nvim-config
~/src/nvim-config/scripts/bootstrap-macos.sh
```

The script:

1. Checks for the Xcode Command Line Tools.
2. Installs Homebrew when necessary.
3. Installs Neovim, Git, search/build tools, Go, Node.js, Zig, Rustup, and a Nerd Font.
4. Reuses an existing Rust toolchain, or installs Rustup when Rust is absent.
5. Links the checkout to `${XDG_CONFIG_HOME:-~/.config}/nvim`.
6. Installs the pinned plugins, Mason tools, and Tree-sitter parsers.
7. Runs a final health check and reports the exact failed installation stage.

If the Xcode Command Line Tools prompt appears, finish that installation and
run the script again.

The Nerd Font is optional. A pre-existing font conflict will produce a warning
but will not prevent Neovim, plugins, LSP servers, or debuggers from installing.

Legacy native packages and packer plugins are not loaded. This prevents old
copies under `stdpath("data")/site/pack` from shadowing the versions pinned by
`lazy-lock.json`.

## Repair or retry an installation

The bootstrap is idempotent. Pull the latest fixes and run it again:

```sh
cd ~/src/nvim-config
git pull --ff-only
./scripts/bootstrap-macos.sh
```

If the repository was cloned somewhere else, run the same commands from that
checkout. On failure, the script prints the exact installation stage that must
be addressed before retrying.

## Verify

Open Neovim and run:

```vim
:checkhealth portable
:checkhealth
```

The first command reports the dependencies specific to this configuration.

## What moves with the repository

- Every Lua configuration and keymap
- The complete plugin list and pinned plugin revisions
- The default Tokyo Night theme and ThemeHub integration
- Mason's required tool list
- Tree-sitter's required parser list
- The macOS dependency manifest and bootstrap script

## Machine-local state

The following data is intentionally regenerated on each Mac:

- Plugins: `stdpath("data")/lazy`
- Mason packages: `stdpath("data")/mason`
- Tree-sitter parsers: installed with the plugins
- ThemeHub downloads and selected theme: `stdpath("data")/theme-hub`
- Open-buffer history: `stdpath("state")/open-buffers.json`
- Persistent breakpoints: `stdpath("state")/dap-breakpoints.json`

Open buffers and breakpoints contain absolute project paths, so copying them
between Macs would make the installation less portable. ThemeHub persistence
starts from the tracked `tokyonight-storm` default; subsequent selections are
persisted on that Mac.

## Updating

Update plugins deliberately and commit the resulting lockfile:

```vim
:Lazy update
```

Re-run `scripts/bootstrap-macos.sh` after changing `Brewfile`, Mason's tool
list, or Tree-sitter's parser list.
