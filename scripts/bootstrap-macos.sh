#!/bin/sh

set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  printf '%s\n' "This bootstrap script supports macOS only." >&2
  exit 1
fi

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
config_dir="$config_home/nvim"
shell_profile="$HOME/.zprofile"

append_profile_line() {
  line=$1
  touch "$shell_profile"
  if ! grep -Fqx "$line" "$shell_profile"; then
    printf '\n%s\n' "$line" >> "$shell_profile"
  fi
}

if ! xcode-select -p >/dev/null 2>&1; then
  printf '%s\n' "Installing the Xcode Command Line Tools..."
  xcode-select --install || true
  printf '%s\n' "Finish the Apple installer, then run this script again." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  printf '%s\n' "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ -x /opt/homebrew/bin/brew ]; then
  brew_executable=/opt/homebrew/bin/brew
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  brew_executable=/usr/local/bin/brew
  eval "$(/usr/local/bin/brew shellenv)"
else
  brew_executable=$(command -v brew)
fi
append_profile_line "eval \"\$($brew_executable shellenv)\""

printf '%s\n' "Installing macOS dependencies..."
brew bundle --file="$root_dir/Brewfile"

rustup_prefix=$(brew --prefix rustup)
export PATH="$rustup_prefix/bin:$PATH"
append_profile_line "export PATH=\"$rustup_prefix/bin:\$PATH\""
if [ -x "$rustup_prefix/bin/rustup" ]; then
  if ! "$rustup_prefix/bin/rustup" toolchain list | grep -q '^stable'; then
    "$rustup_prefix/bin/rustup" toolchain install stable
  fi
  "$rustup_prefix/bin/rustup" default stable
  "$rustup_prefix/bin/rustup" component add rustfmt clippy
fi

mkdir -p "$config_home"
if [ "$root_dir" != "$config_dir" ]; then
  if [ -e "$config_dir" ] || [ -L "$config_dir" ]; then
    existing_dir=$(CDPATH= cd -- "$config_dir" 2>/dev/null && pwd -P || true)
    if [ "$existing_dir" != "$root_dir" ]; then
      printf 'Refusing to replace existing configuration: %s\n' "$config_dir" >&2
      exit 1
    fi
  else
    ln -s "$root_dir" "$config_dir"
  fi
fi

printf '%s\n' "Installing pinned Neovim plugins..."
nvim --headless "+Lazy! sync" +qa

printf '%s\n' "Installing Tree-sitter parsers..."
nvim --headless "+Lazy load nvim-treesitter" "+TSUpdateSync" +qa

printf '%s\n' "Installing LSP servers, formatters, and debug adapters..."
nvim --headless "+Lazy load nvim-lspconfig" "+MasonToolsInstallSync" +qa

printf '\n%s\n' "Neovim is ready. Run :checkhealth portable for a dependency report."
