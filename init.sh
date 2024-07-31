#!/bin/zsh
# TODO: add bash support

# Use external logging utility script
#LOG_URL="https://raw.githubusercontent.com/CrutchTheClutch/.dotfiles/HEAD/scripts/log.sh"
#LOG_SCRIPT=$(mktemp)
#curl -s $LOG_URL -o $LOG_SCRIPT
#source $LOG_SCRIPT
#rm $LOG_SCRIPT
if [[ -z "$LOG_FUNCTIONS_LOADED" ]]; then
    LOG_SCRIPT_URL="https://raw.githubusercontent.com/CrutchTheClutch/.dotfiles/HEAD/scripts/log.sh"
    curl -s "$LOG_SCRIPT_URL" -o /tmp/log.sh
    source /tmp/log.sh
    export LOG_FUNCTIONS_LOADED=true
fi

# Get system information to determine how to proceed
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

# Get sudo access to install all neccesary components
info "This script requires sudo access in order to bootstrap."
sudo -v
# TODO: Handle when user trys to bypass password prompt (fail)
ok "Sudo access verified!"

# Install Homebrew
info "Validating Homebrew..."
if ! which brew > /dev/null 2>&1; then
  info "Homebrew not found, installing..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add homebrew to path on Apple Silicon machines
  if [[ cpu == *"Apple"* ]]; then
    info "Adding Homebrew to \$PATH..."
    (echo; echo 'export PATH="/opt/homebrew/bin:$PATH"') >> ~/.zshrc
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "Homebrew added to \$PATH!"
  fi
fi
ok "Homebrew installed!"

# Verify Homebrew
brew doctor
ok "Homebrew validated!"

# Update Homebrew
info "Updating Homebrew..."
brew update
ok "Homebrew updated!"

# Upgrade Homebrew
info "Upgrading Homebrew packages..."
brew upgrade
ok "Homebrew packages upgraded!"

# Install Ansible
brew install ansible

# Checkout .dotfiles repo and run ansible
if [ -d "$HOME/.dotfiles" ]; then
  warn "~/.dotfiles already exists.  Local copy may not be up to date with the latest."
else 
  info "Cloning .dotfiles repo..."
  cd $HOME
  git clone https://github.com/CrutchTheClutch/.dotfiles.git
fi

cd $HOME/.dotfiles

