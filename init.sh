#!/bin/zsh

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

# logging utilities
log() { printf "[\033[0;$1m$2\033[0m] %s\n" "$3"; }
info() { log 96 "INFO" "$1"; }
warn() { log 93 "WARN" "$1"; }
error() { log 91 "FAIL" "$1"; }
fail() { error "$1"; exit 1; }
ok() { log 92 " OK " "$1"; }
debug() { log 90 "DEBUG" "$1"; }

# os detection
is_macos() { [[ "$OSTYPE" == darwin* ]]; }
is_linux() { [[ "$OSTYPE" == linux* ]]; }

# cpu detection
is_apple_silicon() { is_macos && [[ "$(uname -m)" == "arm64" ]]; }

get_cpu() {
    if is_macos; then
        sysctl -n machdep.cpu.brand_string
    elif is_linux; then
        grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs
    fi
}

# Request sudo upfront
request_sudo() {
    info "Some operations require sudo access. Please enter your password if prompted";
    sudo -v;
    
    # keep sudo alive in the background
    (while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &)
}

brew_path() {
    if is_apple_silicon; then
        echo "/opt/homebrew/bin/brew"
    else
        echo "/usr/local/bin/brew"
    fi
}

install_homebrew() {
    local brew_bin
    brew_bin="$(brew_path)"

    if [[ -x "$brew_bin" ]]; then
        ok "Homebrew already installed"
    else
        info "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        ok "Homebrew installed"
    fi

    if ! command -v brew &>/dev/null; then
        eval "$("$brew_bin" shellenv)"
    fi
}

brewi() {
    local package="$1"
    local cask_flag="${2:+--cask}"

    if brew list $cask_flag "$package" &>/dev/null; then
        if brew outdated $cask_flag 2>/dev/null | grep -q "^${package}"; then
            info "Upgrading $package..."
            brew upgrade $cask_flag "$package"
            ok "$package upgraded"
        else
            ok "$package up to date"
        fi
    else
        info "Installing $package..."
        brew install $cask_flag "$package"
        ok "$package installed"
    fi
}

sync_dotfiles() {
    if [[ -d "$DOTFILES/.git" ]]; then
        info "Updating dotfiles..."
        git -C "$DOTFILES" pull --ff-only
        ok ".dotfiles updated"
    else
        info "Cloning dotfiles..."
        git clone https://github.com/CrutchTheClutch/.dotfiles.git "$DOTFILES"
        ok ".dotfiles cloned"
    fi
}

map_downloads_to_icloud() {
    local icloud_root="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
    local icloud_downloads="$icloud_root/Downloads"
    local downloads_path="$HOME/Downloads"
    local backup_path

    if [[ ! -d "$icloud_root" ]]; then
        warn "Skipping Downloads -> iCloud mapping because iCloud Drive is not available"
        return
    fi

    mkdir -p "$icloud_downloads"

    if [[ -L "$downloads_path" ]]; then
        if [[ "$(readlink "$downloads_path")" == "$icloud_downloads" ]]; then
            ok "Downloads already mapped to iCloud"
            return
        fi

        backup_path="${downloads_path}.backup.$(date +%Y%m%d%H%M%S)"
        info "Backing up existing Downloads symlink to $(basename "$backup_path")..."
        mv "$downloads_path" "$backup_path"
    elif [[ -e "$downloads_path" ]]; then
        backup_path="${downloads_path}.backup.$(date +%Y%m%d%H%M%S)"
        info "Backing up existing Downloads folder to $(basename "$backup_path")..."
        sudo mv "$downloads_path" "$backup_path"

        if [[ -d "$backup_path" ]]; then
            info "Copying existing Downloads contents into iCloud..."
            rsync -a "$backup_path"/ "$icloud_downloads"/
        fi
    fi

    ln -s "$icloud_downloads" "$downloads_path"
    ok "Downloads mapped to iCloud"
}

install_packages() {
    # formulae
    #brewi neofetch
    #brewi neovim

    # casks
    brewi 1password --cask
    #brewi ableton-live-suite@11 --cask
    #brewi adobe-creative-cloud --cask
    brewi appcleaner --cask
    #brewi bambu-studio --cask
    #brewi beekeeper-studio --cask
    #brewi cursor --cask
    #brewi dotnet --cask
    brewi ghostty --cask  # TODO: Give full disk access.  Is this possible?
    #brewi gitkraken --cask
    #brewi godot --cask
    brewi google-chrome --cask
    #brewi handbrake --cask
    #brewi iina --cask
    #brewi imazing --cask
    #brewi izotope-product-portal --cask
    #brewi linear-linear --cask
    #brewi native-access --cask
    #brewi osquery --cask
    #brewi parallels --cask
    #brewi powershell --cask
    brewi raycast --cask
    brewi slack --cask
    brewi superhuman --cask
    #brewi utm --cask
    #brewi waves-central --cask
    #brewi xnapper --cask
    #brewi wifi-explorer-pro --cask
    #brewi zoom --cask

    #check_casks
}

main() {
    if ! is_macos; then
        fail "This script currently only supports macOS"
    fi

    request_sudo

    install_homebrew
    brewi git
    sync_dotfiles

    source "$DOTFILES/scripts/rosetta2.sh"
    source "$DOTFILES/scripts/macos.sh"
    source "$DOTFILES/scripts/homebrew.sh"

    map_downloads_to_icloud
    install_packages
}

main
