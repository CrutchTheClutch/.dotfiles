#!/bin/zsh

array_add() {
    local array_name=$1
    local item=$2
    
    # Use eval to check if item exists in array
    if ! eval "print -l \"\${${array_name}[@]}\"" | grep -q "^${item}\$"; then
        eval "${array_name}+=(\"\$item\")"
    fi
}

MODIFIED_DOMAINS=()

modify_domain() {
    local domain=$1
    array_add MODIFIED_DOMAINS "$domain"
}

# Helper function to reset defaults, used for development
reset_defaults() {
    local domain=$1
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$HOME/Desktop/${domain}_${timestamp}.backup.txt"
    
    info "$(log 95 "$domain")Backing up preferences to $backup_file"
    if defaults read "$domain" > "$backup_file"; then
        info "$(log 95 "$domain")Resetting preferences"
        defaults delete "$domain"
        ok "$(log 95 "$domain")Reset all settings to defaults"
        modify_domain "$domain"
    else
        warn "$(log 95 "$domain")Failed to backup preferences, skipping reset"
    fi
}

default() {
    local domain=$1 key=$2 description=$3 
    shift 3
    local type_flag=""
    local value=$@

    # Check if we're dealing with a type flag
    if [[ "$1" == -* ]]; then
        type_flag=$1
        shift
        value=$@
    fi
    
    # Get the current value
    local current=$(defaults read "$domain" "$key" 2>/dev/null)
    if [[ "$current" == "$value" ]]; then
        ok "$(log 95 "$domain")$description"
        return
    fi
    
    # Update the setting
    info "$(log 95 "$domain")$key needs to be updated..."
    debug "$(log 95 "$domain")Raw current value: '$current'"
    debug "$(log 95 "$domain")Raw new value: '$value'"
    defaults write "$domain" "$key" $type_flag $value
    modify_domain "$domain"

    # Verify the setting
    current=$(defaults read "$domain" "$key" 2>/dev/null)
    if [[ "$current" == "$value" ]]; then
        ok "$(log 95 "$domain")$key updated, $description"
    else
        warn "$(log 95 "$domain")Failed to set $key to $value"
        return 1
    fi
}

remove_default() {
    local domain=$1 key=$2 description=$3
    local current=$(defaults read "$domain" "$key" 2>/dev/null)
    if [[ -n "$current" ]]; then
        info "$(log 95 "$domain")$key needs to be removed..."
        defaults delete "$domain" "$key"
        modify_domain "$domain"
        ok "$(log 95 "$domain")$key removed, $description"
    else
        ok "$(log 95 "$domain")$description"
    fi
}

set_flag() {
    local path=$1 flag=$2 enable=$3 description=$4
    local current=$(/usr/bin/chflags -h "$path" 2>/dev/null)
    
    if [[ "$enable" == "true" && "$current" != *"$flag"* ]] || [[ "$enable" == "false" && "$current" == *"$flag"* ]]; then
        info "Setting $flag flag to $enable on $path..."
        /usr/bin/chflags ${enable:+""}"no"${enable:+""}$flag "$path"
    fi
    # TODO: make this better
    ok "$description"
}

quit_app() {
    local app=$1
    local max_attempts=30  # Maximum number of attempts to wait
    local wait_interval=0.5  # Time between checks in seconds

    # Kill the app
    if killall "$app" 2>/dev/null; then
        info "Killing $app..."
        
        # Wait for process to fully terminate
        while pgrep "$app" >/dev/null && [ $max_attempts -gt 0 ]; do
            info "Waiting for $app to terminate..."
            sleep $wait_interval
            ((max_attempts--))
        done

        if ! pgrep "$app" >/dev/null; then
            ok "$app successfully killed"
        else
            fail "$app failed to kill, aborting out of precaution.  Please kill the app manually."
        fi
    fi
}

restart_app() {
    local app=$1
    local max_attempts=15  # Maximum number of attempts to wait
    local wait_interval=2  # Time between checks in seconds

    # Kill the app
    if killall "$app" 2>/dev/null; then
        info "Killing $app..."
        
        # Wait for process to fully terminate
        while pgrep "$app" >/dev/null && [ $max_attempts -gt 0 ]; do
            info "Waiting for $app to terminate..."
            sleep $wait_interval
            ((max_attempts--))
        done

        # Wait for process to start again
        max_attempts=15  # Reset counter
        while ! pgrep "$app" >/dev/null && [ $max_attempts -gt 0 ]; do
            info "Waiting for $app to restart..."
            sleep $wait_interval
            ((max_attempts--))
        done

        if pgrep "$app" >/dev/null; then
            ok "$app successfully restarted"
        else
            fail "$app failed to restart, aborting out of precaution.  Please restart your system to ensure stability."
        fi
    fi
}

#disable_system_app() {
#    local app=$1
#    local app_path="/System/Applications/${app}.app"
#    local executable_path="$app_path/Contents/MacOS/$app"
#
#    if [ ! -e "$app_path" ]; then
#        ok "$app is not installed"
#        return
#    fi
#
#    quit_app "${app}"
#}

# Check if System Preferences is running before attempting to quit
# Note: On older macOS versions (before Ventura), it's called "System Preferences"
quit_app "System Settings"


###############################################################################
# SYSTEM                                                                      #
###############################################################################

#SYSTEM_APPS=(
#    "Tips"
#)

#for app in "${SYSTEM_APPS[@]}"; do
#    disable_system_app $app
#done

set_flag "$HOME/Library" "hidden" false "Show ~/Library folder by default"
set_flag "/Volumes" "hidden" false "Show /Volumes folder by default"

###############################################################################
# NSGlobalDomain                                                              #
###############################################################################

global() { default "NSGlobalDomain" $@; }

global "AppleAccentColor" "Set accent color to purple" -int 5
global "AppleAntiAliasingThreshold" "Set anti-aliasing threshold to 4" -int 4
global "AppleHighlightColor" "Set highlight color to purple" -string "0.968627 0.831373 1.000000 Purple"
global "AppleInterfaceStyle" "Set dark interface style" -string "Dark"
remove_default "NSGlobalDomain" "AppleInterfaceStyleSwitchesAutomatically" "Disable automatic interface style switch"
#global "AppleKeyboardUIMode" "Set keyboard UI mode to full control"  3
#global "AppleMenuBarVisibleInFullscreen" "Disable menu bar in fullscreen"  0
#global "AppleMiniaturizeOnDoubleClick" "Disable miniaturize on double click" 0
#global "AppleReduceDesktopTinting" "Enable desktop tinting" 0
global "AppleShowAllExtensions" "Show filename extensions" -bool true
#global "NSAutomaticWindowAnimationsEnabled" "Disable window animations" false
#global "NavPanelFileListModeForOpenMode" "Show column view in open mode" 2
#global "NavPanelFileListModeForSaveMode" "Show column view in save mode" 2
#global "NSNavPanelExpandedStateForSaveMode" "Expand save panel by default (legacy)" true
#global "NSNavPanelExpandedStateForSaveMode2" "Expand save panel by default" true
#global "NSTableViewDefaultSizeMode" "Set table view default size to medium" 2
#global "NSWindowResizeTime" "Remove window resize animation" 0.001
#global "PMPrintingExpandedStateForPrint" "Expand print panel by default (legacy)" true
#global "PMPrintingExpandedStateForPrint2" "Expand print panel by default" true
#global "ReduceMotion" "Disable motion animations" true
#global "com.apple.mouse.scaling" "Set mouse scaling to 0.875 (sensitivity)" 0.875
#global "com.apple.sound.beep.volume" "Disable system alert sound" 0
#global "com.apple.sound.uiaudio.enabled" "Disable UI sounds" 0
#global "com.apple.springing.delay" "Disable spring loading delay for directories" 0.001
#global "com.apple.springing.enabled" "Enable spring loading for directories" 1
#global "com.apple.trackpad.forceClick" "Enable force click on trackpad" 1

###############################################################################
# Apple Symbolic Hotkeys                                                      #
###############################################################################

#hotkey() { default "com.apple.symbolichotkeys" $@; }

#hotkey "AppleSymbolicHotKeys:52" "Disable Dock hiding shortcut" -dict "enabled" 0
#hotkey "AppleSymbolicHotKeys:79" "Disable Mission Control switch to previous Space shortcut" -dict "enabled" 0
#hotkey "AppleSymbolicHotKeys:80" "Disable Mission Control switch to previous Space with window shortcut" -dict "enabled" 0
#hotkey "AppleSymbolicHotKeys:81" "Disable Mission Control switch to next Space shortcut" -dict "enabled" 0
#hotkey "AppleSymbolicHotKeys:82" "Disable Mission Control switch to previous Space with window shortcut" -dict "enabled" 0
#hotkey "AppleSymbolicHotKeys:65" "Disable Spotlight search shortcut" -dict "enabled" 0
#hotkey "AppleSymbolicHotKeys:118" "Disable Spotlight file search shortcut" -dict "enabled" 0
#hotkey "AppleSymbolicHotKeys:160" "Disable Launchpad shortcut" -dict "enabled" 0

###############################################################################
# BezelServices                                                               #
###############################################################################

#default "com.apple.BezelServices" "kDim" "Enable keyboard backlight auto-dim" 1
#default "com.apple.BezelServices" "kDimTime" "Disable keyboard backlight inactivity timeout" 0

###############################################################################
# DesktopServices                                                             #
###############################################################################

#default "com.apple.desktopservices" "DSDontWriteNetworkStores" "Disable creation of .DS_Store files on network volumes" 1
#default "com.apple.desktopservices" "DSDontWriteUSBStores" "Disable creation of .DS_Store files on USB volumes" 1

###############################################################################
# Dock                                                                        #
###############################################################################

#default "com.apple.dock" "auto-space-switching-enabled" "Disable auto switching to Space with open windows for an application" 0
#default "com.apple.dock" "autohide" "Auto-hide dock" 1
#default "com.apple.dock" "autohide-delay" "Remove dock auto-hide delay" 0.0
#default "com.apple.dock" "autohide-time-modifier" "Remove dock auto-hide time modifier" 0.0
#default "com.apple.dock" "expose-animation-duration" "Speed up Mission Control animations" 0.0
#default "com.apple.dock" "expose-group-by-app" "Disable grouping windows by application in Mission Control" 0
#default "com.apple.dock" "launchanim" "Disable app launch bounce" 0
#default "com.apple.dock" "magnification" "Disable magnification" 0
#default "com.apple.dock" "mineffect" "Change minimize effect to scale (faster than genie)" "scale"
#default "com.apple.dock" "minimize-to-application" "Minimize windows into application icon" 0
#default "com.apple.dock" "mouse-over-hilite-stack" "Disable drag windows to top of screen to enter Mission Control" 0
#default "com.apple.dock" "mru-spaces" "Disable automatically rearrange Spaces based on most recent use" 0
default "com.apple.dock" "orientation" "Position dock on left side" -string "left"
default "com.apple.dock" "persistent-apps" "Remove all apps from dock" -array
default "com.apple.dock" "persistent-others" "Remove all others from dock" -array
#default "com.apple.dock" "show-process-indicators" "Show indicators for open applications" 1
#default "com.apple.dock" "show-recents" "Disable recent applications" 0
#default "com.apple.dock" "spans-displays" "Enable separate Spaces for each display" 1
#default "com.apple.dock" "springboard-hide-duration" "Remove Launchpad hide animation" 0
#default "com.apple.dock" "springboard-show-duration" "Remove Launchpad show animation" 0
#default "com.apple.dock" "springboard-page-duration" "Remove Launchpad page turning animation" 0
default "com.apple.dock" "static-only" "Enable static dock" -bool true
default "com.apple.dock" "tilesize" "Set dock size to 32 pixels" -int 32
#default "com.apple.dock" "workspace-switch-duration" "Remove desktop switch animation" 0.0
#default "com.apple.dock" "workspaces-edge-delay" "Remove desktop edge switch animation" 0.0
#default "com.apple.dock" "wvous-bl-corner" "Disable bottom-left hot corner" 0
#default "com.apple.dock" "wvous-bl-modifier" "Remove bottom-left hot corner modifier" 0
#default "com.apple.dock" "wvous-br-corner" "Disable bottom-right hot corner" 0
#default "com.apple.dock" "wvous-br-modifier" "Remove bottom-right hot corner modifier" 0
#default "com.apple.dock" "wvous-tl-corner" "Disable top-left hot corner" 0
#default "com.apple.dock" "wvous-tl-modifier" "Remove top-left hot corner modifier" 0
#default "com.apple.dock" "wvous-tr-corner" "Disable top-right hot corner" 0
#default "com.apple.dock" "wvous-tr-modifier" "Remove top-right hot corner modifier" 0

###############################################################################
# Finder                                                                      #
###############################################################################

finder() { default "com.apple.finder" $@; }

finder "AppleShowAllFiles" "Show hidden files in Finder" -bool true
#finder "DesktopViewSettings:IconViewSettings" "Configure desktop icon view" -dict \
#    "iconSize" 64 \
#    "gridSpacing" 54 \
#    "showItemInfo" 0 \
#    "labelOnBottom" true \
#    "arrangeBy" "name"
#finder "DisableAllAnimations" "Disable Finder animations" 1
#finder "FK_AppCentricShowSidebar" "Show sidebar in app-centric Finder" 1
#finder "FK_StandardViewSettings" "Configure standard view settings (new)" -dict "ViewStyle" "Nlsv"
#finder "FK_StandardViewSettings:IconViewSettings" "Configure standard icon view" -dict \
#    "iconSize" 64 \
#    "gridSpacing" 54 \
#    "showItemInfo" false \
#    "arrangeBy" "name"
#finder "FXDefaultSearchScope" "Search current folder by default in Finder" "SCcf"
#finder "FXEnableExtensionChangeWarning" "Disable warning when changing a file extension" false
#finder "FXInfoPanesExpanded" \
#    "Expand the following File Info panes: General, Open with, Sharing & Permissions" "-dict" \
#    "General" true \
#    "OpenWith" true \
#    "Privileges" true
#finder "FXPreferredSearchViewStyle" "Use list view in search results by default" "Nlsv"
#finder "FXPreferredViewStyle" "Use list view in all Finder windows by default" "Nlsv"
#finder "FXRecentFoldersViewStyle" "Use list view in Finder recents by default" "Nlsv"
#finder "FXSearchViewSettings" "Set list view as default for search results (legacy)" -dict "ViewStyle" "Nlsv"
#finder "OpenWindowForNewRemovableDisk" "Open new Finder window when a removable volume is mounted" 1
#finder "SearchRecentsSavedViewStyle" "Use list view in Finder recents by default" "Nlsv"
#finder "SearchViewSettings" "Set list view as default for search results" -dict "ViewStyle" "Nlsv"
#finder "ShowExternalHardDrivesOnDesktop" "Hide external hard drives on desktop" 0
#finder "ShowHardDrivesOnDesktop" "Hide hard drives on desktop" 0
#finder "ShowMountedServersOnDesktop" "Hide mounted servers on desktop" 0
finder "ShowPathbar" "Show path bar in Finder" -bool true
#finder "ShowRemovableMediaOnDesktop" "Hide removable media on desktop" 0
#finder "ShowStatusBar" "Show status bar in Finder" 1
#finder "StandardViewSettings" "Configure standard view settings (legacy)" -dict \
#    "ViewStyle" "Nlsv" \
#    "IconViewSettings" -dict \
#        "iconSize" 64 \
#        "gridSpacing" 54 \
#        "showItemInfo" false \
#        "arrangeBy" "name"
#finder "_FXShowPosixPathInTitle" "Hide POSIX path in Finder title" 0
#finder "_FXSortFoldersFirst" "Show folders on top when sorting by name in Finder" 1

###############################################################################
# DiskImages                                                                  #
###############################################################################

#default "com.apple.frameworks.diskimages" "auto-open-ro-root" "Open new Finder window when a read-only volume is mounted" 1
#default "com.apple.frameworks.diskimages" "auto-open-rw-root" "Open new Finder window when a read-write volume is mounted" 1

###############################################################################
# Help Viewer                                                                 #
###############################################################################

#default "com.apple.helpviewer" "DevMode" "Show Help Viewer content in standard windows" 1

###############################################################################
# LaunchServices                                                              #
###############################################################################

#default "com.apple.LaunchServices" "LSQuarantine" "Disable quarantine for downloaded files" false

###############################################################################
# Menu Extra                                                                  #
###############################################################################

#default "com.apple.menuextra.clock" "FlashDateSeparators" "Enable flash date separators" 1
#default "com.apple.menuextra.clock" "ShowDate" "Show date in clock" 1
#default "com.apple.menuextra.clock" "ShowDayOfWeek" "Show day of week in clock" 1

###############################################################################
# NetworkBrowser                                                              #
###############################################################################

#default "com.apple.NetworkBrowser" "BrowseAllInterfaces" "Enable AirDrop over all interfaces" true

###############################################################################
# Print                                                                       #
###############################################################################

#default "com.apple.print.PrintingPrefs" "Quit When Finished" "Quit print dialog when finished" true

###############################################################################
# Security                                                                  #
###############################################################################

#default "com.apple.security" "GKAutoRearm" "Disable Gatekeeper auto-rearm" false
#default "com.apple.security" "assessment" "Disable Gatekeeper assessment" false

###############################################################################
# WindowManager                                                               #
###############################################################################

#default "com.apple.WindowManager" "GloballyEnabled" "Disable Stage Manager" 0

###############################################################################
# Spotlight                                                                   #
###############################################################################

###############################################################################
# Control Center                                                              #
###############################################################################

###############################################################################
# Kill all                                                                    #
###############################################################################


RESTART_REQUIRED=false
restart_list=()
# Build list of services to restart
# TODO: something not working here (system restart required)
for domain in "${MODIFIED_DOMAINS[@]}"; do
    case "$domain" in
        "NSGlobalDomain")
            array_add restart_list "cfprefsd"
            array_add restart_list "SystemUIServer"
            array_add restart_list "Finder"
            ;;
        "com.apple.dock")
            array_add restart_list "cfprefsd"
            array_add restart_list "Dock"
            RESTART_REQUIRED=true
            ;;
        "com.apple.finder")
            array_add restart_list "cfprefsd"
            array_add restart_list "Finder"
            RESTART_REQUIRED=true
            ;;
        "com.apple.controlcenter")
            array_add restart_list "cfprefsd"
            array_add restart_list "ControlCenter"
            RESTART_REQUIRED=true
            ;;
        "com.apple.Spotlight")
            array_add restart_list "cfprefsd"
            array_add restart_list "Spotlight"
            RESTART_REQUIRED=true
            ;;
        "com.apple.menuextra.clock")
            array_add restart_list "cfprefsd"
            array_add restart_list "SystemUIServer"
            RESTART_REQUIRED=true
            ;;
        *)
            debug "Unknown domain $domain"
            array_add restart_list "cfprefsd"
            RESTART_REQUIRED=true
            ;;
    esac
done

# Restart services based on modified domains
for app in "${restart_list[@]}"; do
    restart_app "$app"
done

if [[ "$RESTART_REQUIRED" == "true" ]]; then
    warn "Some changes require a restart to take effect"
fi
