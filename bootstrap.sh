#!/usr/bin/env bash
set -euo pipefail

# ===== settings =====
REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"
STOW_PACKAGES=("tmux" "nvim" "ghostty")
BREW_FORMULAE=(
	git stow tmux neovim ripgrep fzf
	tree htop curl wget
)
BREW_CASKS=(
	ghostty font-jetbrains-mono
)

# Set ALL_YES=1 to auto-answer "yes" to every install prompt
ALL_YES="${ALL_YES:-0}"

log() { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
die() {
	printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2
	exit 1
}

ask_yes_no() {
	local prompt="$1"
	if [[ "$ALL_YES" == "1" ]]; then
		return 0
	fi
	local ans
	read -r -p "$prompt [y/N]: " ans || true
	case "$ans" in
	y | Y | yes | YES) return 0 ;;
	*) return 1 ;;
	esac
}

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

is_formula_installed() {
	local f="$1"
	brew list --formula --versions "$f" >/dev/null 2>&1
}

is_cask_installed() {
	local c="$1"
	brew list --cask --versions "$c" >/dev/null 2>&1
}

install_formulae() {
	log "Installing CLI tools with Homebrew…"
	brew update

	for formula in "${BREW_FORMULAE[@]}"; do
		if is_formula_installed "$formula"; then
			log "$formula already installed, skipping"
			continue
		fi
		if ask_yes_no "Install formula: $formula?"; then
			log "Installing $formula"
			brew install "$formula"
		else
			warn "Skipped $formula"
		fi
	done

	log "Installing casks (apps)…"
	for cask in "${BREW_CASKS[@]}"; do
		if is_cask_installed "$cask"; then
			log "$cask already installed, skipping"
			continue
		fi
		if ask_yes_no "Install cask: $cask?"; then
			log "Installing $cask"
			brew install --cask "$cask"
		else
			warn "Skipped $cask"
		fi
	done

	# fzf key bindings & completion (only if fzf got installed)
	if command -v fzf >/dev/null 2>&1; then
		"$(brew --prefix)/opt/fzf/install" \
			--key-bindings --completion --no-bash --no-fish --no-update-rc
	fi
}

stow_package() {
	local pkg="$1"
	[[ -d "$REPO_DIR/$pkg" ]] || {
		warn "Skip: $pkg not found in $REPO_DIR"
		return
	}

	case "$pkg" in
	tmux)
		backup_if_real_file "$HOME/.tmux.conf"
		;;
	nvim)
		mkdir -p "$HOME/.config"
		backup_if_real_file "$HOME/.config/nvim"
		;;
	ghostty)
		mkdir -p "$HOME/.config"
		backup_if_real_file "$HOME/.config/ghostty/config"
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
