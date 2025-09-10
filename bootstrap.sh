#!/usr/bin/env bash
set -euo pipefail

# ===== settings =====
REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"
STOW_PACKAGES=("tmux" "nvim")
BREW_FORMULAE=(
  git stow tmux neovim ripgrep fzf
  tree htop curl wget
)

log() { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; exit 1; }

backup_if_real_file() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local bak="${target}.bak.${ts}"
    mv "$target" "$bak"
    warn "Backed up $target -> $bak"
  fi
}

ensure_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  command -v brew >/dev/null || die "brew not found after installation"
}

install_formulae() {
  log "Installing CLI tools with Homebrew…"
  brew update
  brew install "${BREW_FORMULAE[@]}"

  # fzf key bindings & completion
  if command -v fzf >/dev/null 2>&1; then
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-bash --no-fish --no-update-rc
  fi
}

stow_package() {
  local pkg="$1"
  [[ -d "$REPO_DIR/$pkg" ]] || { warn "Skip: $pkg not found in $REPO_DIR"; return; }

  case "$pkg" in
    tmux)
      backup_if_real_file "$HOME/.tmux.conf"
      ;;
    nvim)
      mkdir -p "$HOME/.config"
      backup_if_real_file "$HOME/.config/nvim"
      ;;
  esac

  (cd "$REPO_DIR" && stow -v -t "$HOME" "$pkg")
}

main() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This bootstrap is for macOS only."
  [[ -d "$REPO_DIR" ]] || die "Repo dir not found: $REPO_DIR"

  log "Bootstrap starting (repo: $REPO_DIR)…"
  ensure_homebrew
  install_formulae

  log "Linking dotfiles with stow…"
  for pkg in "${STOW_PACKAGES[@]}"; do
    stow_package "$pkg"
  done

  log "All done ✅  Open a new terminal (or 'exec zsh') to pick up shell changes."
}

main "$@"
