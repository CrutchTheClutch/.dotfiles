#!/bin/bash

log() {
    printf "[\033[0;$1m$2\033[0m] $3\n"
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
