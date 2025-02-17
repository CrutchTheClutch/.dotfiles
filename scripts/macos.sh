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

# Compare two dictionaries (handles both nested and root)
compare_dict() {
    local domain=$1 key=$2
    shift 2

    warn "$(log 95 "$domain")Dictionary comparison is currently considered experimental, $key may be updated unexpectedly"
    debug "$(log 95 "$domain")Evaluating '$domain' '$key':"

    # convert args to zsh associative array
    typeset -A expected=( $@ )
    typeset -A current
    if [[ "$key" == *":"* ]]; then
        debug "$(log 95 "$domain")Comparing nested dictionary..."
        local raw_current=$(defaults read "$domain" "${key%%:*}" 2>/dev/null | awk -v key="${key#*:}" '
            $0 ~ "^[[:space:]]*" key " = *{" { 
                in_section = 1
                next
            }
            in_section && /^[[:space:]]*[^}]/ {
                gsub(/^[[:space:]]*/, "")
                gsub(/;$/, "")
                gsub(/ = /, " ")
                if ($0 !~ /^[{}]/) printf "%s ", $0
            }
            in_section && /^[[:space:]]*}/ { exit }
        ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        current=( ${=raw_current} )
    else
        debug "$(log 95 "$domain")Comparing root dictionary..."
        local raw_current=$(defaults read "$domain" "$key" 2>/dev/null | awk '
            /^[[:space:]]*[^}]/ {
                gsub(/^[[:space:]]*/, "")
                gsub(/;$/, "")
                gsub(/ = /, " ")
                if ($0 !~ /^[{}]/) printf "%s ", $0
            }
        ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        current=( ${=raw_current} )
    fi

    current_string="Current dict: { "
    for key in ${(ok)current}; do
        current_string+="$key = ${current[$key]}; "
    done
    current_string+="}"
    debug "$(log 95 "$domain")$current_string"

    expected_string="Expected dict: { "
    for key in ${(ok)expected}; do
        expected_string+="$key = ${expected[$key]}; "
    done
    expected_string+="}"
    debug "$(log 95 "$domain")$expected_string"

    # Compare values for each key
    for key in ${(k)current}; do
        if [[ "${current[$key]}" != "${expected[$key]}" ]]; then
            debug "$(log 95 "$domain")Key $key: ${current[$key]} != ${expected[$key]}"
            return 1
        fi
    done
    return 0
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
    
    case "$value" in
        -array)
            shift 4
            current=$(defaults read "$domain" "$key" 2>/dev/null | tr -d '\n\t",' | sed 's/[[:space:]]*([[:space:]]*/(/g; s/[[:space:]]*)[[:space:]]*/)/g' | tr -s ' ')
            local expected="($*)"

            warn "$(log 95 "$domain")Array comparison is currently considered experimental, $key may be updated unexpectedly"
            debug "$(log 95 "$domain")Evaluating '$domain' '$key':"
            debug "$(log 95 "$domain")Current (${#current} chars): '$current'"
            debug "$(log 95 "$domain")Expected (${#expected} chars): '$expected'"
            debug "$(log 95 "$domain")Hex dump current: $(echo -n "$current" | xxd)"
            debug "$(log 95 "$domain")Hex dump expected: $(echo -n "$expected" | xxd)"
            
            if [[ "$current" != "$expected" ]]; then
                info "$(log 95 "$domain")Updating $key from '$current' to '$expected'"
                defaults write "$domain" "$key" -array "$@"
                CHANGED=true
            fi
            ;;
        -dict)
            shift 4
            if ! compare_dict "$domain" "$key" "$@"; then
                info "$(log 95 "$domain")Updating $key dictionary..."
                if [[ "$key" == *":"* ]]; then
                    str="{ "
                    while (( $# >= 2 )); do
                        str+="$1 = $2; "
                        shift 2
                    done
                    str+="}"
                    defaults write "$domain" "${key%%:*}" -dict-add "${key#*:}" "$str"
                else
                    defaults write "$domain" "$key" -dict "$@"
                fi
                CHANGED=true
            fi
            ;;
        *)
            current=$(defaults read "$domain" "$key" 2>/dev/null)
            if ! values_match "$type" "$current" "$value"; then
                info "$(log 95 "$domain")Updating $key from '$current' to '$value'"
                defaults write "$domain" "$key" "-$type" "$value"
                CHANGED=true
            fi
            ;;
    esac
    
    ok "$(log 95 "$domain")$description"
}

set_flag() {
    local path=$1 flag=$2 enable=$3 description=$4
    local current=$(/usr/bin/chflags -h "$path" 2>/dev/null)
    
    if [[ "$enable" == "true" && "$current" != *"$flag"* ]] || [[ "$enable" == "false" && "$current" == *"$flag"* ]]; then
        info "Setting $flag flag to $enable on $path..."
        /usr/bin/chflags ${enable:+""}"no"${enable:+""}$flag "$path"
        CHANGED=true
    fi
    
    ok "$description"
}

quit_app() {
    local app=$1
    if osascript -e "tell application \"System Events\" to (name of processes) contains \"$1\"" 2>/dev/null | grep -q "true"; then
        osascript -e "tell application \"$app\" to quit" 2>/dev/null || killall "$app" 2>/dev/null || true
        ok "$app killed to apply changes"
    fi
}

disable_system_app() {
    local app=$1
    local app_path="/System/Applications/${app}.app"
    local executable_path="$app_path/Contents/MacOS/$app"

    if [ ! -e "$app_path" ]; then
        ok "$app is not installed"
        return
    fi

    quit_app "${app}"
}

# Check if System Preferences is running before attempting to quit
# Note: On newer macOS versions (Ventura+), it's called "System Settings"
quit_app "System Preferences"
quit_app "System Settings"

###############################################################################
# SYSTEM                                                                      #
###############################################################################

SYSTEM_APPS=(
    "Tips"
)

for app in "${SYSTEM_APPS[@]}"; do
    disable_system_app $app
done

set_flag "$HOME/Library" "hidden" false "Show ~/Library folder by default"
set_flag "/Volumes" "hidden" false "Show /Volumes folder by default"

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
# Apple Symbolic Hotkeys                                                      #
###############################################################################

hotkey() { default "com.apple.symbolichotkeys" $@; }

hotkey "AppleSymbolicHotKeys:52" "Disable Dock hiding shortcut" -dict "enabled" 0
hotkey "AppleSymbolicHotKeys:79" "Disable Mission Control switch to previous Space shortcut" -dict "enabled" 0
hotkey "AppleSymbolicHotKeys:80" "Disable Mission Control switch to previous Space with window shortcut" -dict "enabled" 0
hotkey "AppleSymbolicHotKeys:81" "Disable Mission Control switch to next Space shortcut" -dict "enabled" 0
hotkey "AppleSymbolicHotKeys:82" "Disable Mission Control switch to previous Space with window shortcut" -dict "enabled" 0
hotkey "AppleSymbolicHotKeys:65" "Disable Spotlight search shortcut" -dict "enabled" 0
hotkey "AppleSymbolicHotKeys:118" "Disable Spotlight file search shortcut" -dict "enabled" 0
hotkey "AppleSymbolicHotKeys:160" "Disable Launchpad shortcut" -dict "enabled" 0

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
finder "DesktopViewSettings:IconViewSettings" "Configure desktop icon view" -dict \
    "iconSize" 64 \
    "gridSpacing" 54 \
    "showItemInfo" false \
    "labelOnBottom" true \
    "arrangeBy" "name"
finder "DisableAllAnimations" "Disable Finder animations" 1
finder "FK_StandardViewSettings:IconViewSettings" "Configure standard icon view" -dict \
    "iconSize" 64 \
    "gridSpacing" 54 \
    "showItemInfo" false \
    "arrangeBy" "name"
finder "FXDefaultSearchScope" "Search current folder by default in Finder" "SCcf"
finder "FXEnableExtensionChangeWarning" "Disable warning when changing a file extension" false
finder "FXInfoPanesExpanded" \
    "Expand the following File Info panes: General, Open with, Sharing & Permissions" "-dict" \
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
finder "StandardViewSettings:IconViewSettings" "Configure standard icon view (legacy)" -dict \
    "iconSize" 64 \
    "gridSpacing" 54 \
    "showItemInfo" false \
    "arrangeBy" "name"
finder "_FXShowPosixPathInTitle" "Hide POSIX path in Finder title" 0
finder "_FXSortFoldersFirst" "Show folders on top when sorting by name in Finder" 1

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
# Security                                                                  #
###############################################################################

default "com.apple.security" "GKAutoRearm" "Disable Gatekeeper auto-rearm" false
default "com.apple.security" "assessment" "Disable Gatekeeper assessment" false

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
