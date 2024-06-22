#!/bin/zsh

# logging config
LOG_NAME="init.log"
LOG_PATH="./$LOG_NAME"

# logging functions
info () {
  printf "[\033[0;35m$1\033[0m][\033[0;96mINFO\033[0m] $2\n"
  printf "[$1][INFO] $2\n" >> $LOG_PATH
}
warn () {
  printf "[\033[0;35m$1\033[0m][\033[0;93mWARN\033[0m] $2\n"
  printf "[$1][WARN] $2\n" >>  $LOG_PATH
}
success () {
  printf "[\033[0;35m$1\033[0m][ \033[0;92mOK\033[0m ] $2\n"
  printf "[$1][ OK ] $2\n" >> $LOG_PATH
}
fail () {
  printf "[\033[0;35m$1\033[0m]\033[2K[\033[0;91mFAIL\033[0m] $2\n"
  printf "[$1][FAIL] $2\n" >> $LOG_PATH
  exit
}

# Used when comparing installed CLI tools versus latest available via softwareupate
autoload is-at-least

xcode_cli_tools() {
    info "XCODE" "Validating Xcode CLI tools..."

    # Trick softwareupdate into giving us everything it knows about Xcode CLI tools by
    # touching the following file to /tmp
    xclt_tmp="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "$xclt_tmp"

    # Run xcrun command to check for a valid Xcode CLI tools path
    xcrun --version >/dev/null 2>&1

    # shellcheck disable=SC2181
    if [[ "$?" -eq 0 ]]; then
        success "XCODE" "Valid Xcode CLI tools path found."

        # current bundleid for CLI tools
        bundle_id="com.apple.pkg.CLTools_Executables"

        info "XCODE" "Determining current Xcode CLI version..."

        if pkgutil --pkgs="$bundle_id" >/dev/null; then
            # If the CLI tools pkg bundle is found, get the version
            installed_version=$(pkgutil --pkg-info="com.apple.pkg.CLTools_Executables" | awk '/version:/ {print $2}' | awk -F "." '{print $1"."$2}')
            success "XCODE" "Installed Xcode CLI tools version is \"$installed_version\""

        else
            warn "XCODE" "Unable to determine installed Xcode CLI tools version from \"$bundle_id\"."
        fi

        info "XCODE" "Checking to see if there are any available Xcode CLI tool updates..."

        # Get the latest available CLI tools
        cmd_line_tools=("$(get_available_cli_tool_installs)")

    else
        warn "XCODE" "Valid Xcode CLI tools path was not found..."
        info "XCODE" "Getting the latest Xcode CLI tools available for install..."

        # Get the latest available CLI tools
        cmd_line_tools=("$(get_available_cli_tool_installs)")
    fi

    # if something is returned from the cli tools check
    # shellcheck disable=SC2128
    if [[ -n $cmd_line_tools ]]; then
        success "XCODE" "Available Xcode CLI tools found: $cmd_line_tools"

        if (($(grep -c . <<<"${cmd_line_tools}") > 0)); then
            cmd_line_tools_output="${cmd_line_tools}"
            cmd_line_tools=$(echo "${cmd_line_tools_output}" | tail -1)

            # get version number of the latest CLI tools installer.
            lastest_available_version=$(echo "$cmd_line_tools_output" | tail -1 | awk -F "-" '{print $2}')
        fi

        if [[ -n $installed_version ]]; then
            # If an installed CLI tools version is returned

            # compare latest version to installed version using is-at-least
            version_check="$(is-at-least "$lastest_available_version" "$installed_version" &&
                echo "greater than or equal to" || echo "less than")"

            if [[ $version_check == *"less"* ]]; then
                # if the installed version is less than available
                info "XCODE" "Updating $cmd_line_tools..."
                softwareupdate --install "${cmd_line_tools}" --verbose

            else
                # if the installed version is greater than or equal to latest available
                success "XCODE" "Installed version \"$installed_version\" is $version_check the latest available version \"$lastest_available_version\"!"
            fi

        else
            info "XCODE" "Installing $cmd_line_tools..."
            softwareupdate --install "${cmd_line_tools}" --verbose
            success "XCODE" "Successfully installed Xcode CLI tools!"
        fi

    else
        warn "XCODE" "Hmmmmmm...unabled to return any available CLI tools..."
        warn "XCODE" "May need to validate the softwareupdate command used."
    fi

    info "XCODE" "Cleaning up $xclt_tmp..."
    rm "${xclt_tmp}"
    success "XCODE" "Succesfully removed $xclt_tmp"
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
    info "ROSETTA" "Validating Rosetta2..."

    # Determine the processor brand
    if [[ "$1" == *"Apple"* ]]; then
        info "ROSETTA" "Apple Processor is present."

        # Check if the Rosetta service is running
        check_rosetta_status=$(pgrep oahd)

        # Condition check to see if the Rosetta folder exists. This check was added
        # because the Rosetta2 service is already running in macOS versions 11.5 and
        # greater without Rosseta2 actually being installed.
        rosetta_folder="/Library/Apple/usr/share/rosetta"

        if [[ -n $check_rosetta_status ]] && [[ -e $rosetta_folder ]]; then
            success "ROSETTA" "Rosetta2 is already installed!"

        else
            warn "ROSETTA" "Rosetta2 not found."
            info "ROSETTA" "Installing Rosetta2."

            # Installs Rosetta
            softwareupdate --install-rosetta --agree-to-license |
                tee -a "${LOG_PATH}"

            success "ROSETTA" "Succesfully installed Rosetta2!"
        fi

    else
        info "ROSETTA" "Apple Processor is not present.  Rosetta2 is not needed."
    fi
}

# Get the processor brand information
processor_brand="$(sysctl -n machdep.cpu.brand_string)"

xcode_cli_tools
rosetta2 "$processor_brand"


# # # homebrew logs
# # exec > >(trap "" INT TERM; sed $'s/^/[\033[0;35mHOMEBREW\033[0m]/')
# # exec 2> >(trap "" INT TERM; sed $'s/^/[\033[0;35mHOMEBREW\033[0m]/' >&2)

# # setup homebrew
# info "Validating Homebrew "
# if ! homebrew -v >/dev/null 2>&1; then
#   warn "Homebrew not found.  Attempting to install..."
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# fi

# # verify and update homebrew
# if homebrew -v >/dev/null 2>&1; then
#   success "Successfully installed Homebrew."
#   brew update
# else
#   fail "Failed to install Homebrew."
# fi