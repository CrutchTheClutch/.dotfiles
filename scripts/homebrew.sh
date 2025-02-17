#!/bin/zsh

info "Running brew doctor..."
brew doctor

info "Updating Homebrew..."
brew update

info "Upgrading all formulae..."
brew upgrade

ok "Homebrew is up to date"
