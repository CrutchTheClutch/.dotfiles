#!/bin/zsh

# only run on m-series macs
if is_m1; then
    # check if rosetta service is running
    check_rosetta_status=$(pgrep oahd)

    # check to see if rosetta folder exists
    # rosetta service is already running without rosetta2 being installed on macOS >=11.5
    rosetta_folder="/Library/Apple/usr/share/rosetta"

    if [[ -n $check_rosetta_status ]] && [[ -e $rosetta_folder ]]; then
        ok "Rosetta2 is already installed. Continuing..."
    else
        info "Installing Rosetta2..."

        # installs rosetta2
        softwareupdate --install-rosetta --agree-to-license --verbose |
            tee -a "${LOG_PATH}"

        ok "Successfully installed Rosetta2!"
    fi
else
    info "Rosetta2 is not required on intel macs. Continuing..."
fi
