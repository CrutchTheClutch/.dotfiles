#!/bin/zsh

CHANGED=false

# Get the type of a value
value_type() {
    local value=$1
    if [[ "$value" =~ ^[0-9]+$ ]]; then echo int
    elif [[ "$value" =~ ^[0-9]+\.[0-9]+$ ]]; then echo float
    elif [[ "$value" =~ ^(true|false)$ ]]; then echo bool
    else echo string; fi
}

# Compare two values with type awareness
values_match() {
    local type=$1 current=$2 expected=$3
    
    case "$type" in
        int|float)
            [[ $(echo "$current == $expected" | bc -l) -eq 1 ]]
            ;;
        bool)
            [[ "$current" =~ ^(1|true|YES)$ ]] && current="true"
            [[ "$current" =~ ^(0|false|NO)$ ]] && current="false"
            [[ "$expected" =~ ^(1|YES)$ ]] && expected="true"
            [[ "$expected" =~ ^(0|NO)$ ]] && expected="false"
            [[ "$current" == "$expected" ]]
            ;;
        *)  # string
            [[ "$current" == "$expected" ]]
            ;;
    esac
}

# Helper function to compare dictionary values
compare_dict_values() {
    local domain=$1 key=$2
    shift 2
    
    local changed=false
    while (( $# >= 2 )); do
        local dict_key=$1
        local dict_expected=$2
        shift 2
        
        # Handle nested dictionary reads
        local dict_current
        if [[ "$key" == *":"* ]]; then
            # For nested keys, read the parent and extract the child value
            local parent_key=${key%%:*}    # Get everything before first colon
            local child_key=${key#*:}      # Get everything after first colon
            dict_current=$(defaults read "$domain" "$parent_key" 2>/dev/null | grep -A1 "\"$dict_key\" =" | tail -1 | awk '{print $1}' | tr -d '";,')
        else
            # For non-nested keys, read directly
            dict_current=$(defaults read "$domain" "$key" 2>/dev/null | grep "$dict_key" | awk -F" = " '{print $2}' | tr -d ';')
        fi
        
        local dict_type=$(value_type "$dict_expected")
        
        if [[ -z "$dict_current" ]] || ! values_match "$dict_type" "$dict_current" "$dict_expected"; then
            changed=true
            break
        fi
    done
    
    echo "$changed"
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
        CHANGED=true
    else
        warn "$(log 95 "$domain")Failed to backup preferences, skipping reset"
    fi
}

# Set a default value
default() {
    local domain=$1 key=$2 description=$3 value=$4
    local type=$(value_type "$value")
    local current
    
    # Handle different value types
    case "$value" in
        -array)
            shift 4
            current=$(defaults read "$domain" "$key" 2>/dev/null)
            [[ "$current" != "($*)" ]] && {
                defaults write "$domain" "$key" -array "$@"
                CHANGED=true
            }
            ;;
        -dict)
            shift 4
            if [[ "$key" == *":"* ]]; then
                defaults write "$domain" "${key%%:*}" -dict-add "${key#*:}" "{ $1 = $2; }"
            else
                defaults write "$domain" "$key" -dict "$@"
            fi
            CHANGED=true
            ;;
        *)
            current=$(defaults read "$domain" "$key" 2>/dev/null)
            if ! values_match "$type" "$current" "$value"; then
                defaults write "$domain" "$key" "-$type" "$value"
                CHANGED=true
            fi
            ;;
    esac
    
    ok "$(log 95 "$domain")$description"
}

check_plist() {
    local domain=$1 key=$2 expected=$3 description=$4
    local plist="$domain.plist"
    local plist_path="$HOME/Library/Preferences/$1"
    
    local current=$(/usr/libexec/PlistBuddy -c "Print $key" "$plist_path" 2>/dev/null)
    local type=$(value_type "$expected")
    if ! values_match "$type" "$current" "$expected"; then
        info "$(log 95 "$domain")Updating $key from $current to $expected..."
        /usr/libexec/PlistBuddy -c "Add $key string $expected" "$plist_path" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set $key $expected" "$plist_path"
        CHANGED=true
    fi

    ok "$(log 95 "$domain")$description"
}

check_flag() {
    local path=$1 flag=$2 remove=$3 description=$4
    
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
    local app=$1
    osascript -e "tell application \"$app\" to quit" 2>/dev/null || killall "$app" 2>/dev/null || true
    ok "$app killed to apply changes"
}

disable_system_app() {
    local app=$1
    local app_path="/System/Applications/${app}.app"
    local executable_path="$app_path/Contents/MacOS/$app"

    if [ ! -e "$app_path" ]; then
        ok "$app is not installed"
        return
    fi

    # Kill the app if it's running
    if is_running "${app}"; then
        quit_app "${app}"
    fi
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
# SYSTEM APPS                                                                 #
###############################################################################

SYSTEM_APPS=(
    "Tips"
)

for app in "${SYSTEM_APPS[@]}"; do
    disable_system_app $app
done

check_flag "$HOME/Library" "nohidden" "true" "~/Library folder is visible"
check_flag "/Volumes" "nohidden" "true" "/Volumes folder is visible"

###############################################################################
# NSGlobalDomain                                                              #
###############################################################################

global() { default "NSGlobalDomain" $@; }

global "AppleLanguages" "Set primary language to English" -array "en-US" "en"
global "AppleLocale" "Set locale to USA" "en_US@currency=USD"
global "AppleMeasurementUnits" "Set measurement units to inches" "inches"
global "AppleMetricUnits" "Disable metric system" false
global "AppleAccentColor" "Set accent color to purple" "5"
global "AppleAntiAliasingThreshold" "Set anti-aliasing threshold to 4" "4"
global "AppleHighlightColor" "Set highlight color to purple" "0.968627 0.831373 1.000000"
global "AppleInterfaceStyle" "Set dark interface style" "Dark"
global "AppleInterfaceStyleSwitchesAutomatically" "Disable automatic interface style switch" 0
global "AppleKeyboardUIMode" "Set keyboard UI mode to full control"  3
global "AppleMenuBarVisibleInFullscreen" "Disable menu bar in fullscreen"  0
global "AppleMiniaturizeOnDoubleClick" "Disable miniaturize on double click" 0
global "AppleReduceDesktopTinting" "Enable desktop tinting" 0
global "AppleShowAllExtensions" "Show filename extensions" 1
global "NSAutomaticWindowAnimationsEnabled" "Disable window animations" false
global "NavPanelFileListModeForOpenMode" "Show column view in open mode" 2
global "NavPanelFileListModeForSaveMode" "Show column view in save mode" 2
global "PMPrintingExpandedStateForPrint" "Expand print panel by default (legacy)" true
global "PMPrintingExpandedStateForPrint2" "Expand print panel by default" true
global "NSNavPanelExpandedStateForSaveMode" "Expand save panel by default (legacy)" true
global "NSNavPanelExpandedStateForSaveMode2" "Expand save panel by default" true
global "NSTableViewDefaultSizeMode" "Set table view default size to medium" 2
global "NSWindowResizeTime" "Remove window resize animation" 0.001
global "ReduceMotion" "Disable motion animations" true
global "com.apple.mouse.scaling" "Set mouse scaling to 0.875 (sensitivity)" 0.875
global "com.apple.sound.beep.volume" "Disable system alert sound" 0
global "com.apple.sound.uiaudio.enabled" "Disable UI sounds" 0
global "com.apple.springing.delay" "Disable spring loading delay for directories" 0.001
global "com.apple.springing.enabled" "Enable spring loading for directories" 1
global "com.apple.trackpad.forceClick" "Enable force click on trackpad" 1

###############################################################################
# BezelServices                                                               #
###############################################################################

default "com.apple.BezelServices" "kDim" "Enable keyboard backlight auto-dim" 1
default "com.apple.BezelServices" "kDimTime" "Disable keyboard backlight inactivity timeout" 0

###############################################################################
# DesktopServices                                                             #
###############################################################################

default "com.apple.desktopservices" "DSDontWriteNetworkStores" "Disable creation of .DS_Store files on network volumes" 1
default "com.apple.desktopservices" "DSDontWriteUSBStores" "Disable creation of .DS_Store files on USB volumes" 1

###############################################################################
# Dock                                                                        #
###############################################################################

default "com.apple.dock" "auto-space-switching-enabled" "Disable auto switching to Space with open windows for an application" 0
default "com.apple.dock" "autohide" "Auto-hide dock" 1
default "com.apple.dock" "autohide-delay" "Remove dock auto-hide delay" 0.0
default "com.apple.dock" "autohide-time-modifier" "Remove dock auto-hide time modifier" 0.0
default "com.apple.dock" "expose-animation-duration" "Speed up Mission Control animations" 0.0
default "com.apple.dock" "expose-group-by-app" "Disable grouping windows by application in Mission Control" 0
default "com.apple.dock" "launchanim" "Disable app launch bounce" 0
default "com.apple.dock" "magnification" "Disable magnification" 0
default "com.apple.dock" "mineffect" "Change minimize effect to scale (faster than genie)" "scale"
default "com.apple.dock" "minimize-to-application" "Minimize windows into application icon" 0
default "com.apple.dock" "mouse-over-hilite-stack" "Disable drag windows to top of screen to enter Mission Control" 0
default "com.apple.dock" "mru-spaces" "Disable automatically rearrange Spaces based on most recent use" 0
default "com.apple.dock" "orientation" "Position dock on left side" "left"
default "com.apple.dock" "persistent-apps" "Remove all apps from dock" "()"
default "com.apple.dock" "persistent-others" "Remove all others from dock" "()"
default "com.apple.dock" "show-process-indicators" "Show indicators for open applications" 1
default "com.apple.dock" "show-recents" "Disable recent applications" 0
default "com.apple.dock" "spans-displays" "Enable separate Spaces for each display" 1
default "com.apple.dock" "springboard-hide-duration" "Remove Launchpad hide animation" 0
default "com.apple.dock" "springboard-show-duration" "Remove Launchpad show animation" 0
default "com.apple.dock" "springboard-page-duration" "Remove Launchpad page turning animation" 0
default "com.apple.dock" "static-only" "Enable static dock" true
default "com.apple.dock" "tilesize" "Set dock size to 32 pixels" 32
default "com.apple.dock" "workspace-switch-duration" "Remove desktop switch animation" 0.0
default "com.apple.dock" "workspaces-edge-delay" "Remove desktop edge switch animation" 0.0
default "com.apple.dock" "wvous-bl-corner" "Disable bottom-left hot corner" 0
default "com.apple.dock" "wvous-bl-modifier" "Remove bottom-left hot corner modifier" 0
default "com.apple.dock" "wvous-br-corner" "Disable bottom-right hot corner" 0
default "com.apple.dock" "wvous-br-modifier" "Remove bottom-right hot corner modifier" 0
default "com.apple.dock" "wvous-tl-corner" "Disable top-left hot corner" 0
default "com.apple.dock" "wvous-tl-modifier" "Remove top-left hot corner modifier" 0
default "com.apple.dock" "wvous-tr-corner" "Disable top-right hot corner" 0
default "com.apple.dock" "wvous-tr-modifier" "Remove top-right hot corner modifier" 0

###############################################################################
# Finder                                                                      #
###############################################################################

finder() { default "com.apple.finder" $@; }

finder "AppleShowAllFiles" "Show hidden files in Finder" 1
finder "DisableAllAnimations" "Disable Finder animations" 1
finder "FXDefaultSearchScope" "Search current folder by default in Finder" "SCcf"
finder "FXInfoPanesExpanded" \
    "Expand the following File Info panes: General, Open with, Sharing & Permissions" \
    "-dict" \
    "General" true \
    "OpenWith" true \
    "Privileges" true
finder "FXPreferredViewStyle" "Use list view in all Finder windows by default" "Nlsv"
finder "OpenWindowForNewRemovableDisk" "Open new Finder window when a removable volume is mounted" 1
finder "ShowExternalHardDrivesOnDesktop" "Hide external hard drives on desktop" 0
finder "ShowHardDrivesOnDesktop" "Hide hard drives on desktop" 0
finder "ShowMountedServersOnDesktop" "Hide mounted servers on desktop" 0
finder "ShowPathbar" "Show path bar in Finder" 1
finder "ShowRemovableMediaOnDesktop" "Hide removable media on desktop" 0
finder "ShowStatusBar" "Show status bar in Finder" 1
finder "_FXShowPosixPathInTitle" "Hide POSIX path in Finder title" 0
finder "_FXSortFoldersFirst" "Show folders on top when sorting by name in Finder" 1

# Unfinalized finder settings
check_plist "com.apple.finder" "DesktopViewSettings:IconViewSettings:iconSize" 64 "Icon size is 64px on desktop"
check_plist "com.apple.finder" "FK_StandardViewSettings:IconViewSettings:iconSize" 64 "Icon size is 64px on standard view"
check_plist "com.apple.finder" "StandardViewSettings:IconViewSettings:iconSize" 64 "Icon size is 64px on standard view (legacy)"
check_plist "com.apple.finder" "DesktopViewSettings:IconViewSettings:gridSpacing" 54 "Grid spacing is 54px on desktop"
check_plist "com.apple.finder" "FK_StandardViewSettings:IconViewSettings:gridSpacing" 54 "Grid spacing is 54px on standard view"
check_plist "com.apple.finder" "StandardViewSettings:IconViewSettings:gridSpacing" 54 "Grid spacing is 54px on standard view (legacy)"
check_plist "com.apple.finder" "DesktopViewSettings:IconViewSettings:showItemInfo" false "Hide item info on desktop"
check_plist "com.apple.finder" "FK_StandardViewSettings:IconViewSettings:showItemInfo" false "Hide item info on standard view"
check_plist "com.apple.finder" "StandardViewSettings:IconViewSettings:showItemInfo" false "Hide item info on standard view (legacy)"
check_plist "com.apple.finder" "DesktopViewSettings:IconViewSettings:labelOnBottom" true "Show label on bottom of desktop icons"
check_plist "com.apple.finder" "DesktopViewSettings:IconViewSettings:arrangeBy" "name" "Icons snap to grid by name on desktop"
check_plist "com.apple.finder" "FK_StandardViewSettings:IconViewSettings:arrangeBy" "name" "Icons snap to grid by name on standard view"
check_plist "com.apple.finder" "StandardViewSettings:IconViewSettings:arrangeBy" "name" "Icons snap to grid by name on standard view (legacy)"


###############################################################################
# DiskImages                                                                  #
###############################################################################

default "com.apple.frameworks.diskimages" "auto-open-ro-root" "Open new Finder window when a read-only volume is mounted" 1
default "com.apple.frameworks.diskimages" "auto-open-rw-root" "Open new Finder window when a read-write volume is mounted" 1

###############################################################################
# Help Viewer                                                                 #
###############################################################################

default "com.apple.helpviewer" "DevMode" "Show Help Viewer content in standard windows" 1

###############################################################################
# LaunchServices                                                              #
###############################################################################

default "com.apple.LaunchServices" "LSQuarantine" "Disable quarantine for downloaded files" false

###############################################################################
# Menu Extra                                                                  #
###############################################################################

default "com.apple.menuextra.clock" "FlashDateSeparators" "Enable flash date separators" 1
default "com.apple.menuextra.clock" "ShowDate" "Show date in clock" 1
default "com.apple.menuextra.clock" "ShowDayOfWeek" "Show day of week in clock" 1

###############################################################################
# NetworkBrowser                                                              #
###############################################################################

default "com.apple.NetworkBrowser" "BrowseAllInterfaces" "Enable AirDrop over all interfaces" true

###############################################################################
# Print                                                                       #
###############################################################################

default "com.apple.print.PrintingPrefs" "Quit When Finished" "Quit print dialog when finished" true

###############################################################################
# Symbolic Hotkeys                                                            #
###############################################################################

default "com.apple.symbolichotkeys" "AppleSymbolicHotKeys:52" "Disable Dock hiding shortcut" -dict "enabled" false
default "com.apple.symbolichotkeys" "AppleSymbolicHotKeys:160" "Disable Launchpad shortcut" -dict "enabled" false

###############################################################################
# WindowManager                                                               #
###############################################################################

default "com.apple.WindowManager" "GloballyEnabled" "Disable Stage Manager" 0

###############################################################################
# Spotlight                                                                   #
###############################################################################

###############################################################################
# Control Center                                                              #
###############################################################################

###############################################################################
# Kill all                                                                    #
###############################################################################

if $CHANGED; then
    for app in "SystemUIServer" \
            "cfprefsd" \
            "Finder" \
            "Dock" \
            "ControlCenter" \
            "NotificationCenter" \
            "Messages" \
            "Spotlight" \
            "AppleSpell" \
            "AppleLanguages"
    do
        quit_app "$app"
    done
    ok "System Settings updated! Some changes may require a restart to take effect."
fi
