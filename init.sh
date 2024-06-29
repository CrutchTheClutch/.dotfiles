#!/bin/bash

# This script only supports macOS for the moment, may support linux in the future

# Logging helper functions
# NOTE: Needs to remain a remote url since this script may get executed outside of the .dotfiles repo
source <(curl -s https://raw.githubusercontent.com/CrutchTheClutch/.dotfiles/main/scripts/log.sh)

# 1: Get system information to determine how to proceed
# TODO: add linux support
os="$(uname -s)"
cpu="$(sysctl -n machdep.cpu.brand_string)"
year=$(sw_vers -buildVersion | cut -c 1,2)

case $os in
  Linux*)
      fail "Unsupported Linux distribution: ${os}"
    ;;

  Darwin*)
    ok "Supported operating system: macOS"
    ;;
  *)
    fail "Unsupported operating system: ${os}"
    ;;
esac

# 2: Install macOS dev tools
# NOTE: Needs to remain a remote url since this script may get executed outside of the .dotfiles repo
curl -s https://raw.githubusercontent.com/CrutchTheClutch/.dotfiles/main/scripts/xcode-select.sh | zsh

# 3. Checkout .dotfile repo at user root directory
info "Downloading .dotfiles..."
cd ~
git clone https://github.com/CrutchTheClutch/.dotfiles.git
cd ~/.dotfiles
ok "Download complete!"

info "Validating Homebrew..."

which -s brew
if [[ $? != 0 ]] ; then
    info "Homebrew not found, installing now..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

ok "Homebrew installed!"
info "Updating Homebrew..."
brew update
ok "Homebrew up to date!"

info "Installing Ansible..."
brew install ansible
ok "Ansible installed!"
