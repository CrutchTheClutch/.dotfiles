#!/bin/zsh

# check apps vs casks
check_casks() {
    info "Checking Applications against Homebrew casks..."
    
    # Get list of installed applications
    local installed_apps=$(ls /Applications | grep '\.app$' | sed 's/\.app$//')

    # declare app overrides with optional version checks
    declare -A app_overrides=(
        ["Ableton Live 11 Suite"]="ableton-live-suite@11"
        ["BambuStudio"]="bambu-studio"
        ["Linear"]="linear-linear"
        ["Parallels Desktop"]="parallels"
        ["WiFi Explorer Pro 3"]="wifi-explorer-pro"
        ["zoom.us"]="zoom"
        # Add more overrides as needed
    )
    
    # For each application, check if it was installed via Homebrew
    echo "$installed_apps" | while read app; do
        # Skip system applications
        if [[ -d "/Applications/$app.app/Contents/_MASReceipt" ]]; then
            continue  # Skip Mac App Store apps
        fi
        
        # Check for override first, otherwise use default conversion
        if [ -n "${app_overrides[$app]}" ]; then
            local full_cask_name="${app_overrides[$app]}"
            # Split into base cask and version if @ exists
            if [[ "$full_cask_name" == *@* ]]; then
                local cask_name="${full_cask_name%@*}"  # everything before @
                local version="${full_cask_name#*@}"    # everything after @
                if brew list --cask | grep -q "^${cask_name}@${version}$"; then
                    ok "Found $app (Homebrew managed, version $version)"
                else
                    warn "$app found but expected version $version"
                fi
                continue
            else
                local cask_name="$full_cask_name"
            fi
        else
            local cask_name=$(echo "$app" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        fi
        
        # Check for non-versioned casks
        if brew list --cask | grep -q "^${cask_name}$"; then
            ok "Found $app (Homebrew managed)"
        else
            warn "$app might not be managed by Homebrew"
        fi
    done
}

info "Running brew doctor..."
brew doctor

info "Updating Homebrew..."
brew update

info "Upgrading all formulae..."
brew upgrade

ok "Homebrew is up to date"
