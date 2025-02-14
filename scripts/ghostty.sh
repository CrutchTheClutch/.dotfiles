#!/bin/zsh

if brew list --cask ghostty &>/dev/null; then
    if brew outdated --cask 2>/dev/null | grep -q "ghostty"; then
        info "Updating Ghostty..."
        brew install ghostty --cask --force >/dev/null 2>&1
        ok "Ghostty updated successfully"
    else
        ok "Latest version of Ghostty is already installed"
    fi
else
    info "Installing Ghostty..."
    brew install ghostty --cask --force >/dev/null 2>&1
    ok "Ghostty installed successfully"
fi
