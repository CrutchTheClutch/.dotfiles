#!/bin/zsh

CHANGED=false

# Helper function to reset defaults, used for development
reset_defaults() {
    local domain="$1"
    local description="$2"
    
    info "$(log 95 "$domain")Resetting preferences"
    defaults delete "$domain" 2>/dev/null || true
    ok "$(log 95 "$domain")$description"
    CHANGED=true
}

check_default() {
    local domain="$1"
    local key="$2"
    local expected="$3"
    local description="$4"
    
    local current=$(defaults read "$domain" "$key" 2>/dev/null)
    if [[ "$current" != "$expected" ]]; then
        info "$(log 95 "$domain")Updating $key from $current to $expected..."
        defaults write "$domain" "$key" "$expected"
        CHANGED=true
    fi

    ok "$(log 95 "$domain")$description"
}

check_default_dict() {
    local domain="$1"
    local key="$2"
    local description="$3"
    shift 3
    
    if ! defaults read "$domain" "$key" >/dev/null 2>&1; then
        info "$(log 95 "$domain")Creating $key dictionary..."
        defaults write "$domain" "$key" -dict "$@"
        CHANGED=true
        ok "$(log 95 "$domain")$description"
        return
    fi
    
    local changed=false
    local all_args=("$@")
    
    while (( $# >= 2 )); do
        local dict_key="$1"
        local expected="$2"
        shift 2
        
        # Get current value by parsing the full dictionary output
        local current=$(defaults read "$domain" "$key" | grep "$dict_key" | cut -d '=' -f2 | tr -d ' ;')
        
        if [[ -z "$current" ]] || [[ "$current" != "$expected" ]]; then
            changed=true
            break
        fi
    done
    
    if [[ "$changed" = true ]]; then
        info "$(log 95 "$domain")Updating $key dictionary values..."
        defaults write "$domain" "$key" -dict "${all_args[@]}"
        CHANGED=true
    fi
    
    ok "$(log 95 "$domain")$description"
}

check_plist() {
    local domain="$1"
    local plist="$HOME/Library/Preferences/$1"
    local key="$2"
    local expected="$3"
    local description="$4"
    
    local current=$(/usr/libexec/PlistBuddy -c "Print $key" "$plist" 2>/dev/null)

    if [[ "$current" =~ ^[0-9.]+$ ]] && [[ "$expected" =~ ^[0-9.]+$ ]]; then
        if (( $(echo "$current == $expected" | bc -l) )); then
            ok "$(log 95 "$domain")$description"
            return
        fi
    elif [[ "$current" == "$expected" ]]; then
        ok "$(log 95 "$domain")$description"
        return
    fi

    info "$(log 95 "$domain")Updating $key from $current to $expected..."
    /usr/libexec/PlistBuddy -c "Set $key $expected" "$plist"
    CHANGED=true
    ok "$(log 95 "$domain")$description"
}

check_flag() {
    local path="$1"
    local flag="$2"
    local remove="$3"        # true to remove flag, false to add flag
    local description="$4"
    
    # Check if flag is present
    if [ "$(/bin/ls -ldO "$path" | /usr/bin/grep -o "$flag")" = "$flag" ]; then
        if [ "$remove" = "true" ]; then
            info "Removing $flag flag from $path..."
            /usr/bin/chflags no"$flag" "$path"
            CHANGED=true
        fi
    else
        if [ "$remove" = "false" ]; then
            info "Adding $flag flag to $path..."
            /usr/bin/chflags "$flag" "$path"
            CHANGED=true
        fi
    fi

    ok "$description"
}

# Helper function to check if an app is running
is_running() {
    osascript -e "tell application \"System Events\" to (name of processes) contains \"$1\"" 2>/dev/null | grep -q "true"
}

# Helper function to quit an app
quit_app() {
    local app="$1"
    osascript -e "tell application \"$app\" to quit" 2>/dev/null || killall "$app" 2>/dev/null || true
    ok "$app killed to apply changes"
}

# Check if System Preferences is running before attempting to quit
# Note: On newer macOS versions (Ventura+), it's called "System Settings"
if is_running "System Preferences"; then
    quit_app "System Preferences"
fi
if is_running "System Settings"; then
    quit_app "System Settings"
fi

###############################################################################
# NSGlobalDomain                                                              #
###############################################################################

check_default "NSGlobalDomain" "com.apple.mouse.scaling" "0.875" "Set mouse scaling to 0.875 (sensitivity)"
check_default "NSGlobalDomain" "com.apple.sound.beep.volume" "0" "Disable system alert sound"
check_default "NSGlobalDomain" "com.apple.sound.uiaudio.enabled" "0" "Disable UI sounds"
check_default "NSGlobalDomain" "NSWindowResizeTime" "0.001" "Remove window resize animation"
check_default "NSGlobalDomain" "NSAutomaticWindowAnimationsEnabled" "false" "Disable window animations"
check_default "NSGlobalDomain" "AppleInterfaceStyle" "Dark" "Set dark interface style"
check_default "NSGlobalDomain" "AppleAccentColor" "5" "Set accent color to purple"
check_default "NSGlobalDomain" "AppleHighlightColor" "0.968627 0.831373 1.000000" "Set highlight color to purple"
check_default "NSGlobalDomain" "AppleShowAllExtensions" "1" "Show filename extensions"
check_default "NSGlobalDomain" "com.apple.springing.enabled" "1" "Enable spring loading for directories"
check_default "NSGlobalDomain" "com.apple.springing.delay" "0" "Disable spring loading delay for directories"
check_default "NSGlobalDomain" "ReduceMotion" "true" "Disable motion animations"

###############################################################################
# DesktopServices                                                             #
###############################################################################

check_default "com.apple.desktopservices" "DSDontWriteNetworkStores" "1" "Disable creation of .DS_Store files on network volumes"
check_default "com.apple.desktopservices" "DSDontWriteUSBStores" "1" "Disable creation of .DS_Store files on USB volumes"

###############################################################################
# WindowManager                                                               #
###############################################################################

check_default "com.apple.WindowManager" "GloballyEnabled" "0" "Disable Stage Manager"

###############################################################################
# DiskImages                                                                  #
###############################################################################

check_default "com.apple.frameworks.diskimages" "auto-open-ro-root" "1" "Open new Finder window when a read-only volume is mounted"
check_default "com.apple.frameworks.diskimages" "auto-open-rw-root" "1" "Open new Finder window when a read-write volume is mounted"

###############################################################################
# NetworkBrowser                                                              #
###############################################################################

check_default "com.apple.NetworkBrowser" "BrowseAllInterfaces" "true" "Enable AirDrop over all interfaces"

###############################################################################
# Dock                                                                        #
###############################################################################

check_default "com.apple.dock" "persistent-apps" "()" "Remove all apps from dock"
check_default "com.apple.dock" "persistent-others" "()" "Remove all others from dock"
check_default "com.apple.dock" "static-only" "true" "Enable static dock"
check_default "com.apple.dock" "tilesize" "32" "Set dock size to 32 pixels"
check_default "com.apple.dock" "orientation" "left" "Position dock on left side"
check_default "com.apple.dock" "show-process-indicators" "true" "Show indicators for open applications"
check_default "com.apple.dock" "autohide" "1" "Auto-hide dock"
check_default "com.apple.dock" "expose-animation-duration" "0.0" "Speed up Mission Control animations"
check_default "com.apple.dock" "workspaces-edge-delay" "0.0" "Remove desktop edge switch animation"
check_default "com.apple.dock" "workspace-switch-duration" "0.0" "Remove desktop switch animation"
check_default "com.apple.dock" "autohide-delay" "0.0" "Remove dock auto-hide delay"
check_default "com.apple.dock" "autohide-time-modifier" "0.0" "Remove dock auto-hide time modifier"
check_default "com.apple.dock" "launchanim" "0" "Disable app launch bounce"
check_default "com.apple.dock" "mineffect" "scale" "Change minimize effect to scale (faster than genie)"

###############################################################################
# Finder                                                                      #
###############################################################################

check_default "com.apple.finder" "AppleShowAllFiles" "1" "Show hidden files in Finder"
check_default "com.apple.finder" "ShowStatusBar" "1" "Show status bar in Finder"
check_default "com.apple.finder" "ShowPathbar" "1" "Show path bar in Finder"
check_default "com.apple.finder" "_FXShowPosixPathInTitle" "0" "Hide POSIX path in Finder title"
check_default "com.apple.finder" "_FXSortFoldersFirst" "1" "Show folders on top when sorting by name in Finder"
check_default "com.apple.finder" "FXDefaultSearchScope" "SCcf" "Search current folder by default in Finder"
check_default "com.apple.finder" "OpenWindowForNewRemovableDisk" "1" "Open new Finder window when a removable volume is mounted"
check_default "com.apple.finder" "ShowExternalHardDrivesOnDesktop" "0" "Hide external hard drives on desktop"
check_default "com.apple.finder" "ShowHardDrivesOnDesktop" "0" "Hide hard drives on desktop"
check_default "com.apple.finder" "ShowMountedServersOnDesktop" "0" "Hide mounted servers on desktop"
check_default "com.apple.finder" "ShowRemovableMediaOnDesktop" "0" "Hide removable media on desktop"
check_default "com.apple.finder" "FXPreferredViewStyle" "Nlsv" "Use list view in all Finder windows by default"
check_plist "com.apple.finder.plist" "DesktopViewSettings:IconViewSettings:iconSize" "64" "Icon size is 64px on desktop"
check_plist "com.apple.finder.plist" "FK_StandardViewSettings:IconViewSettings:iconSize" "64" "Icon size is 64px on standard view"
check_plist "com.apple.finder.plist" "StandardViewSettings:IconViewSettings:iconSize" "64" "Icon size is 64px on standard view (legacy)"
check_plist "com.apple.finder.plist" "DesktopViewSettings:IconViewSettings:gridSpacing" "54" "Grid spacing is 54px on desktop"
check_plist "com.apple.finder.plist" "FK_StandardViewSettings:IconViewSettings:gridSpacing" "54" "Grid spacing is 54px on standard view"
check_plist "com.apple.finder.plist" "StandardViewSettings:IconViewSettings:gridSpacing" "54" "Grid spacing is 54px on standard view (legacy)"
check_plist "com.apple.finder.plist" "DesktopViewSettings:IconViewSettings:showItemInfo" "false" "Hide item info on desktop"
check_plist "com.apple.finder.plist" "FK_StandardViewSettings:IconViewSettings:showItemInfo" "false" "Hide item info on standard view"
check_plist "com.apple.finder.plist" "StandardViewSettings:IconViewSettings:showItemInfo" "false" "Hide item info on standard view (legacy)"
check_plist "com.apple.finder.plist" "DesktopViewSettings:IconViewSettings:labelOnBottom" "true" "Show label on bottom of desktop icons"
check_plist "com.apple.finder.plist" "DesktopViewSettings:IconViewSettings:arrangeBy" "name" "Icons snap to grid by name on desktop"
check_plist "com.apple.finder.plist" "FK_StandardViewSettings:IconViewSettings:arrangeBy" "name" "Icons snap to grid by name on standard view"
check_plist "com.apple.finder.plist" "StandardViewSettings:IconViewSettings:arrangeBy" "name" "Icons snap to grid by name on standard view (legacy)"
check_flag "$HOME/Library" "nohidden" "true" "~/Library folder is visible"
check_flag "/Volumes" "nohidden" "true" "/Volumes folder is visible"
check_default_dict \
    "com.apple.finder" \
    "FXInfoPanesExpanded" \
    "Expand the following File Info panes: General, Open with, Sharing & Permissions" \
    "General" true \
    "OpenWith" true \
    "Privileges" true

###############################################################################
# Kill all                                                                    #
###############################################################################

if $CHANGED; then
    for app in "SystemUIServer" \
            "cfprefsd" \
            "Finder" \
            "Terminal" \
            "Dock" \
            "ControlCenter" \
            "NotificationCenter" \
            "Messages" \
            "Spotlight"
    do
        quit_app "$app"
    done
    ok "System Settings updated! Some changes may require a restart to take effect."
fi
