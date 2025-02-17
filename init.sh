#!/bin/zsh

# logging utilities
log() { printf "[\033[0;$1m$2\033[0m] %s\n" "$3"; }
info() { log 96 "INFO" "$1"; }
warn() { log 93 "WARN" "$1"; }
error() { log 91 "FAIL" "$1"; }
fail() { error "$1"; exit 1; }
ok() { log 92 " OK " "$1"; }
debug() { log 90 "DEBUG" "$1"; }

# os detection utilities
is_osx() { [[ "$OSTYPE" == "darwin"* ]]; }
is_m1() { [[ $(get_cpu) == *"Apple"* ]]; }
is_linux() { [[ "$OSTYPE" == "linux"* ]]; }

# system info utilities
get_cpu() { sysctl -n machdep.cpu.brand_string; } # TODO Add linux support

# Request sudo upfront
request_sudo() {
    info "Some operations require sudo access. Please enter your password if prompted";
    sudo -v;
    
    # keep sudo alive in the background
    (while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &)
}

# homebrew installation
install_homebrew() {
  if ! which brew > /dev/null 2>&1; then
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add temporary homebrew alias for initial install
    # we will properly add this with our .dotfiles
    if is_m1; then
      alias brew="/opt/homebrew/bin/brew";
    else
      alias brew="/usr/local/bin/brew";
    fi

    ok "Homebrew installed successfully"
  else
    ok "Homebrew is already installed"
  fi
}

brewi() {
    local package=$1
    local is_cask=""
    if [ "$2" = "--cask" ]; then
        is_cask="--cask"
    fi

    if brew list $is_cask $package 2>&1; then
        if brew outdated $is_cask 2>&1 | grep -q "^$package\$"; then
            info "Updating $package..."
            brew upgrade $is_cask $package 2>&1
            ok "$package updated successfully"
        else
            ok "$package is installed and up to date"
        fi
    else
        info "Installing $package..."
        brew install $is_cask $package --force 2>&1
        ok "$package installed successfully"
    fi
}

# clone repo
clone_repo() {
  if [ -d "$HOME/.dotfiles" ]; then
    warn "~/.dotfiles already exists"
  else 
    info "Cloning .dotfiles repo..."
    cd $HOME
    git clone https://github.com/CrutchTheClutch/.dotfiles.git
    ok ".dotfiles repo cloned"
  fi
}

# only support osx for now
if ! is_osx; then
  fail "This script currently only supports macOS"
fi

# request sudo upfront
request_sudo;

# install dependencies
install_homebrew;
brewi git;
clone_repo;

# source remaining scripts (order is important)
source $HOME/.dotfiles/scripts/rosetta2.sh;
source $HOME/.dotfiles/scripts/macos.sh;
source $HOME/.dotfiles/scripts/homebrew.sh;

# install brew formulae
brewi neovim;

# install brew packages
brewi ghostty --cask;
brewi gitkraken --cask;
brewi raycast --cask;
brewi superhuman --cask;
brewi google-chrome --cask;
brewi slack --cask;

# check remaining apps vs casks
check_casks;
