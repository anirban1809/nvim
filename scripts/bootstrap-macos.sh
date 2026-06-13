#!/bin/sh

set -eu

current_step="initial checks"
trap 'status=$?; printf "\nSetup failed during: %s\n" "$current_step" >&2; printf "Re-run this script after fixing the error above.\n" >&2; exit "$status"' 0

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

if ! xcode-select -p >/dev/null 2>&1; then
  current_step="Xcode Command Line Tools installation"
  printf '%s\n' "Installing the Xcode Command Line Tools..."
  xcode-select --install || true
  printf '%s\n' "Finish the Apple installer, then run this script again." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  current_step="Homebrew installation"
  printf '%s\n' "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if command -v brew >/dev/null 2>&1; then
  brew_executable=$(command -v brew)
elif [ -x /opt/homebrew/bin/brew ]; then
  brew_executable=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  brew_executable=/usr/local/bin/brew
else
  printf '%s\n' "Homebrew was installed but its executable could not be found." >&2
  exit 1
fi
eval "$("$brew_executable" shellenv)"
append_profile_line "eval \"\$($brew_executable shellenv)\""

current_step="Homebrew dependency installation"
printf '%s\n' "Installing macOS dependencies..."
brew bundle --file="$root_dir/Brewfile"

current_step="Nerd Font installation"
if ! brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
  if ! brew install --cask font-jetbrains-mono-nerd-font; then
    printf '%s\n' "Warning: Nerd Font installation failed; continuing without it." >&2
  fi
fi

current_step="Rust toolchain installation"
if ! command -v cargo >/dev/null 2>&1; then
  brew install rustup
  rustup_prefix=$(brew --prefix rustup)
  export PATH="$rustup_prefix/bin:$PATH"
  append_profile_line "export PATH=\"$rustup_prefix/bin:\$PATH\""
  if ! "$rustup_prefix/bin/rustup" toolchain list | grep -q '^stable'; then
    "$rustup_prefix/bin/rustup" toolchain install stable
  fi
  "$rustup_prefix/bin/rustup" default stable
  "$rustup_prefix/bin/rustup" component add rustfmt clippy
fi
if [ -d "$HOME/.cargo/bin" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
  append_profile_line 'export PATH="$HOME/.cargo/bin:$PATH"'
fi

current_step="host dependency verification"
for command_name in nvim git make cc rg fd go node npm tree-sitter; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command is unavailable after installation: %s\n' "$command_name" >&2
    exit 1
  fi
done

run_nvim() {
  step_name=$1
  shift
  current_step=$step_name
  printf '%s...\n' "$step_name"
  nvim --headless "$@"
}

run_nvim "Installing pinned Neovim plugins" "+Lazy! sync" +qa
run_nvim "Installing LSP servers, formatters, and debug adapters" \
  "+Lazy load nvim-lspconfig" "+MasonToolsInstallSync" +qa

current_step="final Neovim verification"
nvim --headless \
  "+Lazy load nvim-treesitter mason.nvim" \
  "+lua require('portable.verify').assert_ready()" \
  "+lua local path=vim.api.nvim_get_runtime_file('lua/tokyonight/init.lua', false)[1]; assert(path and path:find('/lazy/tokyonight.nvim/', 1, true), 'TokyoNight is shadowed by a legacy package: ' .. tostring(path))" \
  "+checkhealth portable" \
  "+lua local report=table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\\n'); assert(not report:find('ERROR',1,true), report)" \
  +qa

trap - 0
printf '\n%s\n' "Neovim is ready. Run :checkhealth portable for a dependency report."
