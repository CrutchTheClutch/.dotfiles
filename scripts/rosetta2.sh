#!/bin/bash

# Logging helper functions
source ./log.sh

info "Validating Rosetta2..."

# Determine the processor brand
if [[ "\$(sysctl -n machdep.cpu.brand_string)" == *"Apple"* ]]; then
    info "Apple Processor is present"

    # Check if the Rosetta service is running
    check_rosetta_status=$(pgrep oahd)

    # Condition check to see if the Rosetta folder exists. This check was added
    # because the Rosetta2 service is already running in macOS versions 11.5 and
    # greater without Rosseta2 actually being installed.
    rosetta_folder="/Library/Apple/usr/share/rosetta"

    if [[ -n $check_rosetta_status ]] && [[ -e $rosetta_folder ]]; then
        ok "Rosetta2 is already installed!"

    else
        warn "Rosetta2 not found."
        info "Installing Rosetta2..."

        # Installs Rosetta
        softwareupdate --install-rosetta --agree-to-license --verbose |
            tee -a "${LOG_PATH}"

        ok "Successfully installed Rosetta2!"
    fi

else
    info "Rosetta2 is not required, skipping install"
fi
