#!/bin/bash
# logging functions
info () {
  printf "\r[\033[0;96mINFO\033[0m] $1\n"
}
warn () {
  printf "\r[\033[0;93mWARN\033[0m] $1\n"
}
success () {
  printf "\r\033[2K[ \033[0;92mOK\033[0m ] $1\n"
}
fail () {
  printf "\r\033[2K[\033[0;91mFAIL\033[0m] $1\n"
  echo ''
  exit
}

# Ask for the administrator password upfront
sudo -v

# # homebrew logs
# exec > >(trap "" INT TERM; sed $'s/^/[\033[0;35mHOMEBREW\033[0m]/')
# exec 2> >(trap "" INT TERM; sed $'s/^/[\033[0;35mHOMEBREW\033[0m]/' >&2)

# setup homebrew
info "Validating Homebrew "
if ! homebrew -v >/dev/null 2>&1; then
  warn "Homebrew not found.  Attempting to install..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# verify and update homebrew
if homebrew -v >/dev/null 2>&1; then
  success "Successfully installed Homebrew."
  brew update
else
  fail "Failed to install Homebrew."
fi



xcode_cli_tools() {

# # xcode logs
# exec > >(trap "" INT TERM; sed $'s/^/[\033[0;35mXCODE\033[0m]/')
# exec 2> >(trap "" INT TERM; sed $'s/^/[\033[0;35mXCODE\033[0m]/' >&2)

# install xcode-select
info "Validating Command Line Tools for Xcode"
if ! xcode-select -p >/dev/null 2>&1; then
  warn "Command Line Tools for Xcode not found. Attempting to install from softwareupdate..."
  # This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
  PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
  softwareupdate -i "$PROD" --verbose;
fi

# verify xcode-select install
if xcode-select -p >/dev/null 2>&1; then
  success "Successfully installed Command Line Tools for Xcode."
else
  fail "Failed to install Command Line Tools for Xcode."
fi

    info "Validating Xcode CLI tools..."

    # Trick softwareupdate into giving us everything it knows about Xcode CLI tools by
    # touching the following file to /tmp
    xclt_tmp="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "$xclt_tmp"

    # Run xcrun command to check for a valid Xcode CLI tools path
    xcrun --version >/dev/null 2>&1

    # shellcheck disable=SC2181
    if [[ "$?" -eq 0 ]]; then
        success "Valid Xcode CLI tools path found!"

        # current bundleid for CLI tools
        bundle_id="com.apple.pkg.CLTools_Executables"

        if pkgutil --pkgs="$bundle_id" >/dev/null; then
            # If the CLI tools pkg bundle is found, get the version

            installed_version=$(pkgutil --pkg-info="$bundle_id" |
                awk '/version:/ {print $2}' |
                awk -F "." '{print $1"."$2}')

            info "Installed Xcode CLI tools version is \"$installed_version\""

        else
            info "Unable to determine installed Xcode CLI tools version from \"$bundle_id\"."
        fi

        info "Checking to see if there are any available Xcode CLI tool updates..."

        # Get the latest available CLI tools
        cmd_line_tools=("$(get_available_cli_tool_installs)")

    else
        info "Valid Xcode CLI tools path was not found..."
        info "Getting the latest Xcode CLI tools available for install..."

        # Get the latest available CLI tools
        cmd_line_tools=("$(get_available_cli_tool_installs)")
    fi

    # if something is returned from the cli tools check
    # shellcheck disable=SC2128
    if [[ -n $cmd_line_tools ]]; then
        info "Available Xcode CLI tools found: "
        info "$cmd_line_tools"

        if (($(grep -c . <<<"${cmd_line_tools}") > 1)); then
            cmd_line_tools_output="${cmd_line_tools}"
            cmd_line_tools=$(/bin/echo "${cmd_line_tools_output}" | tail -1)

            # get version number of the latest CLI tools installer.
            lastest_available_version=$(/bin/echo "${cmd_line_tools_output}" | tail -1 | awk -F "-" '{print $2}')
        fi

        if [[ -n $installed_version ]]; then
            # If an installed CLI tools version is returned

            # compare latest version to installed version using is-at-least
            version_check="$(is-at-least "$lastest_available_version" "$installed_version" &&
                /bin/echo "greater than or equal to" || /bin/echo "less than")"

            if [[ $version_check == *"less"* ]]; then
                # if the installed version is less than available
                info "Updating $cmd_line_tools..."
                softwareupdate --install "${cmd_line_tools}" --verbose

            else
                # if the installed version is greater than or equal to latest available
                success "Installed version \"$installed_version\" is $version_check the latest available version \"$lastest_available_version\". No upgrade needed."
            fi

        else
            info "Installing $cmd_line_tools..."
            softwareupdate --install "${cmd_line_tools}" --verbose
        fi

    else
        warn "Hmmmmmm...unabled to return any available CLI tools..."
        warn "May need to validate the softwareupdate command used."
    fi

    info "Cleaning up $xclt_tmp ..."
    rm "${xclt_tmp}"

    success "Successfully installed Xcode CLI tools!"
}

get_available_cli_tool_installs() {
    # Return the latest available CLI tools.

    # Get the OS build year
    build_year=$(sw_vers -buildVersion | cut -c 1,2)

    if [[ "$build_year" -ge 19 ]]; then
        # for Catalina or newer
        cmd_line_tools=$(softwareupdate --list |
            awk '/\*\ Label: Command Line Tools/ { $1=$1;print }' |
            sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' |
            cut -c 9- | grep -vi beta | sort -n)

    else
        # For Mojave or older
        cmd_line_tools=$(softwareupdate --list |
            awk '/\*\ Command Line Tools/ { $1=$1;print }' |
            grep -i "macOS" |
            sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)
    fi

    # return rsponse from softwareupdate reguarding CLI tools.
    echo "$cmd_line_tools"
}

rosetta2() {
    # Determine the processor brand
    if [[ "$1" == *"Apple"* ]]; then
        info "Apple Processor is present..."

        # Check if the Rosetta service is running
        check_rosetta_status=$(pgrep oahd)

        # Condition check to see if the Rosetta folder exists. This check was added
        # because the Rosetta2 service is already running in macOS versions 11.5 and
        # greater without Rosseta2 actually being installed.
        rosetta_folder="/Library/Apple/usr/share/rosetta"

        if [[ -n $check_rosetta_status ]] && [[ -e $rosetta_folder ]]; then
            info "Rosetta2 is installed... no action needed"

        else
            info "Rosetta is not installed... installing now"

            # Installs Rosetta
            softwareupdate --install-rosetta --agree-to-license |
                tee -a "${LOG_PATH}"
        fi

    else
        info "Apple Processor is not present...Rosetta2 is not needed"
    fi
}