#!/bin/zsh

declare -A CASK_OVERRIDES=(
    ["Ableton Live 11 Suite"]="ableton-live-suite@11"
    ["BambuStudio"]="bambu-studio"
    ["Linear"]="linear-linear"
    ["Parallels Desktop"]="parallels"
    ["WiFi Explorer Pro 3"]="wifi-explorer-pro"
    ["zoom.us"]="zoom"
)

check_casks() {
    info "Checking Applications against Homebrew casks..."

    local installed_apps
    installed_apps=$(ls /Applications | grep '\.app$' | sed 's/\.app$//')

    local brew_casks
    brew_casks=$(brew list --cask 2>/dev/null)

    while IFS= read -r app; do
        [[ -d "/Applications/$app.app/Contents/_MASReceipt" ]] && continue

        local cask_name
        if [[ -n "${CASK_OVERRIDES[$app]}" ]]; then
            cask_name="${CASK_OVERRIDES[$app]}"
        else
            cask_name=$(echo "$app" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        fi

        if echo "$brew_casks" | grep -q "^${cask_name}$"; then
            ok "$app (Homebrew managed)"
        else
            warn "$app not managed by Homebrew"
        fi
    done <<< "$installed_apps"
}

update_homebrew() {
    info "Running brew doctor..."
    brew doctor || true

    info "Updating Homebrew..."
    brew update || true

    info "Upgrading formulae..."
    brew upgrade --formula || true

    info "Upgrading casks..."
    brew upgrade --cask || true

    ok "Homebrew up to date"
}

update_homebrew
