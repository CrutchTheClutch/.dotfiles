# logging functions
info () {
  printf "\r  [ \033[00;34m..\033[0m ] $1\n"
}
warn () {
  printf "\r  [ \033[0;33m??\033[0m ] $1\n"
}
success () {
  printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}
fail () {
  printf "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
  echo ''
  exit
}

# install xcode-select
info("Checking Command Line Tools for Xcode")
if ! xcode-select -p >/dev/null 2>&1; then
  warn("Command Line Tools for Xcode not found. Installing from softwareupdate…")
  # This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
  PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
  softwareupdate -i "$PROD" --verbose;
fi

# verify xcode-select install
if xcode-select -p >/dev/null 2>&1;
  success("Command Line Tools for Xcode have been installed.")
else
  fail("Command Line Tools for Xcode have failed to install.")
fi

# setup homebrew
