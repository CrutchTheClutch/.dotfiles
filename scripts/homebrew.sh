#!/bin/zsh

# check apps vs casks
check_casks() {
    info "Checking Applications against Homebrew casks..."
    
    # Get list of installed applications
    local installed_apps=$(ls /Applications | grep '\.app$' | sed 's/\.app$//')
    
    # For each application, check if it was installed via Homebrew
    echo "$installed_apps" | while read app; do
        # Skip system applications
        if [[ -d "/Applications/$app.app/Contents/_MASReceipt" ]]; then
            continue  # Skip Mac App Store apps
        fi
        
        # Try to find a matching Homebrew cask
        local matching_cask=$(brew list --cask | grep -i "^${app}$" || true)
        
        if [ -n "$matching_cask" ]; then
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
