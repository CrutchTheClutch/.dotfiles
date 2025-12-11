#!/bin/zsh

install_rosetta() {
    if ! is_apple_silicon; then
        ok "Rosetta2 not required (Intel Mac)"
        return
    fi

    local rosetta_folder="/Library/Apple/usr/share/rosetta"

    if pgrep -q oahd && [[ -d "$rosetta_folder" ]]; then
        ok "Rosetta2 already installed"
    else
        info "Installing Rosetta2..."
        softwareupdate --install-rosetta --agree-to-license
        ok "Rosetta2 installed"
    fi
}

install_rosetta
