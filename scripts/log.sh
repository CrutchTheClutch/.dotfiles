#!/bin/bash

log() {
    local color=$1
    local status=$2
    local message=$3
    printf "[\033[0;${color}m${status}\033[0m] $message\n"
}

info() {
    log 96 "INFO" $1
}

warn() {
    log 93 "WARN" $1
}

error() {
    log 91 "FAIL" $1
}

fail() {
    error $1
    exit 1
}

ok() {
    log 92 " OK " $1
}
