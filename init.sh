#!/bin/zsh

## Get sudo access to install all neccesary components
#info "This script requires sudo access in order to bootstrap."
#sudo -v
## TODO: Handle when user trys to bypass password prompt (fail)
#ok "Sudo access verified!"

# Install Homebrew
if ! which brew > /dev/null 2>&1; then
  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Do I need this?
  ## Add homebrew to path on Apple Silicon machines
  #if [[ cpu == *"Apple"* ]]; then
  #  info "Adding Homebrew to \$PATH..."
  #  (echo; echo 'export PATH="/opt/homebrew/bin:$PATH"') >> ~/.zshrc
  #  eval "$(/opt/homebrew/bin/brew shellenv)"
  #  ok "Homebrew added to \$PATH!"
  #fi
fi
ok "Homebrew installed!"

# Install Git
if ! brew list git &>/dev/null; then
    info "Installing Git..."
    brew install git
    ok "Git installed!"
else
    ok "Git is already installed. Continuing..."
fi

# Checkout .dotfiles repo and run ansible
if [ -d "$HOME/.dotfiles" ]; then
  warn "~/.dotfiles already exists.  Local copy may not be up to date with the latest."
else 
  info "Cloning .dotfiles repo..."
  cd $HOME
  git clone https://github.com/CrutchTheClutch/.dotfiles.git
fi

cd $HOME/.dotfiles

## Install Rosetta 2
#source ./scripts/rosetta2.sh

## Set up macOS defaults
#source ./scripts/macos.sh
