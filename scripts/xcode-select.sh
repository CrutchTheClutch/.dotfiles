#!/bin/zsh
# NOTE: Utilize zsh rather than bash due to need for is-at-least autoload

# Used to compare Xcode CLI versions
autoload -U is-at-least

# Logging helper functions
# NOTE: Needs to remain a remote url since this script may get executed outside of the .dotfiles repo
source <(curl -s https://raw.githubusercontent.com/CrutchTheClutch/.dotfiles/HEAD/scripts/log.sh)

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

info "Validating Xcode CLI tools..."

# Trick softwareupdate into giving us everything it knows about Xcode CLI tools by
# touching the following file to /tmp
xclt_tmp="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
touch "$xclt_tmp"

# Run xcrun command to check for a valid Xcode CLI tools path
xcrun --version >/dev/null 2>&1

if [[ "$?" -eq 0 ]]; then
    info "Valid Xcode CLI tools path found"

    # current bundleid for CLI tools
    bundle_id="com.apple.pkg.CLTools_Executables"

    info "Determining current Xcode CLI version..."

    if pkgutil --pkgs="$bundle_id" >/dev/null; then
        # If the CLI tools pkg bundle is found, get the version
        installed_version=$(pkgutil --pkg-info="com.apple.pkg.CLTools_Executables" | awk '/version:/ {print $2}' | awk -F "." '{print $1"."$2}')
        ok "Installed Xcode CLI tools version is \"$installed_version\""

    else
        warn "Unable to determine installed Xcode CLI tools version from \"$bundle_id\""
    fi

    info "Checking to see if there are any available Xcode CLI tool updates..."

    # Get the latest available CLI tools
    cmd_line_tools=("$(get_available_cli_tool_installs)")

else
    warn "Valid Xcode CLI tools path was not found..."
    info "Getting the latest Xcode CLI tools available for install..."

    # Get the latest available CLI tools
    cmd_line_tools=("$(get_available_cli_tool_installs)")
fi

# if something is returned from the cli tools check
if [[ -n $cmd_line_tools ]]; then
    info "Available Xcode CLI tools found: $cmd_line_tools"

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
            info "Updating $cmd_line_tools..."
            softwareupdate --install "${cmd_line_tools}" --verbose

        else
            # if the installed version is greater than or equal to latest available
            ok "Installed version \"$installed_version\" is $version_check the latest available version \"$lastest_available_version\"!"
        fi

    else
        info "Installing $cmd_line_tools..."
        softwareupdate --install "${cmd_line_tools}" --verbose
        ok "Successfully installed Xcode CLI tools!"
    fi

else
    warn "Hmmmmmm...unabled to return any available CLI tools..."
    warn "May need to validate the softwareupdate command used"
fi

info "Cleaning up $xclt_tmp..."
rm "${xclt_tmp}"
ok "Successfully removed $xclt_tmp"
