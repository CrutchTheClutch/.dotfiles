#!/bin/bash

if [[ -z "$LOG_FUNCTIONS_LOADED" ]]; then
    LOG_SCRIPT_URL="https://raw.githubusercontent.com/CrutchTheClutch/.dotfiles/HEAD/scripts/log.sh"
    curl -s "$LOG_SCRIPT_URL" -o /tmp/log.sh
    source /tmp/log.sh
    export LOG_FUNCTIONS_LOADED=true
fi

